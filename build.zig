const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const core = b.addModule("core", .{
        .root_source_file = .{
            .path = "src/core/core.zig",
        },
        .target = target,
        .optimize = optimize,
    });

    const tracy_dep = b.dependency("tracy", .{
        .no_exit = true,
    });
    const tracy = tracy_dep.module("tracy");
    _ = tracy; // autofix

    const app = b.addModule("app", .{
        .root_source_file = .{
            .path = "src/app/app.zig",
        },
        .target = target,
        .optimize = optimize,
    });
    app.addImport("core", core);

    const stb = b.addModule("stb", .{
        .root_source_file = .{
            .path = "thirdparty/stb/image.zig",
        },
        .link_libc = true,
    });
    stb.addIncludePath(.{
        .path = "thirdparty/stb/",
    });
    stb.addCSourceFile(.{ .file = .{
        .path = "thirdparty/stb/stb_image_impl.c",
    } });

    const gpu = b.addModule("gpu", .{
        .root_source_file = .{
            .path = "src/gpu/gpu.zig",
        },
        .target = target,
        .optimize = optimize,
    });
    gpu.addImport("core", core);
    gpu.addImport("app", app);

    const renderer = b.addModule("renderer", .{
        .root_source_file = .{
            .path = "src/renderer/renderer.zig",
        },
        .target = target,
        .optimize = optimize,
    });
    renderer.addImport("core", core);
    renderer.addImport("app", app);
    renderer.addImport("gpu", gpu);

    const rl = b.addModule("rl", .{
        .root_source_file = .{
            .path = "src/rl/rl.zig",
        },
        .target = target,
        .optimize = optimize,
    });
    rl.addImport("core", core);

    // const rlshader = b.addModule("rlshader", .{
    //     .root_source_file = .{
    //         .path = "src/rlshader/rlshader.zig",
    //     },
    //     .target = target,
    //     .optimize = optimize,
    // });
    // rlshader.addImport("core", core);
    // rlshader.addImport("rl", rl);
    // rlshader.addImport("gpu", gpu);

    const exe = b.addExecutable(.{
        .name = "surge",
        .link_libc = false,
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("core", core);
    exe.root_module.addImport("app", app);
    exe.root_module.addImport("gpu", gpu);
    exe.root_module.addImport("renderer", renderer);
    exe.root_module.addImport("stb", stb);
    // exe.root_module.addImport("rlshader", rlshader);
    exe.root_module.addImport("rl", rl);
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

    // const sysgpu_dep = b.dependency("mach-sysgpu", .{});
    // const sysgpu_module = sysgpu_dep.module("mach-sysgpu");
    // exe.addModule("gpu", sysgpu_module);

    if (target.result.os.tag == .windows) {
        const win32_dep = b.dependency("win32", .{});
        const win32 = win32_dep.module("zigwin32");
        app.addImport("win32", win32);

        app.linkSystemLibrary("Imm32", .{ .needed = true });
        app.linkSystemLibrary("Gdi32", .{ .needed = true });
        app.linkSystemLibrary("comctl32", .{ .needed = true });

        const app_windows = b.addModule("app_windows", .{
            .root_source_file = .{
                .path = "src/backends/windows.zig",
            },
            .target = target,
            .optimize = optimize,
        });
        app_windows.addImport("win32", win32);
        app_windows.addImport("core", core);
        app_windows.addImport("app", app);
        app.addImport("app_windows", app_windows);

        const d3d = b.addModule("d3d", .{
            .root_source_file = .{
                .path = "src/backends/d3d/d3d.zig",
            },
            .target = target,
            .optimize = optimize,
        });
        d3d.addImport("gpu", gpu);
        d3d.addImport("win32", win32);

        const d3d12 = b.addSharedLibrary(.{
            .name = "render_d3d12",
            .root_source_file = .{
                .path = "src/backends/d3d12/d3d12.zig",
            },
            .target = target,
            .optimize = optimize,
        });
        d3d12.root_module.addImport("core", core);
        d3d12.root_module.addImport("app", app);
        d3d12.root_module.addImport("gpu", gpu);
        d3d12.root_module.addImport("d3d", d3d);
        d3d12.root_module.addImport("win32", win32);
        b.getInstallStep().dependOn(&b.addInstallArtifact(d3d12, .{ .dest_dir = .{ .override = .bin } }).step);

        b.installBinFile("thirdparty/dxc/x64/dxil.dll", "dxil.dll");
        b.installBinFile("thirdparty/dxc/x64/dxcompiler.dll", "dxcompiler.dll");

        inline for (.{ exe, unit_tests }) |t| {

            // June 2023 Update 3
            linkGdk(b, t, null, "230603", "amd64") catch unreachable;

            // GDK
            // CUrrently uses 221001
            // t.c_std = .C11;
        }

        // buildD3d11(b, target, optimize);
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

const DependencyPair = struct {
    name: []const u8,
    module: *const std.Build.Module,
};
fn waterfallModules(to: *std.Build.Module, from: []const DependencyPair) void {
    for (from) |m| {
        var it = m.module.iterateDependencies(false, false);
        while (it.next()) |dep| {
            if (to.import_table.get(dep.name) == null) {
                to.addImport(dep.name, dep.module);
                if (dep.compile) |c| to.linkLibrary(c);
            }
        }
        if (to.import_table.get(m.name) == null) {
            to.addImport(m.name, m.module);
        }
    }
}
