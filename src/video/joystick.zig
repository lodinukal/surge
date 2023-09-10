const std = @import("std");
const definitions = @import("definitions.zig");

pub const JoystickConnectionCallback = *fn (joystick: Joystick, connected: bool) void;

pub const Joystick = enum(u8) {
    @"1" = 0,
    @"2" = 1,
    @"3" = 2,
    @"4" = 3,
    @"5" = 4,
    @"6" = 5,
    @"7" = 6,
    @"8" = 7,
    @"9" = 8,
    @"10" = 9,
    @"11" = 10,
    @"12" = 11,
    @"13" = 12,
    @"14" = 13,
    @"15" = 14,
    @"16" = 15,

    pub fn isJoystickPresent(joy: Joystick) definitions.Error!bool {
        _ = joy;
    }

    pub fn getJoystickAxes(joy: Joystick) definitions.Error![]const f32 {
        _ = joy;
    }

    pub fn getJoystickButtons(
        joy: Joystick,
    ) definitions.Error![]const ?definitions.ElementState {
        _ = joy;
    }

    pub fn getJoystickHats(joy: Joystick) definitions.Error![]const definitions.HatState {
        _ = joy;
    }

    pub fn getJoystickName(
        allocator: std.mem.Allocator,
        joy: Joystick,
    ) (std.mem.Allocator.Error | definitions.Error)![]const u8 {
        _ = allocator;
        _ = joy;
    }

    pub fn getJoystickGUID(
        allocator: std.mem.Allocator,
        joy: Joystick,
    ) (std.mem.Allocator.Error | definitions.Error)![]const u8 {
        _ = allocator;
        _ = joy;
    }

    pub fn setJoystickUserPointer(joy: Joystick, pointer: ?*void) definitions.Error!void {
        _ = joy;
        _ = pointer;
    }

    pub fn getJoystickUserPointer(joy: Joystick) definitions.Error!?*void {
        _ = joy;
    }

    pub fn joystickIsGamepad(joy: Joystick) definitions.Error!bool {
        _ = joy;
    }

    pub fn setJoystickConnectionCallback(
        cb: ?JoystickConnectionCallback,
    ) definitions.Error!?JoystickConnectionCallback {
        _ = cb;
    }

    pub fn updateGamepadMappings(mapping: []const u8) definitions.Error!bool {
        _ = mapping;
    }

    pub fn getGamepadName(
        allocator: std.mem.Allocator,
        gamepad: definitions.Gamepad,
    ) (std.mem.Allocator.Error | definitions.Error)![]const u8 {
        _ = allocator;
        _ = gamepad;
    }

    pub fn getGamepadState(
        joy: Joystick,
    ) definitions.Error!definitions.GamepadState {
        _ = joy;
    }
};
