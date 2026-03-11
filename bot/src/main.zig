const std = @import("std");
const Bot = @import("telegram.zig").Bot;
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

    const api_key = cfg.gemini_api_key orelse {
        std.log.err("gemini_api_key required", .{});
        return error.MissingGeminiApiKey;
    };
    const bot_token = cfg.telegram_bot_token orelse {
        std.log.err("telegram_bot_token required", .{});
        return error.MissingBotToken;
    };
    const owner_id = cfg.owner_id orelse {
        std.log.err("owner_id required", .{});
        return error.MissingOwnerId;
    };

    var bot = try Bot.init(
        allocator,
        io,
        cfg.db_path,
        api_key,
        bot_token,
        owner_id,
    );
    defer bot.deinit();

    try bot.run();
}
