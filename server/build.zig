const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zqlite_dep = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });

    const skip_frontend = b.option(
        bool,
        "skip-frontend",
        "Skip building the frontend (use pre-built ui/)",
    ) orelse false;

    const embedded_ui_mod = b.addModule("embedded_ui", .{
        .root_source_file = b.path("embedded_ui.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "metos-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zqlite", .module = zqlite_dep.module("zqlite") },
                .{ .name = "embedded_ui", .module = embedded_ui_mod },
            },
        }),
    });

    if (!skip_frontend) {
        const frontend_install = b.addSystemCommand(
            &.{ "bun", "install" },
        );
        frontend_install.setCwd(b.path("frontend"));

        const frontend_build = b.addSystemCommand(
            &.{ "bun", "run", "build" },
        );
        frontend_build.setCwd(b.path("frontend"));
        frontend_build.step.dependOn(&frontend_install.step);

        exe.step.dependOn(&frontend_build.step);
    }
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the server");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
