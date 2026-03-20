const std = @import("std");
const http = std.http;
const net = std.Io.net;
const Io = std.Io;
const database = @import("db.zig");
const kinetics = @import("kinetics");
const embedded_ui = @import("embedded_ui");
const Auth = @import("auth.zig").Auth;

const json_headers: []const http.Header = &.{
    .{ .name = "Content-Type", .value = "application/json" },
    .{ .name = "Access-Control-Allow-Origin", .value = "*" },
};

pub const Server = struct {
    db: database.Db,
    tcp: net.Server,
    io: Io,
    allocator: std.mem.Allocator,
    auth: Auth,

    pub fn init(
        allocator: std.mem.Allocator,
        io: Io,
        db_path: [*:0]const u8,
        port: u16,
        password: []const u8,
    ) !Server {
        const db_inst = try database.Db.open(db_path);
        errdefer db_inst.close();

        const address = net.IpAddress{
            .ip4 = .{ .bytes = .{ 0, 0, 0, 0 }, .port = port },
        };
        const tcp = try address.listen(io, .{ .reuse_address = true });

        std.log.info("dashboard listening on :{d}", .{port});

        return .{
            .db = db_inst,
            .tcp = tcp,
            .io = io,
            .allocator = allocator,
            .auth = Auth.init(io, password),
        };
    }

    pub fn deinit(self: *Server) void {
        self.tcp.deinit(self.io);
        self.db.close();
    }

    pub fn run(self: *Server) !void {
        while (true) {
            var stream = self.tcp.accept(self.io) catch |err| {
                std.log.err("accept error: {s}", .{@errorName(err)});
                continue;
            };
            self.handleConnection(&stream) catch |err| {
                std.log.err("request error: {s}", .{@errorName(err)});
            };
            stream.close(self.io);
        }
    }

    fn handleConnection(
        self: *Server,
        stream: *net.Stream,
    ) !void {
        var recv_buf: [8192]u8 = undefined;
        var send_buf: [8192]u8 = undefined;
        var reader = stream.reader(self.io, &recv_buf);
        var writer = stream.writer(self.io, &send_buf);
        var srv = http.Server.init(
            &reader.interface,
            &writer.interface,
        );

        var request = srv.receiveHead() catch |err| {
            std.log.err(
                "failed to receive head: {s}",
                .{@errorName(err)},
            );
            return;
        };

        self.route(&request) catch |err| {
            std.log.err("route error: {s}", .{@errorName(err)});
            request.respond(
                "{\"error\":\"internal error\"}",
                .{ .status = .internal_server_error },
            ) catch {};
        };
    }

    fn route(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const target = request.head.target;

        // Login — no auth required
        if (std.mem.startsWith(u8, target, "/api/auth/login")) {
            try self.apiLogin(request);
            return;
        }

        // Protected API routes — check JWT
        if (std.mem.startsWith(u8, target, "/api/")) {
            if (!self.checkAuth(request)) {
                try request.respond(
                    "{\"error\":\"unauthorized\"}",
                    .{ .status = .unauthorized },
                );
                return;
            }

            if (std.mem.startsWith(u8, target, "/api/config")) {
                try self.apiConfig(request);
            } else if (std.mem.startsWith(u8, target, "/api/stats")) {
                try self.apiStats(request);
            } else if (std.mem.startsWith(u8, target, "/api/meals")) {
                try self.apiMeals(request);
            } else if (std.mem.startsWith(u8, target, "/api/weight")) {
                try self.apiWeight(request);
            } else if (std.mem.startsWith(u8, target, "/api/water")) {
                try self.apiWater(request);
            } else if (std.mem.startsWith(u8, target, "/api/goal")) {
                try self.apiGoal(request);
            } else if (std.mem.startsWith(u8, target, "/api/analytics")) {
                try self.apiAnalytics(request);
            } else if (std.mem.startsWith(u8, target, "/api/kinetics")) {
                try self.apiKinetics(request);
            } else if (std.mem.startsWith(u8, target, "/api/injection")) {
                try self.apiInjection(request);
            } else {
                try request.respond(
                    "{\"error\":\"not found\"}",
                    .{ .status = .not_found },
                );
            }
            return;
        }

        // Static assets — no auth (SPA needs to load for login)
        if (embedded_ui.get(target)) |asset| {
            const cache = if (std.mem.endsWith(
                u8,
                asset.content_type,
                "html; charset=utf-8",
            ))
                "no-cache"
            else
                "public, max-age=31536000, immutable";

            try request.respond(asset.content, .{
                .extra_headers = &.{
                    .{
                        .name = "Content-Type",
                        .value = asset.content_type,
                    },
                    .{ .name = "Cache-Control", .value = cache },
                },
            });
        } else {
            try request.respond(
                "{\"error\":\"not found\"}",
                .{ .status = .not_found },
            );
        }
    }

    fn checkAuth(
        self: *Server,
        request: *http.Server.Request,
    ) bool {
        const now = self.getNow();
        var it = request.iterateHeaders();
        while (it.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "authorization")) {
                if (std.mem.startsWith(u8, header.value, "Bearer ")) {
                    const token = header.value["Bearer ".len..];
                    return self.auth.validateToken(token, now);
                }
            }
        }
        return false;
    }

    fn getNow(self: *Server) i64 {
        const ts = Io.Timestamp.now(self.io, .real);
        return ts.toSeconds();
    }

    fn apiLogin(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        if (request.head.method != .POST) {
            try request.respond(
                "{\"error\":\"method not allowed\"}",
                .{ .status = .method_not_allowed },
            );
            return;
        }

        var read_buf: [1024]u8 = undefined;
        const body_reader = request.readerExpectNone(&read_buf);
        const body = body_reader.allocRemaining(
            self.allocator,
            Io.Limit.limited(4096),
        ) catch {
            try request.respond(
                "{\"error\":\"bad request\"}",
                .{ .status = .bad_request },
            );
            return;
        };
        defer self.allocator.free(body);

        const LoginReq = struct { password: []const u8 };
        const parsed = std.json.parseFromSlice(
            LoginReq,
            self.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        ) catch {
            try request.respond(
                "{\"error\":\"invalid json\"}",
                .{ .status = .bad_request },
            );
            return;
        };
        defer parsed.deinit();

        if (!self.auth.checkPassword(parsed.value.password)) {
            try request.respond(
                "{\"error\":\"invalid password\"}",
                .{ .status = .unauthorized },
            );
            return;
        }

        const now = self.getNow();
        const token = self.auth.createToken(
            self.allocator,
            now,
        ) catch {
            try request.respond(
                "{\"error\":\"token creation failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(token);

        const resp = std.json.Stringify.valueAlloc(
            self.allocator,
            .{ .token = token },
            .{},
        ) catch {
            try request.respond(
                "{\"error\":\"serialization failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(resp);

        try request.respond(resp, .{
            .extra_headers = json_headers,
        });
    }

    fn getDateParam(target: []const u8, today: *const [10]u8) []const u8 {
        if (std.mem.indexOf(u8, target, "?date=")) |idx| {
            const rest = target[idx + 6 ..];
            if (rest.len >= 10) return rest[0..10];
        }
        return today;
    }

    fn apiConfig(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const cfg = self.db.getUserConfig() orelse
            database.UserConfig{
            .gout_tracking = true,
            .glp1_tracking = true,
        };
        const body = std.json.Stringify.valueAlloc(
            self.allocator,
            .{
                .gout_tracking = cfg.gout_tracking,
                .glp1_tracking = cfg.glp1_tracking,
            },
            .{},
        ) catch return error.SerializationFailed;
        defer self.allocator.free(body);
        try request.respond(
            body,
            .{ .extra_headers = json_headers },
        );
    }

    fn apiStats(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const today = getToday(self.io);
        const date = getDateParam(request.head.target, &today);

        const summary = self.db.getDailySummary(date) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        if (summary == null) {
            try request.respond("null", .{
                .extra_headers = json_headers,
            });
            return;
        }

        const json = std.json.Stringify.valueAlloc(
            self.allocator,
            summary.?,
            .{},
        ) catch {
            try request.respond(
                "{\"error\":\"serialization failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiMeals(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const today = getToday(self.io);
        const date = getDateParam(request.head.target, &today);

        const json = self.db.getMealsJson(
            self.allocator,
            date,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiWeight(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const json = self.db.getWeightJson(self.allocator) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiWater(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const today = getToday(self.io);
        const date = getDateParam(request.head.target, &today);

        const total = self.db.getDailyWater(date) catch 0;
        const high = self.db.hasHighPurine(date) catch false;
        const bonus: i64 = if (high) 250 else 0;
        const json = std.json.Stringify.valueAlloc(
            self.allocator,
            .{ .total_ml = total, .purine_bonus_ml = bonus },
            .{},
        ) catch {
            try request.respond(
                "{\"error\":\"serialization failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiGoal(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const goal = self.db.getGoal() catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        if (goal == null) {
            try request.respond("null", .{
                .extra_headers = json_headers,
            });
            return;
        }

        const json = std.json.Stringify.valueAlloc(
            self.allocator,
            goal.?,
            .{},
        ) catch {
            try request.respond(
                "{\"error\":\"serialization failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }
    fn apiAnalytics(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const today = getToday(self.io);
        const days = getDaysParam(request.head.target) orelse 7;
        var from_buf: [10]u8 = undefined;
        const from = daysAgo(self.io, days, &from_buf);

        const json = self.db.getAnalyticsJson(
            self.allocator,
            from,
            &today,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiKinetics(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const today = getToday(self.io);
        const hour = getHourCET(self.io);

        const recent = self.db.getRecentInjections(
            &today,
            hour,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        const has_doses = recent.len > 0;
        const hours_since = if (has_doses)
            recent.records[0].hours_ago
        else
            0.0;

        // Build JSON: {"curve":[...],"history":[...]}
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(self.allocator);
        try out.appendSlice(
            self.allocator,
            "{\"curve\":[",
        );

        // Curve: 0–168h in 1h steps
        var h: u16 = 0;
        while (h <= 168) : (h += 1) {
            if (h > 0) try out.appendSlice(
                self.allocator,
                ",",
            );
            const t: f64 = @floatFromInt(h);

            var shifted: [8]kinetics.Dose = undefined;
            for (0..recent.len) |i| {
                shifted[i] = .{
                    .hours_ago = recent.records[i]
                        .hours_ago - t,
                    .dose_mg = recent.records[i].dose_mg,
                };
            }

            const plasma = kinetics.plasmaLevel(
                shifted[0..recent.len],
            );
            const sup: f32 = if (has_doses)
                kinetics.appetiteSuppression(
                    hours_since + t,
                )
            else
                0.0;

            var pt_buf: [128]u8 = undefined;
            const pt = std.fmt.bufPrint(
                &pt_buf,
                "{{\"hour\":{d},"
                    ++ "\"plasma\":{d:.3},"
                    ++ "\"suppression\":{d:.3}}}",
                .{ h, plasma, @as(f64, sup) },
            ) catch continue;
            try out.appendSlice(self.allocator, pt);
        }

        try out.appendSlice(
            self.allocator,
            "],\"history\":",
        );

        const history = self.db.getInjectionHistoryJson(
            self.allocator,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(history);

        try out.appendSlice(self.allocator, history);
        try out.appendSlice(self.allocator, "}");

        const json = try out.toOwnedSlice(self.allocator);
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiInjection(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        if (request.head.method == .POST) {
            try self.apiInjectionPost(request);
            return;
        }
        try self.apiInjectionGet(request);
    }

    fn apiInjectionGet(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        const today = getToday(self.io);
        const hour = getHourCET(self.io);
        const info = self.db.getLatestInjection(
            &today,
            hour,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        if (info == null) {
            try request.respond("null", .{
                .extra_headers = json_headers,
            });
            return;
        }

        const data = info.?;
        const recent = self.db.getRecentInjections(
            &today,
            hour,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        var doses: [8]kinetics.Dose = undefined;
        for (0..recent.len) |i| {
            doses[i] = .{
                .hours_ago = recent.records[i].hours_ago,
                .dose_mg = recent.records[i].dose_mg,
            };
        }
        const plasma = kinetics.plasmaLevel(
            doses[0..recent.len],
        );
        const suppression = kinetics.appetiteSuppression(
            data.hours_since,
        );

        const json = std.json.Stringify.valueAlloc(
            self.allocator,
            .{
                .injection_date = data.date(),
                .days_since = data.days_since,
                .dose_mg = data.dose_mg,
                .site = data.site(),
                .hours_since = data.hours_since,
                .plasma_level = plasma,
                .suppression = suppression,
            },
            .{},
        ) catch {
            try request.respond(
                "{\"error\":\"serialization failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };
        defer self.allocator.free(json);

        try request.respond(json, .{
            .extra_headers = json_headers,
        });
    }

    fn apiInjectionPost(
        self: *Server,
        request: *http.Server.Request,
    ) !void {
        var read_buf: [1024]u8 = undefined;
        const body_reader = request.readerExpectNone(&read_buf);
        const body = body_reader.allocRemaining(
            self.allocator,
            Io.Limit.limited(4096),
        ) catch {
            try request.respond(
                "{\"error\":\"bad request\"}",
                .{ .status = .bad_request },
            );
            return;
        };
        defer self.allocator.free(body);

        const InjReq = struct {
            dose_mg: ?f64 = null,
            site: ?[]const u8 = null,
        };
        const parsed = std.json.parseFromSlice(
            InjReq,
            self.allocator,
            body,
            .{ .ignore_unknown_fields = true },
        ) catch {
            try request.respond(
                "{\"error\":\"invalid json\"}",
                .{ .status = .bad_request },
            );
            return;
        };
        defer parsed.deinit();

        const today = getToday(self.io);
        const dose = parsed.value.dose_mg orelse
            (self.db.getLastDose() catch 2.5);

        self.db.insertInjection(
            &today,
            dose,
            parsed.value.site,
        ) catch {
            try request.respond(
                "{\"error\":\"insert failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        // Re-fetch to return updated data with PK
        const hour = getHourCET(self.io);
        const info = self.db.getLatestInjection(
            &today,
            hour,
        ) catch {
            try request.respond(
                "{\"error\":\"query failed\"}",
                .{ .status = .internal_server_error },
            );
            return;
        };

        if (info) |data| {
            const recent = self.db.getRecentInjections(
                &today,
                hour,
            ) catch {
                try request.respond(
                    "{\"error\":\"query failed\"}",
                    .{ .status = .internal_server_error },
                );
                return;
            };

            var doses: [8]kinetics.Dose = undefined;
            for (0..recent.len) |i| {
                doses[i] = .{
                    .hours_ago = recent.records[i].hours_ago,
                    .dose_mg = recent.records[i].dose_mg,
                };
            }
            const plasma = kinetics.plasmaLevel(
                doses[0..recent.len],
            );
            const suppression = kinetics.appetiteSuppression(
                data.hours_since,
            );

            const json = std.json.Stringify.valueAlloc(
                self.allocator,
                .{
                    .injection_date = data.date(),
                    .days_since = data.days_since,
                    .dose_mg = data.dose_mg,
                    .site = data.site(),
                    .hours_since = data.hours_since,
                    .plasma_level = plasma,
                    .suppression = suppression,
                },
                .{},
            ) catch {
                try request.respond(
                    "{\"error\":\"serialization failed\"}",
                    .{ .status = .internal_server_error },
                );
                return;
            };
            defer self.allocator.free(json);

            try request.respond(json, .{
                .extra_headers = json_headers,
            });
        } else {
            try request.respond("null", .{
                .extra_headers = json_headers,
            });
        }
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
    const day_secs = secs % 86400;
    const utc_hour: u8 = @intCast(day_secs / 3600);
    return (utc_hour + 1) % 24; // CET = UTC+1
}

fn getDaysParam(target: []const u8) ?u16 {
    if (std.mem.indexOf(u8, target, "?days=")) |idx| {
        const rest = target[idx + 6 ..];
        const end = std.mem.indexOfAny(u8, rest, "&") orelse
            rest.len;
        return std.fmt.parseInt(u16, rest[0..end], 10) catch null;
    }
    return null;
}

fn daysAgo(io: Io, days: u16, buf: *[10]u8) []const u8 {
    const ts = Io.Timestamp.now(io, .real);
    const secs: u64 = @intCast(ts.toSeconds());
    const offset: u64 = @as(u64, days) * 86400;
    const past = std.time.epoch.EpochSeconds{
        .secs = secs -| offset,
    };
    const day = past.getEpochDay();
    const yd = day.calculateYearDay();
    const ymd = yd.calculateMonthDay();
    _ = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        yd.year,
        @intFromEnum(ymd.month),
        ymd.day_index + 1,
    }) catch unreachable;
    return buf;
}
