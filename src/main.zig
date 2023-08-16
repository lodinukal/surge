const std = @import("std");

const common = @import("core/common.zig");
const ecs = @import("ecs/main.zig");

const display = @import("video/display.zig");
const icon = @import("video/platform_impl/windows/icon.zig");

const World = ecs.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const displays = try display.DisplayHandle.availableDisplays(allocator);
    defer allocator.free(displays);

    var ico = try icon.WinIcon.fromDefaultResource(32512);
    std.debug.print("ico: {d}\n", .{ico.handle});

    for (displays) |disp| {
        if (try disp.getName(allocator)) |name| {
            defer allocator.free(name);
            std.debug.print("{s}\n", .{name});
        }
        const modes = try disp.getVideoModes(allocator);
        defer allocator.free(modes);
        for (modes) |*mode| {
            std.debug.print("    {d}x{d} {d}Hz\n", .{
                mode.getSize().width,
                mode.getSize().height,
                mode.getRefreshRate(),
            });
            mode.deinit(allocator);
        }
    }
}

test {
    std.testing.refAllDecls(common);
    std.testing.refAllDecls(ecs);
}
