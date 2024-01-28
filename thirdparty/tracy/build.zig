const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const no_exit = b.option(bool, "no_exit", "should tracy exit") orelse false;

    const tracy_dep = b.dependency("tracy_src", .{});
    const tracy = b.addModule("tracy", .{
        .root_source_file = .{
            .path = "tracy.zig",
        },
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    tracy.addIncludePath(tracy_dep.path("public/tracy/"));
    tracy.addCSourceFile(.{
        .file = tracy_dep.path("public/TracyClient.cpp"),
        .flags = &.{
            "-DTRACY_ENABLE",
            "-fno-sanitize=undefined",
        },
    });
    if (no_exit) {
        tracy.addCMacro("TRACY_NO_EXIT", "");
    }

    if (target.result.os.tag == .windows) {
        tracy.linkSystemLibrary("Advapi32", .{});
        tracy.linkSystemLibrary("User32", .{});
        tracy.linkSystemLibrary("Ws2_32", .{});
        tracy.linkSystemLibrary("DbgHelp", .{});
    } else if (target.result.os.tag == .freebsd) {
        tracy.linkSystemLibrary("execinfo", .{});
    }
}
