const std = @import("std");
const Server = @import("server.zig").Server;
const config = @import("config.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const cfg = config.load(allocator, io, "config.toml") catch |err| {
        std.log.err("failed to load config.toml: {s}", .{
            @errorName(err),
        });
        return err;
    };

    const port = cfg.port orelse 3000;
    const password = cfg.password orelse {
        std.log.err("password required in config", .{});
        return error.MissingPassword;
    };

    var server = try Server.init(
        allocator,
        io,
        cfg.db_path,
        port,
        password,
    );
    defer server.deinit();
    try server.run();
}
