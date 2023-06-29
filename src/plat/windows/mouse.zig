const std = @import("std");
const testing = std.testing;

const common = @import("../../core/common.zig");
const input_enums = @import("../../core/input_enums.zig");
const mouse = @import("../mouse.zig");

pub fn setMouseMode(mode: mouse.MouseMode) void {
    std.debug.print("windows: mouse {}!\n", .{mode});
}
pub fn getMouseMode() mouse.MouseMode {
    return mouse.MouseMode.confined;
}

pub fn warpMouse(position: common.Vec2i) void {
    std.debug.print("windows: warp mouse to {}!\n", .{position});
}
pub fn getMousePosition() common.Vec2i {
    return common.Vec2i{ .x = 0, .y = 0 };
}
pub fn getMouseButtonState() input_enums.MouseButtonState {
    return input_enums.MouseButtonState{};
}
