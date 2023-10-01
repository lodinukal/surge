const std = @import("std");

const common = @import("../../core/common.zig");
const interface = @import("../../core/interface.zig");

const math = @import("../../core/math.zig");

const platform = @import("../platform.zig");
const Cursor = @import("cursor.zig").Cursor;
const GenericApplicationMessageHandler = @import("message_handler.zig").GenericApplicationMessageHandler;

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

pub const DisplayMetrics = struct {
    primary_display_width: i32 = 0,
    primary_display_height: i32 = 0,
    monitor_info: std.ArrayList(MonitorInfo),
    primary_display_work_rect: PlatformRect,
    virtual_display_rect: PlatformRect,

    pub fn rebuildDisplayMetrics(self: *DisplayMetrics) void {
        self.primary_display_width = 0;
        self.primary_display_height = 0;
        self.monitor_info = std.ArrayList(MonitorInfo).init(0, null);
        self.primary_display_work_rect = PlatformRect.init(null, null, null, null);
        self.virtual_display_rect = PlatformRect.init(null, null, null, null);
    }

    pub fn getMonitorWorkAreaFromPoint(self: *const DisplayMetrics, point: *const math.Vector2(i32)) PlatformRect {
        for (self.monitor_info.items) |mi| {
            if (mi.display_rect.contains(point.x, point.y)) {
                return mi.work_rect;
            }
        }
        return PlatformRect.init(null, null, null, null);
    }
};

pub const WindowTitleAlignment = enum {
    left,
    center,
    right,
};

pub const GenericApplication = struct {
    const Self = @This();
    pub const Virtual = interface.VirtualTable(struct {
        deinit: fn (self: *Self) void,
        setMessageHandler: fn (
            self: *Self,
            message_handler: *GenericApplicationMessageHandler,
        ) void,
        getMessageHandler: fn (
            self: *Self,
        ) *GenericApplicationMessageHandler,
        pollGameDeviceState: fn (
            self: *Self,
            delta: f32,
        ) void,
        pumpMessages: fn (
            self: *Self,
            delta: f32,
        ) void,
    });
    virtual: ?*const Virtual = null,
    cursor: *Cursor,
    message_handler: *GenericApplicationMessageHandler,
    on_virtual_keyboard_shown: ?OnVirtualKeyboardShown = null,
    on_virtual_keyboard_hidden: ?OnVirtualKeyboardHidden = null,
    on_display_metrics_changed: ?OnDisplayMetricsChanged = null,

    pub const OnVirtualKeyboardShown = common.Delegate(fn (
        rect: PlatformRect,
    ) void);
    pub const OnVirtualKeyboardHidden = common.Delegate(fn () void);
    pub const OnDisplayMetricsChanged = common.Delegate(fn (
        metrics: *const DisplayMetrics,
    ) void);

    pub fn init(cursor: *Cursor) GenericApplication {
        return GenericApplication{
            .cursor = cursor,
        };
    }

    pub fn setMessageHandler(
        self: *GenericApplication,
        message_handler: *GenericApplicationMessageHandler,
    ) void {
        if (self.virtual) |v| if (v.setMessageHandler) |f| {
            f(self, message_handler);
        };
        self.message_handler = message_handler;
    }

    pub fn getMessageHandler(
        self: *GenericApplication,
    ) *GenericApplicationMessageHandler {
        if (self.virtual) |v| if (v.getMessageHandler) |f| {
            return f(self);
        };
        return self.message_handler;
    }

    pub fn pollGameDeviceState(
        self: *GenericApplication,
        delta: f32,
    ) void {
        if (self.virtual) |v| if (v.pollGameDeviceState) |f| {
            f(self, delta);
        };
    }

    pub fn pumpMessages(self: *GenericApplication, delta: f32) void {
        if (self.virtual) |v| if (v.pumpMessages) |f| {
            f(self, delta);
        };
    }

    pub fn _broadcastDisplayMetricsChanged(self: *GenericApplication, metrics: *const DisplayMetrics) void {
        self.on_display_metrics_changed.?.broadcast(.{metrics});
    }
};

pub const WindowSizeLimits = struct {
    min_width: ?f32,
    min_height: ?f32,
    max_width: ?f32,
    max_height: ?f32,
};
