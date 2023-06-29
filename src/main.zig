const std = @import("std");

const core = @import("core/common.zig");
const ecs = @import("ecs/main.zig");
const plat = @import("plat/main.zig");

const World = ecs.World;

pub fn main() !void {
    try plat.window.init();
    defer plat.window.deinit();

    var ci = plat.window.WindowCreateInfo{
        .title = "8man",
        .mode = .windowed,
        .rect = core.Rect2i.from_components(
            core.Vec2i.zero(),
            core.Vec2i.init(800, 600),
        ),
        .flags = .{},
    };
    var window = try plat.window.createWindow(ci);

    while (true) {}

    _ = window;
}

test "run all tests" {
    std.testing.refAllDeclsRecursive(core);
    std.testing.refAllDeclsRecursive(ecs);
    std.testing.refAllDeclsRecursive(plat);
}
