const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "surge",
        .link_libc = false,
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(std.Build.LazyPath.relative("./src/c"));
    // exe.addSystemIncludePath("");
    // exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const sysgpu_dep = b.dependency("mach-sysgpu", .{});
    const sysgpu_module = sysgpu_dep.module("mach-sysgpu");
    exe.addModule("gpu", sysgpu_module);

    if (target.isWindows()) {
        const win32_dep = b.dependency("win32", .{});
        const win32_module = win32_dep.module("zigwin32");

        inline for (.{ exe, unit_tests }) |t| {
            t.addModule("win32", win32_module);
            t.linkSystemLibraryName("Imm32");
            t.linkSystemLibraryName("Gdi32");
            t.linkSystemLibraryName("comctl32");

            // June 2023 Update 3
            linkGdk(b, t, null, "230603", "amd64") catch unreachable;

            // GDK
            // CUrrently uses 221001
            // t.c_std = .C11;
        }
    }
}

fn linkGdk(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    gdk_host_path: ?[]const u8,
    comptime version: []const u8,
    comptime arch: []const u8,
) !void {
    const using_gdk_host_path = gdk_host_path orelse try std.process.getEnvVarOwned(
        b.allocator,
        "GameDK",
    );

    const gdk_path = try std.fs.path.join(
        b.allocator,
        &[_][]const u8{
            using_gdk_host_path,
            version,
            "GRDK/GameKit",
        },
    );

    const lib_path = try std.fs.path.join(
        b.allocator,
        &[_][]const u8{
            gdk_path,
            "Lib",
            arch,
        },
    );

    exe.addLibraryPath(std.Build.LazyPath{ .path = lib_path });

    exe.linkSystemLibrary("GameInput");
    exe.linkSystemLibrary("xgameruntime");
    exe.linkLibC();
}

fn buildBackend(
    b: *std.Build,
    name: []const u8,
    src: []const u8,
    target: std.zig.CrossTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib = b.addSharedLibrary(.{
        .name = name,
        .link_libc = false,
        .root_source_file = .{ .path = src },
        .main_mod_path = .{ .path = "src" },
        .target = target,
        .optimize = optimize,
    });

    const artifact = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .bin } });
    b.getInstallStep().dependOn(&artifact.step);
    return lib;
}
