const std = @import("std");
const zqlite = @import("zqlite");

pub const Db = struct {
    conn: zqlite.Conn,

    pub fn open(path: [*:0]const u8) !Db {
        const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;
        const conn = try zqlite.open(path, flags);
        try conn.busyTimeout(5000);
        try migrate(conn);
        return .{ .conn = conn };
    }

    pub fn close(self: Db) void {
        self.conn.close();
    }

    pub fn getDailySummary(self: Db, date: []const u8) !?DailySummary {
        const row = (try self.conn.row(
            \\SELECT meal_date, meal_count, total_calories,
            \\  total_protein_g, total_fat_g, total_carbs_g,
            \\  total_fiber_g, day_gout_alert, max_purine_level
            \\FROM daily_summary WHERE meal_date = ?
        , .{date})) orelse return null;
        defer row.deinit();

        return DailySummary{
            .meal_date = row.text(0),
            .meal_count = row.int(1),
            .total_calories = row.int(2),
            .total_protein_g = row.float(3),
            .total_fat_g = row.float(4),
            .total_carbs_g = row.float(5),
            .total_fiber_g = row.float(6),
            .day_gout_alert = row.boolean(7),
            .max_purine_level = row.text(8),
        };
    }

    pub fn getGoal(self: Db) !?Goal {
        const row = (try self.conn.row(
            \\SELECT target_calories, target_protein_g,
            \\  target_water_ml
            \\FROM goals ORDER BY id DESC LIMIT 1
        , .{})) orelse return null;
        defer row.deinit();

        return Goal{
            .target_calories = row.nullableInt(0),
            .target_protein_g = row.nullableFloat(1),
            .target_water_ml = row.nullableInt(2),
        };
    }

    pub fn getDailyWater(self: Db, date: []const u8) !i64 {
        const row = (try self.conn.row(
            \\SELECT COALESCE(SUM(water_ml), 0)
            \\FROM water_log WHERE log_date = ?
        , .{date})) orelse return 0;
        defer row.deinit();
        return row.int(0);
    }

    pub fn hasHighPurine(self: Db, date: []const u8) !bool {
        const row = (try self.conn.row(
            \\SELECT COUNT(*) FROM meals
            \\WHERE meal_date = ? AND purine_level = 'high'
        , .{date})) orelse return false;
        defer row.deinit();
        return row.int(0) > 0;
    }

    pub fn getMealsJson(
        self: Db,
        allocator: std.mem.Allocator,
        date: []const u8,
    ) ![]const u8 {
        var rows = try self.conn.rows(
            \\SELECT meal_name, calories, protein_g, carbs_g,
            \\  fat_g, fiber_g, protein_density,
            \\  purine_level, purine_mg, gout_warning, water_ml,
            \\  COALESCE(purine_confidence, 'medium'),
            \\  COALESCE(purine_notes, '')
            \\FROM meals WHERE meal_date = ? ORDER BY id
        , .{date});
        defer rows.deinit();

        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.appendSlice(allocator, "[");

        var first = true;
        while (rows.next()) |row| {
            if (!first) try out.appendSlice(allocator, ",");
            first = false;
            const item = std.json.Stringify.valueAlloc(
                allocator,
                .{
                    .meal_name = row.text(0),
                    .calories = row.int(1),
                    .protein_g = row.float(2),
                    .carbs_g = row.float(3),
                    .fat_g = row.float(4),
                    .fiber_g = row.float(5),
                    .protein_density = row.float(6),
                    .purine_level = row.text(7),
                    .purine_mg = row.float(8),
                    .gout_warning = row.boolean(9),
                    .water_ml = row.int(10),
                    .purine_confidence = row.text(11),
                    .purine_notes = row.text(12),
                },
                .{},
            ) catch return error.SerializationFailed;
            defer allocator.free(item);
            try out.appendSlice(allocator, item);
        }
        if (rows.err) |_| return error.QueryFailed;

        try out.appendSlice(allocator, "]");
        return try out.toOwnedSlice(allocator);
    }

    pub fn insertInjection(
        self: Db,
        date: []const u8,
        dose_mg: f64,
        site: ?[]const u8,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO injections
            \\  (injection_date, dose_mg, site)
            \\VALUES (?, ?, ?)
        , .{ date, dose_mg, site });
    }

    pub fn getLastDose(self: Db) !f64 {
        const row = (try self.conn.row(
            \\SELECT COALESCE(dose_mg, 2.5)
            \\FROM injections
            \\ORDER BY injection_date DESC LIMIT 1
        , .{})) orelse return 2.5;
        defer row.deinit();
        return row.float(0);
    }

    pub fn getLatestInjection(
        self: Db,
        today: []const u8,
        hour: u8,
    ) !?InjectionInfo {
        const row = (try self.conn.row(
            \\SELECT injection_date,
            \\  CAST(julianday(?) - julianday(injection_date)
            \\  AS INTEGER),
            \\  COALESCE(dose_mg, 2.5),
            \\  site
            \\FROM injections
            \\ORDER BY injection_date DESC LIMIT 1
        , .{today})) orelse return null;
        defer row.deinit();

        const date_text = row.text(0);
        const site_text = row.nullableText(3);
        var info = InjectionInfo{
            .date_buf = undefined,
            .date_len = @min(date_text.len, 10),
            .days_since = row.int(1),
            .dose_mg = row.float(2),
            .site_buf = undefined,
            .site_len = 0,
            .hours_since = 0,
        };
        @memcpy(
            info.date_buf[0..info.date_len],
            date_text[0..info.date_len],
        );
        if (site_text) |s| {
            info.site_len = @min(s.len, 16);
            @memcpy(
                info.site_buf[0..info.site_len],
                s[0..info.site_len],
            );
        }
        const days_f: f64 = @floatFromInt(info.days_since);
        info.hours_since = days_f * 24.0 + @as(
            f64,
            @floatFromInt(hour),
        );
        return info;
    }

    pub fn getRecentInjections(
        self: Db,
        today: []const u8,
        hour: u8,
    ) !RecentInjections {
        var rows = try self.conn.rows(
            \\SELECT
            \\  (julianday(?) - julianday(injection_date))
            \\    * 24 + ?,
            \\  COALESCE(dose_mg, 2.5)
            \\FROM injections
            \\WHERE injection_date >= date(?, '-35 days')
            \\ORDER BY injection_date DESC
            \\LIMIT 8
        , .{ today, @as(i64, hour), today });
        defer rows.deinit();

        var result = RecentInjections{
            .records = undefined,
            .len = 0,
        };
        while (rows.next()) |row| {
            if (result.len >= 8) break;
            result.records[result.len] = .{
                .hours_ago = row.float(0),
                .dose_mg = row.float(1),
            };
            result.len += 1;
        }
        return result;
    }

    pub fn getRecentSites(self: Db) !RecentSites {
        var rows = try self.conn.rows(
            \\SELECT site FROM injections
            \\WHERE site IS NOT NULL
            \\ORDER BY injection_date DESC
            \\LIMIT 6
        , .{});
        defer rows.deinit();

        var result = RecentSites{
            .bufs = undefined,
            .lens = undefined,
            .len = 0,
        };
        while (rows.next()) |row| {
            if (result.len >= 6) break;
            const site = row.text(0);
            const slen = @min(site.len, 16);
            @memcpy(
                result.bufs[result.len][0..slen],
                site[0..slen],
            );
            result.lens[result.len] = slen;
            result.len += 1;
        }
        return result;
    }

    pub fn getWeightJson(
        self: Db,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var rows = try self.conn.rows(
            \\SELECT weigh_date, weight_kg, notes
            \\FROM weigh_ins ORDER BY id DESC LIMIT 30
        , .{});
        defer rows.deinit();

        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.appendSlice(allocator, "[");

        var first = true;
        while (rows.next()) |row| {
            if (!first) try out.appendSlice(allocator, ",");
            first = false;
            const item = std.json.Stringify.valueAlloc(
                allocator,
                .{
                    .weigh_date = row.text(0),
                    .weight_kg = row.float(1),
                    .notes = row.nullableText(2),
                },
                .{},
            ) catch return error.SerializationFailed;
            defer allocator.free(item);
            try out.appendSlice(allocator, item);
        }
        if (rows.err) |_| return error.QueryFailed;

        try out.appendSlice(allocator, "]");
        return try out.toOwnedSlice(allocator);
    }
};

