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

    pub fn insertMeal(self: Db, meal: Meal) !void {
        try self.conn.exec(
            \\INSERT INTO meals (
            \\  meal_date, raw_text, meal_name, calories,
            \\  protein_g, carbs_g, fat_g, fiber_g,
            \\  protein_density, purine_level, purine_mg,
            \\  purine_confidence, purine_notes,
            \\  gout_warning, water_ml, llm_response
            \\) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        , .{
            meal.meal_date,
            meal.raw_text,
            meal.meal_name,
            meal.calories,
            meal.protein_g,
            meal.carbs_g,
            meal.fat_g,
            meal.fiber_g,
            meal.protein_density,
            meal.purine_level,
            meal.purine_mg,
            meal.purine_confidence,
            meal.purine_notes,
            meal.gout_warning,
            meal.water_ml,
            meal.llm_response,
        });
    }

    pub fn insertWeighIn(
        self: Db,
        date: []const u8,
        weight_kg: f64,
        notes: ?[]const u8,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO weigh_ins (weigh_date, weight_kg, notes)
            \\VALUES (?, ?, ?)
        , .{ date, weight_kg, notes });
    }

    pub fn getDailySummary(self: Db, date: []const u8) !?DailySummary {
        const row = (try self.conn.row(
            \\SELECT meal_date, meal_count, total_calories,
            \\  total_protein_g, total_fat_g, total_carbs_g,
            \\  total_fiber_g, day_gout_alert, max_purine_level
            \\FROM daily_summary WHERE meal_date = ?
        , .{date})) orelse return null;
        defer row.deinit();

        const purine = row.text(8);
        var purine_buf: [16]u8 = undefined;
        const plen = @min(purine.len, 16);
        @memcpy(purine_buf[0..plen], purine[0..plen]);

        return DailySummary{
            .meal_count = row.int(1),
            .total_calories = row.int(2),
            .total_protein_g = row.float(3),
            .total_fat_g = row.float(4),
            .total_carbs_g = row.float(5),
            .total_fiber_g = row.float(6),
            .day_gout_alert = row.boolean(7),
            .max_purine_level = purine_buf,
            .max_purine_len = plen,
        };
    }

    pub fn deleteLastMeal(
        self: Db,
        name_buf: []u8,
    ) !?[]const u8 {
        const row = (try self.conn.row(
            \\SELECT id, meal_name FROM meals
            \\ORDER BY id DESC LIMIT 1
        , .{})) orelse return null;
        const meal_id = row.int(0);
        const name = row.text(1);
        const len = @min(name.len, name_buf.len);
        @memcpy(name_buf[0..len], name[0..len]);
        row.deinit();

        try self.conn.exec(
            "DELETE FROM meals WHERE id = ?",
            .{meal_id},
        );
        return name_buf[0..len];
    }

    pub fn formatMealsList(
        self: Db,
        date: []const u8,
        buf: []u8,
    ) !?[]const u8 {
        var rows = try self.conn.rows(
            \\SELECT meal_name, calories, protein_g
            \\FROM meals WHERE meal_date = ?
            \\ORDER BY id
        , .{date});
        defer rows.deinit();

        var pos: usize = 0;
        var idx: usize = 0;
        while (rows.next()) |row| {
            const name = row.text(0);
            const cal = row.int(1);
            const prot = row.float(2);
            const line = std.fmt.bufPrint(
                buf[pos..],
                "{d}. {s} — {d}kcal P:{d:.0}g\n",
                .{ idx + 1, name, cal, prot },
            ) catch break;
            pos += line.len;
            idx += 1;
        }
        if (rows.err) |_| return error.QueryFailed;
        if (idx == 0) return null;
        return buf[0..pos];
    }

    pub fn formatWeighHistory(
        self: Db,
        buf: []u8,
    ) !?[]const u8 {
        var rows = try self.conn.rows(
            \\SELECT weigh_date, weight_kg, notes
            \\FROM weigh_ins ORDER BY id DESC LIMIT 10
        , .{});
        defer rows.deinit();

        var pos: usize = 0;
        var count: usize = 0;
        while (rows.next()) |row| {
            const date = row.text(0);
            const kg = row.float(1);
            const notes = row.nullableText(2);
            const line = if (notes) |n|
                std.fmt.bufPrint(
                    buf[pos..],
                    "{s}: {d:.1}kg ({s})\n",
                    .{ date, kg, n },
                )
            else
                std.fmt.bufPrint(
                    buf[pos..],
                    "{s}: {d:.1}kg\n",
                    .{ date, kg },
                );
            const written = line catch break;
            pos += written.len;
            count += 1;
        }
        if (rows.err) |_| return error.QueryFailed;
        if (count == 0) return null;
        return buf[0..pos];
    }

    pub fn setGoal(
        self: Db,
        calories: i64,
        protein_g: f64,
    ) !void {
        try self.conn.exec(
            "DELETE FROM goals",
            .{},
        );
        try self.conn.exec(
            \\INSERT INTO goals (
            \\  target_calories, target_protein_g, target_water_ml
            \\) VALUES (?, ?, 3000)
        , .{ calories, protein_g });
    }

    pub fn resetGoal(self: Db) !void {
        try self.conn.exec("DELETE FROM goals", .{});
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

    pub fn insertWater(
        self: Db,
        date: []const u8,
        ml: i64,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO water_log (log_date, water_ml)
            \\VALUES (?, ?)
        , .{ date, ml });
    }

    pub fn getDailyWater(self: Db, date: []const u8) !i64 {
        const row = (try self.conn.row(
            \\SELECT COALESCE(SUM(water_ml), 0)
            \\FROM water_log WHERE log_date = ?
        , .{date})) orelse return 0;
        defer row.deinit();
        return row.int(0);
    }

    pub fn resetDailyWater(self: Db, date: []const u8) !void {
        try self.conn.exec(
            "DELETE FROM water_log WHERE log_date = ?",
            .{date},
        );
    }

    pub fn removeWater(
        self: Db,
        date: []const u8,
        ml: i64,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO water_log (log_date, water_ml)
            \\VALUES (?, ?)
        , .{ date, -ml });
    }

    pub fn getDailyProteinTotal(
        self: Db,
        date: []const u8,
    ) !f64 {
        const row = (try self.conn.row(
            \\SELECT COALESCE(SUM(protein_g), 0)
            \\FROM meals WHERE meal_date = ?
        , .{date})) orelse return 0;
        defer row.deinit();
        return row.float(0);
    }

    pub fn getDailyFiberTotal(
        self: Db,
        date: []const u8,
    ) !f64 {
        const row = (try self.conn.row(
            \\SELECT COALESCE(SUM(fiber_g), 0)
            \\FROM meals WHERE meal_date = ?
        , .{date})) orelse return 0;
        defer row.deinit();
        return row.float(0);
    }

    pub fn countHighPurineDays(
        self: Db,
        date: []const u8,
    ) !i64 {
        const row = (try self.conn.row(
            \\SELECT COUNT(DISTINCT meal_date) FROM meals
            \\WHERE meal_date >= date(?, '-2 days')
            \\AND meal_date <= ?
            \\AND purine_level = 'high'
        , .{ date, date })) orelse return 0;
        defer row.deinit();
        return row.int(0);
    }

    pub fn insertInjection(
        self: Db,
        date: []const u8,
        dose_mg: f64,
        site: ?[]const u8,
        notes: ?[]const u8,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO injections
            \\  (injection_date, dose_mg, site, notes)
            \\VALUES (?, ?, ?, ?)
        , .{ date, dose_mg, site, notes });
    }

    pub fn daysSinceInjection(
        self: Db,
        today: []const u8,
    ) !?i64 {
        const row = (try self.conn.row(
            \\SELECT CAST(
            \\  julianday(?) - julianday(injection_date)
            \\AS INTEGER)
            \\FROM injections
            \\ORDER BY injection_date DESC LIMIT 1
        , .{today})) orelse return null;
        defer row.deinit();
        return row.int(0);
    }

    pub fn isAlertSentToday(
        self: Db,
        alert_type: []const u8,
        date: []const u8,
    ) !bool {
        const row = (try self.conn.row(
            \\SELECT COUNT(*) FROM notification_log
            \\WHERE alert_type = ?
            \\AND triggered_date = ?
        , .{ alert_type, date })) orelse return false;
        defer row.deinit();
        return row.int(0) > 0;
    }

    pub fn markAlertSent(
        self: Db,
        alert_type: []const u8,
        date: []const u8,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO notification_log
            \\  (alert_type, triggered_date)
            \\VALUES (?, ?)
        , .{ alert_type, date });
    }

    pub fn pickMsgIndex(
        self: Db,
        pool: []const u8,
        pool_size: u8,
    ) !usize {
        const unused: i64 = blk: {
            const row = (try self.conn.row(
                \\SELECT COUNT(*) FROM msg_pool
                \\WHERE pool_name = ? AND used = 0
            , .{pool})) orelse break :blk 0;
            defer row.deinit();
            break :blk row.int(0);
        };

        if (unused == 0) {
            try self.conn.exec(
                \\DELETE FROM msg_pool
                \\WHERE pool_name = ?
            , .{pool});
            var i: i64 = 0;
            while (i < pool_size) : (i += 1) {
                try self.conn.exec(
                    \\INSERT INTO msg_pool
                    \\  (pool_name, msg_index, used)
                    \\VALUES (?, ?, 0)
                , .{ pool, i });
            }
        }

        const idx: usize = blk: {
            const row = (try self.conn.row(
                \\SELECT msg_index FROM msg_pool
                \\WHERE pool_name = ? AND used = 0
                \\ORDER BY RANDOM() LIMIT 1
            , .{pool})) orelse break :blk 0;
            defer row.deinit();
            break :blk @intCast(row.int(0));
        };

        try self.conn.exec(
            \\UPDATE msg_pool SET used = 1
            \\WHERE pool_name = ? AND msg_index = ?
        , .{ pool, @as(i64, @intCast(idx)) });

        return idx;
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

    pub fn getWeeklyWeightChange(
        self: Db,
        today: []const u8,
    ) !?f64 {
        const latest: f64 = blk: {
            const row = (try self.conn.row(
                \\SELECT weight_kg FROM weigh_ins
                \\ORDER BY weigh_date DESC LIMIT 1
            , .{})) orelse return null;
            defer row.deinit();
            break :blk row.float(0);
        };

        const old: f64 = blk: {
            const row = (try self.conn.row(
                \\SELECT weight_kg FROM weigh_ins
                \\WHERE weigh_date <= date(?, '-6 days')
                \\ORDER BY weigh_date DESC LIMIT 1
            , .{today})) orelse return null;
            defer row.deinit();
            break :blk row.float(0);
        };

        if (old == 0) return null;
        return (latest - old) / old * 100.0;
    }

    pub fn getUserConfig(self: Db) !?UserConfig {
        const row = (try self.conn.row(
            \\SELECT locale, gout_tracking,
            \\  glp1_tracking, onboarded
            \\FROM user_config WHERE id = 1
        , .{})) orelse return null;
        defer row.deinit();
        return UserConfig{
            .locale = row.text(0),
            .gout_tracking = row.boolean(1),
            .glp1_tracking = row.boolean(2),
            .onboarded = row.boolean(3),
        };
    }

    pub fn getLlmCallCount(
        self: Db,
        date: []const u8,
    ) !i64 {
        const row = (try self.conn.row(
            \\SELECT count FROM llm_usage
            \\WHERE usage_date = ?
        , .{date})) orelse return 0;
        defer row.deinit();
        return row.int(0);
    }

    pub fn incrementLlmCalls(
        self: Db,
        date: []const u8,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO llm_usage (usage_date, count)
            \\VALUES (?, 1)
            \\ON CONFLICT(usage_date) DO UPDATE
            \\SET count = count + 1
        , .{date});
    }

    pub fn saveUserConfig(
        self: Db,
        locale: []const u8,
        gout: bool,
        glp1: bool,
    ) !void {
        try self.conn.exec(
            \\INSERT INTO user_config
            \\  (id, locale, gout_tracking,
            \\   glp1_tracking, onboarded)
            \\VALUES (1, ?, ?, ?, 1)
            \\ON CONFLICT(id) DO UPDATE SET
            \\  locale = excluded.locale,
            \\  gout_tracking = excluded.gout_tracking,
            \\  glp1_tracking = excluded.glp1_tracking,
            \\  onboarded = 1
        , .{ locale, gout, glp1 });
    }
};

