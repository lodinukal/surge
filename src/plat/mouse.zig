const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../core/common.zig");
const input_enums = @import("../core/input_enums.zig");

const platform_mouse = switch (builtin.os.tag) {
    .windows => @import("windows/mouse.zig"),
    inline else => @panic("Unsupported OS"),
};

pub fn setMouseMode(mode: MouseMode) void {
    platform_mouse.setMouseMode(mode);
}
pub fn getMouseMode() MouseMode {
    return platform_mouse.getMouseMode();
}

pub fn warpMouse(position: common.Vec2i) void {
    platform_mouse.warpMouse(position);
}
pub fn getMousePosition() common.Vec2i {
    return platform_mouse.getMousePosition();
}
pub fn getMouseButtonState() input_enums.MouseButtonState {
    return platform_mouse.getMouseButtonState();
}

pub const MouseMode = enum {
    visible,
    hidden,
    captured,
    confined,
    confined_hidden,
};
