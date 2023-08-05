const std = @import("std");

const core = @import("core/common.zig");
const ecs = @import("ecs/main.zig");

const display = @import("video/platform_impl/windows/display.zig");

const World = ecs.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const displays = try display.availableDisplays(allocator);
    defer allocator.free(displays);

    for (displays) |disp| {
        if (try disp.getName(allocator)) |name| {
            defer allocator.free(name);
            std.debug.print("{s}\n", .{name});
        }
        const modes = try disp.getVideoModes(allocator);
        defer allocator.free(modes);
        for (modes) |*mode| {
            std.debug.print("    {d}x{d} {d}Hz\n", .{
                mode.size.@"0",
                mode.size.@"1",
                mode.refresh_rate,
            });
            mode.deinit(allocator);
        }
    }
}

test {
    std.testing.refAllDecls(core);
    std.testing.refAllDecls(ecs);
}
