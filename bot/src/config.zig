const std = @import("std");
const Io = std.Io;
const strings = @import("strings");

pub const Config = struct {
    gemini_api_key: ?[]const u8,
    telegram_bot_token: ?[]const u8,
    db_path: [*:0]const u8,
    owner_id: ?i64,
    port: ?u16,
    locale: strings.Locale,
};

pub fn load(
    allocator: std.mem.Allocator,
    io: Io,
    path: []const u8,
) !Config {
    const dir = Io.Dir.cwd();
    const content = dir.readFileAlloc(
        io,
        path,
        allocator,
        Io.Limit.limited(64 * 1024),
    ) catch return error.ConfigNotFound;
    defer allocator.free(content);

    var gemini_key: ?[]const u8 = null;
    var bot_token: ?[]const u8 = null;
    var db_path: ?[]const u8 = null;
    var owner_id_str: ?[]const u8 = null;
    var port_str: ?[]const u8 = null;
    var locale_str: ?[]const u8 = null;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        const eq = std.mem.indexOfScalar(u8, trimmed, '=') orelse
            continue;
        const key = std.mem.trimEnd(
            u8,
            trimmed[0..eq],
            " \t",
        );
        const raw_val = std.mem.trimStart(
            u8,
            trimmed[eq + 1 ..],
            " \t",
        );
        const val = stripQuotes(raw_val);

        if (std.mem.eql(u8, key, "gemini_api_key")) {
            gemini_key = val;
        } else if (std.mem.eql(u8, key, "telegram_bot_token")) {
            bot_token = val;
        } else if (std.mem.eql(u8, key, "db_path")) {
            db_path = val;
        } else if (std.mem.eql(u8, key, "owner_id")) {
            owner_id_str = val;
        } else if (std.mem.eql(u8, key, "port")) {
            port_str = val;
        } else if (std.mem.eql(u8, key, "locale")) {
            locale_str = val;
        }
    }

    return Config{
        .gemini_api_key = if (gemini_key) |k|
            try allocator.dupe(u8, k)
        else
            null,
        .telegram_bot_token = if (bot_token) |t|
            try allocator.dupe(u8, t)
        else
            null,
        .db_path = if (db_path) |p|
            try allocator.dupeSentinel(u8, p, 0)
        else
            "metos.db",
        .owner_id = if (owner_id_str) |oid|
            std.fmt.parseInt(i64, oid, 10) catch null
        else
            null,
        .port = if (port_str) |p|
            std.fmt.parseInt(u16, p, 10) catch null
        else
            null,
        .locale = if (locale_str) |l|
            std.meta.stringToEnum(strings.Locale, l) orelse .en
        else
            .en,
    };
}

fn stripQuotes(s: []const u8) []const u8 {
    if (s.len >= 2) {
        if ((s[0] == '"' and s[s.len - 1] == '"') or
            (s[0] == '\'' and s[s.len - 1] == '\''))
        {
            return s[1 .. s.len - 1];
        }
    }
    return s;
}
