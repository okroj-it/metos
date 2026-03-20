const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zqlite_dep = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });

    const core_path = "../core/";
    const core_mods = .{
        .{ "kinetics", "kinetics.zig" },
        .{ "llm", "llm.zig" },
        .{ "strings", "strings.zig" },
        .{ "strings_notif", "strings_notif.zig" },
        .{ "commands", "commands.zig" },
        .{ "notifications", "notifications.zig" },
    };

    var imports: [core_mods.len + 1]std.Build.Module.Import = undefined;
    imports[0] = .{
        .name = "zqlite",
        .module = zqlite_dep.module("zqlite"),
    };
    inline for (core_mods, 0..) |entry, i| {
        imports[i + 1] = .{
            .name = entry[0],
            .module = b.createModule(.{
                .root_source_file = b.path(
                    core_path ++ entry[1],
                ),
            }),
        };
    }
    // Cross-module dependencies within core
    // strings_notif depends on strings
    imports[4].module.addImport(
        "strings",
        imports[3].module,
    );
    // commands depends on kinetics
    imports[5].module.addImport(
        "kinetics",
        imports[1].module,
    );
    // notifications depends on kinetics, strings, strings_notif
    imports[6].module.addImport(
        "kinetics",
        imports[1].module,
    );
    imports[6].module.addImport(
        "strings",
        imports[3].module,
    );
    imports[6].module.addImport(
        "strings_notif",
        imports[4].module,
    );

    const exe = b.addExecutable(.{
        .name = "metos-bot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the bot");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