pub const Meal = struct {
    meal_date: []const u8,
    raw_text: []const u8,
    meal_name: []const u8,
    calories: i64,
    protein_g: f64,
    carbs_g: f64,
    fat_g: f64,
    fiber_g: f64,
    protein_density: f64,
    purine_level: []const u8,
    purine_mg: f64,
    purine_confidence: []const u8,
    purine_notes: []const u8,
    gout_warning: bool,
    water_ml: i64,
    llm_response: []const u8,
};

pub const Goal = struct {
    target_calories: ?i64,
    target_protein_g: ?f64,
    target_water_ml: ?i64,
};

pub const InjectionRecord = struct {
    hours_ago: f64,
    dose_mg: f64,
};

pub const RecentInjections = struct {
    records: [8]InjectionRecord,
    len: usize,

    pub fn slice(self: *const RecentInjections) []const InjectionRecord {
        return self.records[0..self.len];
    }
};

pub const RecentSites = struct {
    bufs: [6][16]u8,
    lens: [6]usize,
    len: usize,

    pub fn get(self: *const RecentSites, i: usize) []const u8 {
        return self.bufs[i][0..self.lens[i]];
    }
};

pub const UserConfig = struct {
    locale: []const u8,
    gout_tracking: bool,
    glp1_tracking: bool,
    onboarded: bool,
};

