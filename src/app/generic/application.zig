const std = @import("std");

const math = @import("../../core/math.zig");

pub const ModifierKey = packed struct {
    control: bool = false,
    shift: bool = false,
    alt: bool = false,
    command: bool = false,
};

pub const PopUpOrientation = enum {
    horizontal,
    vertical,
};

pub const ModifierKeysState = packed struct {
    is_left_shift_down: bool = false,
    is_right_shift_down: bool = false,
    is_left_control_down: bool = false,
    is_right_control_down: bool = false,
    is_left_alt_down: bool = false,
    is_right_alt_down: bool = false,
    is_left_command_down: bool = false,
    is_right_command_down: bool = false,
    are_caps_locked: bool = false,

    pub fn isShiftDown(self: ModifierKeysState) bool {
        return self.is_left_shift_down || self.is_right_shift_down;
    }

    pub fn isControlDown(self: ModifierKeysState) bool {
        return self.is_left_control_down || self.is_right_control_down;
    }

    pub fn isAltDown(self: ModifierKeysState) bool {
        return self.is_left_alt_down || self.is_right_alt_down;
    }

    pub fn isCommandDown(self: ModifierKeysState) bool {
        return self.is_left_command_down || self.is_right_command_down;
    }

    pub fn isAnyModifierDown(self: ModifierKeysState) bool {
        return self.isShiftDown() || self.isControlDown() || self.isAltDown() || self.isCommandDown();
    }

    pub fn areModifiersDown(self: ModifierKeysState, mods: ModifierKey) bool {
        return (mods.control == self.isControlDown()) and
            (mods.shift == self.isShiftDown()) and
            (mods.alt == self.isAltDown()) and
            (mods.command == self.isCommandDown());
    }
};

pub const PlatformRect = struct {
    left: i32 = 0,
    top: i32 = 0,
    right: i32 = 0,
    bottom: i32 = 0,

    pub fn init(left: ?i32, top: ?i32, right: ?i32, bottom: ?i32) PlatformRect {
        return PlatformRect{
            .left = left orelse 0,
            .top = top orelse 0,
            .right = right orelse 0,
            .bottom = bottom orelse 0,
        };
    }

    pub fn width(self: PlatformRect) i32 {
        return self.right - self.left;
    }

    pub fn height(self: PlatformRect) i32 {
        return self.bottom - self.top;
    }

    pub fn contains(self: PlatformRect, x: i32, y: i32) bool {
        return (x >= self.left) and (x < self.right) and (y >= self.top) and (y < self.bottom);
    }
};

pub const MonitorInfo = struct {
    name: []const u8,
    id: []const u8,
    native_width: i32 = 0,
    native_height: i32 = 0,
    max_resolution: math.IntPoint(i32),
    display_rect: PlatformRect,
    work_rect: PlatformRect,
    is_primary: bool = false,
    dpi: i32 = 0,
};
