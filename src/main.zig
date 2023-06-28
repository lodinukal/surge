const std = @import("std");

const core = @import("core/common.zig");
const ecs = @import("ecs/main.zig");
const plat = @import("plat/main.zig");

const World = ecs.World;

pub fn main() !void {
    plat.mouse.setMouseMode(plat.mouse.MouseMode.confined);

    var x = core.Point2f{ .x = 15, .y = 15 };
    var y = core.Point2f{ .x = 20, .y = 20 };

    std.debug.print("sub! {}\n", .{y.sub(x)});

    std.debug.print("display_count: {}\n", .{plat.display.getDisplayCount()});
}

test "run all tests" {
    std.testing.refAllDeclsRecursive(core);
    std.testing.refAllDeclsRecursive(ecs);
    std.testing.refAllDeclsRecursive(plat);
}