pub const DailySummary = struct {
    meal_count: i64,
    total_calories: i64,
    total_protein_g: f64,
    total_fat_g: f64,
    total_carbs_g: f64,
    total_fiber_g: f64,
    day_gout_alert: bool,
    max_purine_level: [16]u8,
    max_purine_len: usize,
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
    conn.execNoArgs(
        \\ALTER TABLE meals ADD COLUMN purine_confidence TEXT
        \\  DEFAULT 'medium';
    ) catch {};
    conn.execNoArgs(
        \\ALTER TABLE meals ADD COLUMN purine_notes TEXT DEFAULT '';
    ) catch {};
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
        \\ALTER TABLE injections ADD COLUMN dose_mg REAL
        \\  DEFAULT 2.5;
    ) catch {};
    conn.execNoArgs(
        \\ALTER TABLE injections ADD COLUMN site TEXT;
    ) catch {};
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS notification_log (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  alert_type TEXT NOT NULL,
        \\  triggered_date TEXT NOT NULL,
        \\  triggered_at TEXT NOT NULL DEFAULT (datetime('now'))
        \\);
    );
    try conn.execNoArgs(
        \\CREATE INDEX IF NOT EXISTS idx_notif_type_date
        \\  ON notification_log(alert_type, triggered_date);
    );
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS msg_pool (
        \\  pool_name TEXT NOT NULL,
        \\  msg_index INTEGER NOT NULL,
        \\  used INTEGER NOT NULL DEFAULT 0,
        \\  PRIMARY KEY (pool_name, msg_index)
        \\);
    );
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
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS llm_usage (
        \\  usage_date TEXT PRIMARY KEY,
        \\  count INTEGER NOT NULL DEFAULT 0
        \\);
    );
    try conn.execNoArgs(
        \\CREATE TABLE IF NOT EXISTS user_config (
        \\  id INTEGER PRIMARY KEY CHECK (id = 1),
        \\  locale TEXT NOT NULL DEFAULT 'en',
        \\  gout_tracking INTEGER NOT NULL DEFAULT 0,
        \\  glp1_tracking INTEGER NOT NULL DEFAULT 0,
        \\  onboarded INTEGER NOT NULL DEFAULT 0
        \\);
    );
}