pub const InjectionInfo = struct {
    date_buf: [10]u8,
    date_len: usize,
    days_since: i64,
    dose_mg: f64,
    site_buf: [16]u8,
    site_len: usize,
    hours_since: f64,

    pub fn date(self: *const InjectionInfo) []const u8 {
        return self.date_buf[0..self.date_len];
    }

    pub fn site(self: *const InjectionInfo) ?[]const u8 {
        if (self.site_len == 0) return null;
        return self.site_buf[0..self.site_len];
    }
};

pub const InjectionRecord = struct {
    hours_ago: f64,
    dose_mg: f64,
};

pub const RecentInjections = struct {
    records: [8]InjectionRecord,
    len: usize,
};

pub const RecentSites = struct {
    bufs: [6][16]u8,
    lens: [6]usize,
    len: usize,
};

pub const Goal = struct {
    target_calories: ?i64,
    target_protein_g: ?f64,
    target_water_ml: ?i64,
};

pub const DailySummary = struct {
    meal_date: []const u8,
    meal_count: i64,
    total_calories: i64,
    total_protein_g: f64,
    total_fat_g: f64,
    total_carbs_g: f64,
    total_fiber_g: f64,
    day_gout_alert: bool,
    max_purine_level: []const u8,
};

fn migrate(conn: zqlite.Conn) !void {
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS meals (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  created_at TEXT NOT NULL DEFAULT (datetime('now')),
        \\  meal_date TEXT NOT NULL,
        \\  raw_text TEXT NOT NULL,
        \\  meal_name TEXT,
        \\  calories INTEGER,
        \\  protein_g REAL,
        \\  carbs_g REAL,
        \\  fat_g REAL,
        \\  fiber_g REAL,
        \\  protein_density REAL,
        \\  purine_level TEXT CHECK(purine_level IN ('low','medium','high')),
        \\  purine_mg REAL,
        \\  gout_warning INTEGER NOT NULL DEFAULT 0,
        \\  water_ml INTEGER,
        \\  llm_response TEXT
        \\);
    );
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS weigh_ins (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  created_at TEXT NOT NULL DEFAULT (datetime('now')),
        \\  weigh_date TEXT NOT NULL,
        \\  weight_kg REAL NOT NULL,
        \\  notes TEXT
        \\);
    );
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS goals (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  active_from TEXT NOT NULL DEFAULT (date('now')),
        \\  target_calories INTEGER,
        \\  target_protein_g REAL,
        \\  target_fat_g REAL,
        \\  target_carbs_g REAL,
        \\  target_fiber_g REAL,
        \\  max_purine_mg REAL,
        \\  target_water_ml INTEGER
        \\);
    );
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS water_log (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  created_at TEXT NOT NULL DEFAULT (datetime('now')),
        \\  log_date TEXT NOT NULL,
        \\  water_ml INTEGER NOT NULL
        \\);
    );
    try conn.execNoArgs(
        \\CREATE INDEX IF NOT EXISTS idx_water_date ON water_log(log_date);
    );
    try conn.execNoArgs(
        \\CREATE INDEX IF NOT EXISTS idx_meals_date ON meals(meal_date);
    );
    try conn.execNoArgs(
        \\CREATE INDEX IF NOT EXISTS idx_weigh_ins_date ON weigh_ins(weigh_date);
    );
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS injections (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  created_at TEXT NOT NULL DEFAULT (datetime('now')),
        \\  injection_date TEXT NOT NULL,
        \\  notes TEXT
        \\);
    );
    conn.execNoArgs(
        \\ALTER TABLE injections ADD COLUMN dose_mg REAL;
    ) catch {};
    conn.execNoArgs(
        \\ALTER TABLE injections ADD COLUMN site TEXT;
    ) catch {};
    try conn.execNoArgs(
        \\CREATE VIEW IF NOT EXISTS daily_summary AS
        \\SELECT
        \\  meal_date,
        \\  COUNT(*) AS meal_count,
        \\  SUM(calories) AS total_calories,
        \\  SUM(protein_g) AS total_protein_g,
        \\  SUM(fat_g) AS total_fat_g,
        \\  SUM(carbs_g) AS total_carbs_g,
        \\  SUM(fiber_g) AS total_fiber_g,
        \\  MAX(CASE WHEN gout_warning = 1 THEN 1 ELSE 0 END)
        \\    AS day_gout_alert,
        \\  MAX(purine_level) AS max_purine_level
        \\FROM meals
        \\GROUP BY meal_date;
    );
}
