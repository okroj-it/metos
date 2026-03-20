const std = @import("std");
const Io = std.Io;
const database = @import("db.zig");
const llm = @import("llm.zig");
const notif = @import("notifications.zig");
const kinetics = @import("kinetics.zig");
const strings = @import("strings.zig");
const strings_notif = @import("strings_notif.zig");

pub const Bot = struct {
    const PendingAction = union(enum) {
        none,
        transcript: []const u8,
        edit,
        command: []const u8,
    };

    allocator: std.mem.Allocator,
    io: Io,
    db: database.Db,
    gemini_key: []const u8,
    bot_token: []const u8,
    owner_id: i64,
    locale: strings.Locale,
    last_update_id: i64,
    pending: PendingAction,
    pending_chat_id: i64,
    last_notif_check: i64,

    pub fn init(
        allocator: std.mem.Allocator,
        io: Io,
        db_path: [*:0]const u8,
        gemini_key: []const u8,
        bot_token: []const u8,
        owner_id: i64,
        locale: strings.Locale,
    ) !Bot {
        const db_inst = try database.Db.open(db_path);
        errdefer db_inst.close();

        return .{
            .allocator = allocator,
            .io = io,
            .db = db_inst,
            .gemini_key = gemini_key,
            .bot_token = bot_token,
            .owner_id = owner_id,
            .locale = locale,
            .last_update_id = 0,
            .pending = .none,
            .pending_chat_id = 0,
            .last_notif_check = 0,
        };
    }

    fn s(self: *const Bot, key: strings.Key) []const u8 {
        return strings.get(self.locale, key);
    }

    fn fmt(
        self: *const Bot,
        buf: []u8,
        comptime key: strings.Key,
        args: anytype,
    ) ?[]const u8 {
        return switch (self.locale) {
            inline else => |loc| std.fmt.bufPrint(
                buf,
                comptime strings.get(loc, key),
                args,
            ) catch null,
        };
    }

    pub fn deinit(self: *Bot) void {
        self.clearPending();
        self.db.close();
    }

    fn clearPending(self: *Bot) void {
        switch (self.pending) {
            .transcript => |t| self.allocator.free(t),
            .command => |c| self.allocator.free(c),
            .none, .edit => {},
        }
        self.pending = .none;
    }

    fn storePending(
        self: *Bot,
        chat_id: i64,
        cmd: []const u8,
    ) !void {
        self.clearPending();
        self.pending = .{
            .command = try self.allocator.dupe(u8, cmd),
        };
        self.pending_chat_id = chat_id;
    }

    pub fn run(self: *Bot) !void {
        std.log.info("telegram bot started", .{});
        while (true) {
            self.pollUpdates() catch |err| {
                std.log.err(
                    "poll error: {s}",
                    .{@errorName(err)},
                );
            };
        }
    }

    fn pollUpdates(self: *Bot) !void {
        var client: std.http.Client = .{
            .allocator = self.allocator,
            .io = self.io,
        };
        defer client.deinit();

        var url_buf: [512]u8 = undefined;
        const url = std.fmt.bufPrint(
            &url_buf,
            "https://api.telegram.org/bot{s}/getUpdates"
            ++ "?timeout=30&offset={d}",
            .{ self.bot_token, self.last_update_id },
        ) catch return error.UrlTooLong;

        const uri = std.Uri.parse(url) catch
            return error.InvalidUrl;

        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();

        var redirect_buf: [1]u8 = undefined;
        var response = try req.receiveHead(&redirect_buf);

        if (response.head.status != .ok) {
            return error.TelegramApiError;
        }

        var transfer_buf: [4096]u8 = undefined;
        const reader = response.reader(&transfer_buf);
        const body = try reader.allocRemaining(
            self.allocator,
            Io.Limit.limited(1024 * 1024),
        );
        defer self.allocator.free(body);

        const parsed = std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            body,
            .{},
        ) catch return;
        defer parsed.deinit();

        const ok = parsed.value.object.get("ok") orelse return;
        if (ok != .bool or !ok.bool) return;

        const result = parsed.value.object.get("result") orelse
            return;
        for (result.array.items) |update| {
            self.handleUpdate(update) catch |err| {
                std.log.err(
                    "update handler error: {s}",
                    .{@errorName(err)},
                );
            };
        }

        self.maybeRunNotifications();
    }

    fn handleUpdate(
        self: *Bot,
        update: std.json.Value,
    ) !void {
        const update_id = update.object.get("update_id") orelse
            return;
        const id = update_id.integer;
        if (id >= self.last_update_id) {
            self.last_update_id = id + 1;
        }

        if (update.object.get("callback_query")) |cb| {
            try self.handleCallback(cb);
            return;
        }

        const message = update.object.get("message") orelse
            return;
        const chat = message.object.get("chat") orelse return;
        const chat_id = chat.object.get("id") orelse return;

        const from = message.object.get("from") orelse return;
        const user_id = from.object.get("id") orelse return;
        if (user_id.integer != self.owner_id) {
            try self.sendMessage(
                chat_id.integer,
                self.s(.access_denied),
            );
            return;
        }

        if (message.object.get("voice")) |voice| {
            try self.handleVoice(chat_id.integer, voice);
            return;
        }

        const text_val = message.object.get("text") orelse {
            try self.sendMessage(
                chat_id.integer,
                self.s(.err_send_text_or_voice),
            );
            return;
        };
        const text = text_val.string;

        // Awaiting edited transcript from voice flow
        if (self.pending == .edit and
            chat_id.integer == self.pending_chat_id)
        {
            self.clearPending();
            try self.handleMeal(chat_id.integer, text);
            return;
        }

        // Any new text input clears pending confirmation
        self.clearPending();

        // Read-only commands — no confirmation
        if (std.mem.startsWith(u8, text, "/stats")) {
            try self.handleStats(chat_id.integer, text);
        } else if (std.mem.startsWith(u8, text, "/meals")) {
            try self.handleMeals(chat_id.integer, text);
        } else if (std.mem.startsWith(u8, text, "/history")) {
            try self.handleHistory(chat_id.integer);
        } else if (std.mem.startsWith(u8, text, "/start")) {
            try self.sendMessage(
                chat_id.integer,
                self.s(.cmd_start),
            );
        } else if (std.mem.startsWith(u8, text, "/help")) {
            try self.sendMessage(
                chat_id.integer,
                self.s(.cmd_help),
            );
            // Data-modifying — show confirmation
        } else if (std.mem.startsWith(u8, text, "/weight")) {
            try self.confirmWeight(chat_id.integer, text);
        } else if (std.mem.startsWith(u8, text, "/water")) {
            try self.confirmWater(chat_id.integer, text);
        } else if (std.mem.startsWith(u8, text, "/goal")) {
            try self.confirmGoal(chat_id.integer, text);
        } else if (std.mem.startsWith(u8, text, "/injection")) {
            try self.confirmInjection(chat_id.integer, text);
        } else if (std.mem.startsWith(u8, text, "/undo")) {
            try self.confirmUndo(chat_id.integer);
        } else {
            try self.handleMeal(chat_id.integer, text);
        }
    }

    // --- Confirmation generators ---

    fn confirmWeight(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = text[7..];
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        if (trimmed.len == 0) {
            try self.sendMessage(
                chat_id,
                self.s(.usage_weight),
            );
            return;
        }

        var weight_end: usize = 0;
        for (trimmed, 0..) |c, i| {
            if ((c >= '0' and c <= '9') or c == '.') {
                weight_end = i + 1;
            } else break;
        }
        if (weight_end == 0) {
            try self.sendMessage(
                chat_id,
                self.s(.usage_weight),
            );
            return;
        }

        const weight = std.fmt.parseFloat(
            f64,
            trimmed[0..weight_end],
        ) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_invalid_weight),
            );
            return;
        };

        const rest = std.mem.trimStart(
            u8,
            trimmed[weight_end..],
            " ",
        );

        var buf: [192]u8 = undefined;
        const msg = if (rest.len > 0)
            self.fmt(
                &buf,
                .confirm_weight,
                .{ weight, rest },
            )
        else
            self.fmt(
                &buf,
                .confirm_weight_no_note,
                .{weight},
            );
        try self.storePending(chat_id, text);
        try self.sendConfirmButtons(
            chat_id,
            msg orelse self.s(.confirm_weight_fallback),
        );
    }

    fn confirmWater(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 6)
            text[6..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        if (trimmed.len == 0) {
            try self.sendMessage(
                chat_id,
                self.s(.usage_water),
            );
            return;
        }

        var buf: [128]u8 = undefined;
        if (std.mem.eql(u8, trimmed, "reset")) {
            try self.storePending(chat_id, text);
            try self.sendConfirmButtons(
                chat_id,
                self.s(.confirm_water_reset),
            );
            return;
        }

        const ml = std.fmt.parseInt(i64, trimmed, 10) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_invalid_number),
            );
            return;
        };

        const msg = if (ml < 0)
            self.fmt(
                &buf,
                .confirm_water_subtract,
                .{-ml},
            )
        else
            self.fmt(
                &buf,
                .confirm_water_add,
                .{ml},
            );
        try self.storePending(chat_id, text);
        try self.sendConfirmButtons(
            chat_id,
            msg orelse self.s(.confirm_water_fallback),
        );
    }

    fn confirmGoal(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 5)
            text[5..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");

        if (trimmed.len == 0) {
            try self.handleGoalShow(chat_id);
            return;
        }

        if (std.mem.eql(u8, trimmed, "reset")) {
            try self.storePending(chat_id, text);
            try self.sendConfirmButtons(
                chat_id,
                self.s(.confirm_goal_reset),
            );
            return;
        }

        var it = std.mem.splitScalar(u8, trimmed, ' ');
        const cal_str = it.first();
        const prot_str = it.next() orelse {
            try self.sendMessage(
                chat_id,
                self.s(.usage_goal),
            );
            return;
        };

        const cal = std.fmt.parseInt(i64, cal_str, 10) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_invalid_calories),
            );
            return;
        };
        const prot = std.fmt.parseFloat(f64, prot_str) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_invalid_protein),
            );
            return;
        };

        var buf: [192]u8 = undefined;
        try self.storePending(chat_id, text);
        try self.sendConfirmButtons(
            chat_id,
            self.fmt(
                &buf,
                .confirm_goal,
                .{ cal, prot },
            ) orelse self.s(.confirm_goal_fallback),
        );
    }

    fn confirmInjection(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 10)
            text[10..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        const last_dose = self.db.getLastDose() catch 2.5;
        const suggested = self.getSuggestedSite();
        const args = parseInjectionText(
            trimmed,
            last_dose,
            suggested,
        );

        var cmd_buf: [256]u8 = undefined;
        const notes = if (args.has_notes)
            trimmed[args.notes_start..]
        else
            null;
        const cmd = if (notes) |n|
            std.fmt.bufPrint(
                &cmd_buf,
                "/injection {d:.1} {s} {s}",
                .{ args.dose_mg, args.site(), n },
            )
        else
            std.fmt.bufPrint(
                &cmd_buf,
                "/injection {d:.1} {s}",
                .{ args.dose_mg, args.site() },
            );
        try self.storePending(
            chat_id,
            cmd catch text,
        );

        var buf: [256]u8 = undefined;
        try self.sendConfirmButtons(
            chat_id,
            self.fmt(
                &buf,
                .confirm_injection,
                .{ args.dose_mg, args.site() },
            ) orelse self.s(.confirm_injection_fallback),
        );
    }

    fn confirmUndo(self: *Bot, chat_id: i64) !void {
        try self.storePending(chat_id, "/undo");
        try self.sendConfirmButtons(
            chat_id,
            self.s(.confirm_undo),
        );
    }

    // --- Command executors ---

    fn dispatchCommand(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        if (std.mem.startsWith(u8, text, "/weight")) {
            try self.execWeight(chat_id, text);
        } else if (std.mem.startsWith(u8, text, "/water")) {
            try self.execWater(chat_id, text);
        } else if (std.mem.startsWith(u8, text, "/goal")) {
            try self.execGoal(chat_id, text);
        } else if (std.mem.startsWith(
            u8,
            text,
            "/injection",
        )) {
            try self.execInjection(chat_id, text);
        } else if (std.mem.startsWith(u8, text, "/undo")) {
            try self.execUndo(chat_id);
        }
    }

    fn handleMeal(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        var result = llm.analyze(
            self.allocator,
            self.io,
            self.gemini_key,
            text,
            self.locale.llmName(),
        ) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_meal_analysis_failed),
            );
            return;
        };
        defer result.deinit(self.allocator);

        const today = getToday(self.io);
        const r = result.parsed;

        const meal = database.Meal{
            .meal_date = &today,
            .raw_text = text,
            .meal_name = r.meal_name,
            .calories = r.calories,
            .protein_g = r.protein_g,
            .carbs_g = r.carbs_g,
            .fat_g = r.fat_g,
            .fiber_g = r.fiber_g,
            .protein_density = r.protein_density,
            .purine_level = r.purine_level,
            .purine_mg = r.purine_mg,
            .purine_confidence = r.purine_confidence,
            .purine_notes = r.purine_notes,
            .gout_warning = r.gout_warning,
            .water_ml = r.water_ml,
            .llm_response = result.raw_json,
        };

        self.db.insertMeal(meal) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_meal_save_failed),
            );
            return;
        };

        self.checkPostMealAlerts(&today, r.calories, r.fat_g);

        const notes_str = if (r.purine_notes.len > 0)
            r.purine_notes
        else
            "";

        var msg_buf: [1024]u8 = undefined;
        const msg = self.fmt(
            &msg_buf,
            .meal_summary,
            .{
                r.meal_name,
                r.calories,
                r.protein_g,
                r.carbs_g,
                r.fat_g,
                r.fiber_g,
                r.protein_density,
                r.purine_level,
                r.purine_mg,
                r.purine_confidence,
                r.water_ml,
                if (r.gout_warning)
                    self.s(.gout_warning_line)
                else
                    @as([]const u8, ""),
                notes_str,
            },
        ) orelse self.s(.meal_saved_fallback);

        try self.sendMessage(chat_id, msg);
    }

    fn execWeight(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = text[7..];
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");

        var weight_end: usize = 0;
        for (trimmed, 0..) |c, i| {
            if ((c >= '0' and c <= '9') or c == '.') {
                weight_end = i + 1;
            } else break;
        }

        const weight = std.fmt.parseFloat(
            f64,
            trimmed[0..weight_end],
        ) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_invalid_weight),
            );
            return;
        };

        const rest = std.mem.trimStart(
            u8,
            trimmed[weight_end..],
            " ",
        );
        const notes: ?[]const u8 = if (rest.len > 0)
            rest
        else
            null;
        const today = getToday(self.io);

        self.db.insertWeighIn(&today, weight, notes) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_weight_save_failed),
            );
            return;
        };

        var msg_buf: [128]u8 = undefined;
        const msg = self.fmt(
            &msg_buf,
            .ok_weight,
            .{weight},
        ) orelse self.s(.ok_weight_fallback);
        try self.sendMessage(chat_id, msg);
    }

    fn execWater(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 6)
            text[6..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        const today = getToday(self.io);

        if (std.mem.eql(u8, trimmed, "reset")) {
            self.db.resetDailyWater(&today) catch {
                try self.sendMessage(
                    chat_id,
                    self.s(.err_water_reset_failed),
                );
                return;
            };
            try self.sendMessage(
                chat_id,
                self.s(.ok_water_reset),
            );
            return;
        }

        const ml = std.fmt.parseInt(i64, trimmed, 10) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_invalid_number),
            );
            return;
        };

        if (ml < 0) {
            self.db.removeWater(&today, -ml) catch {
                try self.sendMessage(
                    chat_id,
                    self.s(.err_water_save_failed),
                );
                return;
            };
        } else {
            self.db.insertWater(&today, ml) catch {
                try self.sendMessage(
                    chat_id,
                    self.s(.err_water_save_failed),
                );
                return;
            };
        }

        const total = self.db.getDailyWater(&today) catch 0;
        var msg_buf: [128]u8 = undefined;
        const msg = self.fmt(
            &msg_buf,
            .ok_water,
            .{ ml, total },
        ) orelse self.s(.ok_water_fallback);
        try self.sendMessage(chat_id, msg);
    }

    fn execGoal(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 5)
            text[5..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");

        if (std.mem.eql(u8, trimmed, "reset")) {
            self.db.resetGoal() catch {
                try self.sendMessage(
                    chat_id,
                    self.s(.err_goal_reset_failed),
                );
                return;
            };
            try self.sendMessage(
                chat_id,
                self.s(.ok_goal_reset),
            );
            return;
        }

        var it = std.mem.splitScalar(u8, trimmed, ' ');
        const cal_str = it.first();
        const prot_str = it.next() orelse return;

        const calories = std.fmt.parseInt(
            i64,
            cal_str,
            10,
        ) catch return;
        const protein = std.fmt.parseFloat(
            f64,
            prot_str,
        ) catch return;

        self.db.setGoal(calories, protein) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_goal_save_failed),
            );
            return;
        };

        var msg_buf: [192]u8 = undefined;
        try self.sendMessage(
            chat_id,
            self.fmt(
                &msg_buf,
                .ok_goal,
                .{ calories, protein },
            ) orelse self.s(.ok_goal_fallback),
        );
    }

    fn execUndo(self: *Bot, chat_id: i64) !void {
        var name_buf: [128]u8 = undefined;
        const name = self.db.deleteLastMeal(&name_buf) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_undo_failed),
            );
            return;
        };
        if (name) |n| {
            var msg_buf: [256]u8 = undefined;
            const msg = self.fmt(
                &msg_buf,
                .ok_undo,
                .{n},
            ) orelse self.s(.ok_undo_fallback);
            try self.sendMessage(chat_id, msg);
        } else {
            try self.sendMessage(
                chat_id,
                self.s(.no_meals_to_undo),
            );
        }
    }

    fn execInjection(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 10)
            text[10..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        const args = parseInjectionText(
            trimmed,
            2.5,
            kinetics.injection_sites[0],
        );
        const notes: ?[]const u8 = if (args.has_notes)
            trimmed[args.notes_start..]
        else
            null;
        const today = getToday(self.io);

        self.db.insertInjection(
            &today,
            args.dose_mg,
            args.site(),
            notes,
        ) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_injection_save_failed),
            );
            return;
        };

        var msg_buf: [256]u8 = undefined;
        try self.sendMessage(
            chat_id,
            self.fmt(
                &msg_buf,
                .ok_injection,
                .{ args.dose_mg, args.site() },
            ) orelse self.s(.ok_injection_fallback),
        );
    }

    fn getSuggestedSite(self: *Bot) []const u8 {
        const sites = self.db.getRecentSites() catch
            return kinetics.injection_sites[0];
        var slices: [6][]const u8 = undefined;
        for (0..sites.len) |i| {
            slices[i] = sites.get(i);
        }
        return kinetics.suggestSite(slices[0..sites.len]);
    }

    fn handleGoalShow(self: *Bot, chat_id: i64) !void {
        const goal = self.db.getGoal() catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_goal_fetch_failed),
            );
            return;
        };
        if (goal) |g| {
            var msg_buf: [256]u8 = undefined;
            const msg = self.fmt(
                &msg_buf,
                .goal_show,
                .{
                    g.target_calories orelse 0,
                    g.target_protein_g orelse 0,
                },
            ) orelse self.s(.goal_show_fallback);
            try self.sendMessage(chat_id, msg);
        } else {
            try self.sendMessage(
                chat_id,
                self.s(.no_goal),
            );
        }
    }

    // --- Read-only handlers ---

    fn handleStats(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 6)
            text[6..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        const today_buf = getToday(self.io);
        const date: []const u8 = if (trimmed.len >= 10)
            trimmed[0..10]
        else
            &today_buf;

        const summary = self.db.getDailySummary(date) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_stats_fetch_failed),
            );
            return;
        };

        if (summary == null) {
            try self.sendMessage(
                chat_id,
                self.s(.stats_no_data),
            );
            return;
        }

        const sm = summary.?;
        const hour = getHourCET(self.io);
        const water = self.db.getDailyWater(date) catch 0;

        // Pharma status
        const inj = self.db.getRecentInjections(
            date,
            hour,
        ) catch database.RecentInjections{
            .records = undefined,
            .len = 0,
        };
        const days = self.db.daysSinceInjection(
            date,
        ) catch null;

        var pharma_buf: [128]u8 = undefined;
        const pharma_line = if (inj.len > 0) blk: {
            const sup = kinetics.appetiteSuppression(
                inj.records[0].hours_ago,
            );
            break :blk self.fmt(
                &pharma_buf,
                .stats_pharma,
                .{
                    days orelse 0,
                    sup * 100,
                },
            ) orelse "";
        } else
            @as([]const u8, "");

        var msg_buf: [768]u8 = undefined;
        const msg = self.fmt(
            &msg_buf,
            .stats_template,
            .{
                date,
                sm.meal_count,
                sm.total_calories,
                sm.total_protein_g,
                sm.total_carbs_g,
                sm.total_fat_g,
                sm.total_fiber_g,
                sm.max_purine_level[0..sm.max_purine_len],
                pharma_line,
                water,
                if (sm.day_gout_alert)
                    self.s(.stats_gout_alert)
                else
                    @as([]const u8, ""),
            },
        ) orelse self.s(.stats_fallback);

        try self.sendMessage(chat_id, msg);
    }

    fn handleMeals(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        const after_cmd = if (text.len > 6)
            text[6..]
        else
            "";
        const trimmed = std.mem.trimStart(u8, after_cmd, " ");
        const today_buf = getToday(self.io);
        const date: []const u8 = if (trimmed.len >= 10)
            trimmed[0..10]
        else
            &today_buf;

        var buf: [2048]u8 = undefined;
        const list = self.db.formatMealsList(date, &buf) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_meals_fetch_failed),
            );
            return;
        };
        if (list) |l| {
            var msg_buf: [2200]u8 = undefined;
            const msg = self.fmt(
                &msg_buf,
                .meals_header,
                .{ date, l },
            ) orelse l;
            try self.sendMessage(chat_id, msg);
        } else {
            try self.sendMessage(
                chat_id,
                self.s(.no_meals),
            );
        }
    }

    fn handleHistory(self: *Bot, chat_id: i64) !void {
        var buf: [2048]u8 = undefined;
        const list = self.db.formatWeighHistory(&buf) catch {
            try self.sendMessage(
                chat_id,
                self.s(.err_history_fetch_failed),
            );
            return;
        };
        if (list) |l| {
            var msg_buf: [2200]u8 = undefined;
            const msg = self.fmt(
                &msg_buf,
                .history_header,
                .{l},
            ) orelse l;
            try self.sendMessage(chat_id, msg);
        } else {
            try self.sendMessage(
                chat_id,
                self.s(.no_weigh_ins),
            );
        }
    }

    // --- Voice ---

    fn handleVoice(
        self: *Bot,
        chat_id: i64,
        voice: std.json.Value,
    ) !void {
        const file_id_val = voice.object.get("file_id") orelse
            return;
        const file_id = file_id_val.string;

        try self.sendMessage(
            chat_id,
            self.s(.voice_transcribing),
        );

        const audio = self.downloadTelegramFile(
            file_id,
        ) catch |err| {
            std.log.err(
                "download audio failed: {s}",
                .{@errorName(err)},
            );
            try self.sendMessage(
                chat_id,
                self.s(.err_audio_download_failed),
            );
            return;
        };
        defer self.allocator.free(audio);

        var result = llm.transcribe(
            self.allocator,
            self.io,
            self.gemini_key,
            audio,
            "audio/ogg",
        ) catch |err| {
            std.log.err(
                "transcribe failed: {s}",
                .{@errorName(err)},
            );
            try self.sendMessage(
                chat_id,
                self.s(.err_transcribe_failed),
            );
            return;
        };

        self.clearPending();
        self.pending = .{ .transcript = result.transcript };
        self.pending_chat_id = chat_id;

        var msg_buf: [2048]u8 = undefined;
        const msg = self.fmt(
            &msg_buf,
            .voice_transcript_prefix,
            .{result.transcript},
        ) orelse result.transcript;

        try self.sendVoiceButtons(chat_id, msg);
    }

    // --- Callbacks ---

    fn handleCallback(
        self: *Bot,
        cb: std.json.Value,
    ) !void {
        const cb_id = cb.object.get("id") orelse return;
        const from = cb.object.get("from") orelse return;
        const user_id = from.object.get("id") orelse return;
        if (user_id.integer != self.owner_id) return;

        const data_val = cb.object.get("data") orelse return;
        const data = data_val.string;
        const msg = cb.object.get("message") orelse return;
        const chat = msg.object.get("chat") orelse return;
        const chat_id = chat.object.get("id") orelse return;

        self.answerCallbackQuery(cb_id.string) catch {};

        if (std.mem.eql(u8, data, "approve")) {
            if (self.pending == .transcript) {
                const t = self.pending.transcript;
                const text = self.allocator.dupe(u8, t) catch {
                    try self.sendMessage(
                        chat_id.integer,
                        self.s(.err_memory),
                    );
                    return;
                };
                defer self.allocator.free(text);
                self.clearPending();
                try self.handleMeal(chat_id.integer, text);
            } else {
                try self.sendMessage(
                    chat_id.integer,
                    self.s(.no_pending_transcript),
                );
            }
        } else if (std.mem.eql(u8, data, "edit")) {
            self.pending = .edit;
            try self.sendMessage(
                chat_id.integer,
                self.s(.voice_edit_prompt),
            );
        } else if (std.mem.eql(u8, data, "confirm")) {
            if (self.pending == .command) {
                const cmd = self.pending.command;
                const text = self.allocator.dupe(
                    u8,
                    cmd,
                ) catch {
                    try self.sendMessage(
                        chat_id.integer,
                        self.s(.err_memory),
                    );
                    return;
                };
                defer self.allocator.free(text);
                self.clearPending();
                try self.dispatchCommand(
                    chat_id.integer,
                    text,
                );
            } else {
                try self.sendMessage(
                    chat_id.integer,
                    self.s(.no_pending_command),
                );
            }
        } else if (std.mem.eql(u8, data, "cancel")) {
            self.clearPending();
            try self.sendMessage(
                chat_id.integer,
                self.s(.cancelled),
            );
        }
    }

    // --- Notifications ---

    fn maybeRunNotifications(self: *Bot) void {
        const ts = Io.Timestamp.now(self.io, .real);
        const now = ts.toSeconds();
        if (now - self.last_notif_check < 300) return;
        self.last_notif_check = now;

        const today = getToday(self.io);
        const hour = getHourCET(self.io);

        const loc = self.locale;

        var buf: [512]u8 = undefined;
        if (notif.checkWaterReminder(
            self.db, &today, hour, loc, &buf,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf2: [512]u8 = undefined;
        if (notif.checkProteinDeficit(
            self.db, &today, hour, loc, &buf2,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf3: [512]u8 = undefined;
        if (notif.checkPurine72h(
            self.db, &today, loc, &buf3,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf4: [512]u8 = undefined;
        if (notif.checkAntiCatabolic(
            self.db, &today, loc, &buf4,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf5: [512]u8 = undefined;
        if (notif.checkInjection(
            self.db, &today, hour, loc, &buf5,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf6: [512]u8 = undefined;
        if (notif.checkForceFeed(
            self.db, &today, hour, loc, &buf6,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf7: [512]u8 = undefined;
        if (notif.checkPurineSentry(
            self.db, &today, hour, loc, &buf7,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }
    }

    fn checkPostMealAlerts(
        self: *Bot,
        date: []const u8,
        calories: i64,
        fat: f64,
    ) void {
        const hour = getHourCET(self.io);

        var buf: [512]u8 = undefined;
        if (notif.checkConcreteIndex(
            self.db, date, self.locale, &buf,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }

        var buf2: [512]u8 = undefined;
        if (notif.checkStomachLoad(
            self.db, date, hour, calories, fat,
            self.locale, &buf2,
        )) |m| {
            self.sendMessage(self.owner_id, m) catch {};
        }
    }

    // --- Telegram API helpers ---

    fn downloadTelegramFile(
        self: *Bot,
        file_id: []const u8,
    ) ![]const u8 {
        var url_buf: [512]u8 = undefined;
        const url = std.fmt.bufPrint(
            &url_buf,
            "https://api.telegram.org/bot{s}"
                ++ "/getFile?file_id={s}",
            .{ self.bot_token, file_id },
        ) catch return error.UrlTooLong;

        const file_info = try self.telegramGet(url);
        defer self.allocator.free(file_info);

        const parsed = std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            file_info,
            .{},
        ) catch return error.InvalidResponse;
        defer parsed.deinit();

        const result = parsed.value.object.get("result") orelse
            return error.InvalidResponse;
        const fp = result.object.get("file_path") orelse
            return error.InvalidResponse;
        const file_path = fp.string;

        var dl_url_buf: [512]u8 = undefined;
        const dl_url = std.fmt.bufPrint(
            &dl_url_buf,
            "https://api.telegram.org/file/bot{s}/{s}",
            .{ self.bot_token, file_path },
        ) catch return error.UrlTooLong;

        return try self.telegramGet(dl_url);
    }

    fn telegramGet(
        self: *Bot,
        url: []const u8,
    ) ![]const u8 {
        var client: std.http.Client = .{
            .allocator = self.allocator,
            .io = self.io,
        };
        defer client.deinit();

        const uri = std.Uri.parse(url) catch
            return error.InvalidUrl;

        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();

        var redirect_buf: [1]u8 = undefined;
        var response = try req.receiveHead(&redirect_buf);

        if (response.head.status != .ok) {
            return error.TelegramApiError;
        }

        var transfer_buf: [4096]u8 = undefined;
        const reader = response.reader(&transfer_buf);
        return try reader.allocRemaining(
            self.allocator,
            Io.Limit.limited(20 * 1024 * 1024),
        );
    }

    fn sendConfirmButtons(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        try self.sendWithButtons(
            chat_id,
            text,
            self.s(.btn_yes),
            "confirm",
            self.s(.btn_no),
            "cancel",
        );
    }

    fn sendVoiceButtons(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        try self.sendWithButtons(
            chat_id,
            text,
            self.s(.btn_approve),
            "approve",
            self.s(.btn_edit),
            "edit",
        );
    }

    fn sendWithButtons(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
        btn1_label: []const u8,
        btn1_data: []const u8,
        btn2_label: []const u8,
        btn2_data: []const u8,
    ) !void {
        var client: std.http.Client = .{
            .allocator = self.allocator,
            .io = self.io,
        };
        defer client.deinit();

        const body = std.json.Stringify.valueAlloc(
            self.allocator,
            .{
                .chat_id = chat_id,
                .text = text,
                .reply_markup = .{
                    .inline_keyboard = .{
                        .{
                            .{
                                .text = btn1_label,
                                .callback_data = btn1_data,
                            },
                            .{
                                .text = btn2_label,
                                .callback_data = btn2_data,
                            },
                        },
                    },
                },
            },
            .{},
        ) catch return error.SerializationFailed;
        defer self.allocator.free(body);

        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(
            &url_buf,
            "https://api.telegram.org/bot{s}/sendMessage",
            .{self.bot_token},
        ) catch return error.UrlTooLong;

        const uri = std.Uri.parse(url) catch
            return error.InvalidUrl;

        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{
                    .name = "Content-Type",
                    .value = "application/json",
                },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{
            .content_length = body.len,
        };
        var send_body = try req.sendBodyUnflushed(&.{});
        try send_body.writer.writeAll(body);
        try send_body.end();
        try req.connection.?.flush();

        var redirect_buf: [1]u8 = undefined;
        var response = try req.receiveHead(&redirect_buf);
        var transfer_buf: [1024]u8 = undefined;
        const rdr = response.reader(&transfer_buf);
        _ = rdr.discardRemaining() catch {};
    }

    fn answerCallbackQuery(
        self: *Bot,
        callback_query_id: []const u8,
    ) !void {
        var client: std.http.Client = .{
            .allocator = self.allocator,
            .io = self.io,
        };
        defer client.deinit();

        const body = std.json.Stringify.valueAlloc(
            self.allocator,
            .{ .callback_query_id = callback_query_id },
            .{},
        ) catch return error.SerializationFailed;
        defer self.allocator.free(body);

        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(
            &url_buf,
            "https://api.telegram.org/bot{s}"
                ++ "/answerCallbackQuery",
            .{self.bot_token},
        ) catch return error.UrlTooLong;

        const uri = std.Uri.parse(url) catch
            return error.InvalidUrl;

        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{
                    .name = "Content-Type",
                    .value = "application/json",
                },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{
            .content_length = body.len,
        };
        var send_body = try req.sendBodyUnflushed(&.{});
        try send_body.writer.writeAll(body);
        try send_body.end();
        try req.connection.?.flush();

        var redirect_buf: [1]u8 = undefined;
        var response = try req.receiveHead(&redirect_buf);
        var transfer_buf: [1024]u8 = undefined;
        const rdr = response.reader(&transfer_buf);
        _ = rdr.discardRemaining() catch {};
    }

    fn sendMessage(
        self: *Bot,
        chat_id: i64,
        text: []const u8,
    ) !void {
        var client: std.http.Client = .{
            .allocator = self.allocator,
            .io = self.io,
        };
        defer client.deinit();

        const body = std.json.Stringify.valueAlloc(
            self.allocator,
            .{
                .chat_id = chat_id,
                .text = text,
            },
            .{},
        ) catch return error.SerializationFailed;
        defer self.allocator.free(body);

        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(
            &url_buf,
            "https://api.telegram.org/bot{s}/sendMessage",
            .{self.bot_token},
        ) catch return error.UrlTooLong;

        const uri = std.Uri.parse(url) catch
            return error.InvalidUrl;

        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{
                    .name = "Content-Type",
                    .value = "application/json",
                },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{
            .content_length = body.len,
        };
        var send_body = try req.sendBodyUnflushed(&.{});
        try send_body.writer.writeAll(body);
        try send_body.end();
        try req.connection.?.flush();

        var redirect_buf: [1]u8 = undefined;
        var response = try req.receiveHead(&redirect_buf);
        var transfer_buf: [1024]u8 = undefined;
        const reader = response.reader(&transfer_buf);
        _ = reader.discardRemaining() catch {};
    }
};

fn getToday(io: Io) [10]u8 {
    const ts = Io.Timestamp.now(io, .real);
    const secs: u64 = @intCast(ts.toSeconds());
    const epoch = std.time.epoch.EpochSeconds{ .secs = secs };
    const day = epoch.getEpochDay();
    const yd = day.calculateYearDay();
    const ymd = yd.calculateMonthDay();

    var buf: [10]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        yd.year,
        @intFromEnum(ymd.month),
        ymd.day_index + 1,
    }) catch unreachable;
    return buf;
}

fn getHourCET(io: Io) u8 {
    const ts = Io.Timestamp.now(io, .real);
    const secs: u64 = @intCast(ts.toSeconds());
    const cet = secs + 3600; // UTC+1
    const day_secs = cet % 86400;
    return @intCast(day_secs / 3600);
}

const InjectionArgs = struct {
    dose_mg: f64,
    site_buf: [16]u8,
    site_len: usize,
    notes_start: usize,
    has_notes: bool,

    fn site(self: *const InjectionArgs) []const u8 {
        return self.site_buf[0..self.site_len];
    }
};

fn parseInjectionText(
    text: []const u8,
    default_dose: f64,
    default_site: []const u8,
) InjectionArgs {
    var result = InjectionArgs{
        .dose_mg = default_dose,
        .site_buf = undefined,
        .site_len = @min(default_site.len, 16),
        .notes_start = 0,
        .has_notes = false,
    };
    @memcpy(
        result.site_buf[0..result.site_len],
        default_site[0..result.site_len],
    );
    if (text.len == 0) return result;

    var pos: usize = 0;

    // Try parsing dose number (e.g. "2.5", "5", "7.5")
    var num_end: usize = 0;
    for (text[pos..], 0..) |c, i| {
        if ((c >= '0' and c <= '9') or c == '.') {
            num_end = pos + i + 1;
        } else break;
    }
    if (num_end > pos) {
        if (std.fmt.parseFloat(f64, text[pos..num_end])) |v| {
            result.dose_mg = v;
            pos = num_end;
            while (pos < text.len and text[pos] == ' ')
                pos += 1;
        } else |_| {}
    }

    // Try matching a known injection site
    for (kinetics.injection_sites) |known| {
        if (pos + known.len <= text.len and
            std.mem.eql(u8, text[pos .. pos + known.len], known))
        {
            result.site_len = known.len;
            @memcpy(
                result.site_buf[0..known.len],
                known,
            );
            pos += known.len;
            while (pos < text.len and text[pos] == ' ')
                pos += 1;
            break;
        }
    }

    if (pos < text.len) {
        result.notes_start = pos;
        result.has_notes = true;
    }
    return result;
}
