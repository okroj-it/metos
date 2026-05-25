const std = @import("std");
const Io = std.Io;

pub const Config = struct {
    db_path: [*:0]const u8,
    port: ?u16,
    password: ?[]const u8,
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

    var db_path: ?[]const u8 = null;
    var port_str: ?[]const u8 = null;
    var password: ?[]const u8 = null;

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

        if (std.mem.eql(u8, key, "db_path")) {
            db_path = val;
        } else if (std.mem.eql(u8, key, "port")) {
            port_str = val;
        } else if (std.mem.eql(u8, key, "password")) {
            password = val;
        }
    }

    return Config{
        .db_path = if (db_path) |p|
            try allocator.dupeSentinel(u8, p, 0)
        else
            "metos.db",
        .port = if (port_str) |p|
            std.fmt.parseInt(u16, p, 10) catch null
        else
            null,
        .password = if (password) |pw|
            try allocator.dupe(u8, pw)
        else
            null,
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
