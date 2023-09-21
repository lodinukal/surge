const std = @import("std");

const math = @import("../../core/math.zig");

pub const WindowType = enum {
    normal,
    menu,
    tooltip,
    notification,
    cursor_decorator,
    game_window,
};

pub const WindowTransparency = enum {
    none,
    per_window,
    per_pixel,
};

pub const WindowActivationPolicy = enum {
    never,
    always,
    first_shown,
};

pub const WindowSizeLimits = struct {
    min_width: ?f32,
    min_height: ?f32,
    max_width: ?f32,
    max_height: ?f32,
};

pub const GenericWindowDefinition = struct {
    type: WindowType,
    x_desired_position: ?f32,
    y_desired_position: ?f32,
    width_desired: ?f32,
    height_desired: ?f32,
    transparency: WindowTransparency,
    has_os_border: bool,
    appears_in_taskbar: bool,
    is_topmost_window: bool,
    accepts_input: bool,
    activation_policy: WindowActivationPolicy,
    focus_when_first_shown: bool,
    has_close_button: bool,
    has_toolbar_minimise_button: bool,
    has_toolbar_maximise_button: bool,
    is_modal: bool,
    is_regular_window: bool,
    has_sizing_frame: bool,
    changes_often: bool,
    should_preserve_aspect_ratio: bool,
    expected_max_width: ?i32,
    expected_max_height: ?i32,

    title: []const u8,
    opacity: f32,
    corner_radius: i32,

    size_limits: WindowSizeLimits,

    manual_dpi_scaling: bool = false,
};

pub const WindowMode = enum(i32) {
    fullscreen = 0,
    windowed_fullscreen = 1,
    windowed = 2,
};

pub const WindowDrawAttentionRequestType = enum {
    until_activated,
    stop,
};

pub const WindowDrawAttentionParameters = struct {
    type: WindowDrawAttentionRequestType,
};

pub const GenericWindow = struct {
    const Self = @This();
    definition: GenericWindowDefinition,
    virtual: struct {
        deinit: ?fn (self: *Self) void = null,
        reshapeWindow: ?fn (self: *Self, x: i32, y: i32, width: i32, height: i32) void = null,
        getFullscreenInfo: ?fn (self: *const Self, x: ?*i32, y: ?*i32, width: ?*i32, height: ?*i32) void = null,
        moveWindowTo: ?fn (self: *Self, x: i32, y: i32) void = null,
        bringToFront: ?fn (self: *Self, force: bool) void = null,
        forceToFront: ?fn (self: *Self) void = null,
        cleanup: ?fn (self: *Self) void = null,
        minimise: ?fn (self: *Self) void = null,
        maximise: ?fn (self: *Self) void = null,
        restore: ?fn (self: *Self) void = null,
        show: ?fn (self: *Self) void = null,
        hide: ?fn (self: *Self) void = null,
        setWindowMode: ?fn (self: *Self, new_mode: WindowMode) void = null,
        getWindowMode: ?fn (self: *const Self) WindowMode = null,
        isMaximised: ?fn (self: *const Self) bool = null,
        isMinimised: ?fn (self: *const Self) bool = null,
        isVisible: ?fn (self: *const Self) bool = null,
        getRestoredDimensions: ?fn (self: *Self, x: ?*i32, y: ?*i32, width: ?*i32, height: ?*i32) bool = null,
        setWindowFocus: ?fn (self: *Self) void = null,
        setOpacity: ?fn (self: *Self, opacity: f32) void = null,
        enable: ?fn (self: *Self, enable: bool) void = null,
        isPointInWindow: ?fn (self: *const Self, x: i32, y: i32) bool = null,
        getWindowBorderSize: ?fn (self: *const Self) i32 = null,
        getWindowTitleBarSize: ?fn (self: *const Self) i32 = null,
        getOsWindowHandle: ?fn (self: *const Self) ?*void = null,
        isForegroundWindow: ?fn (self: *const Self) bool = null,
        isFullscreenSupported: ?fn (self: *const Self) bool = null,
        setText: ?fn (self: *Self, text: []const u8) void = null,
        getDefinition: ?fn (self: *const Self) *const GenericWindowDefinition = null,
        adjustCachedSize: ?fn (self: *Self, size: *math.Vector2(f32)) void = null,
        getDpiScaleFactor: ?fn (self: *const Self) f32 = null,
        setDpiScaleFactor: ?fn (self: *Self, dpi_scale_factor: f32) void = null,
        isManualManageDpiChanges: ?fn (self: *const Self) bool = null,
        setManualManageDpiChanges: ?fn (self: *Self, manual_manage_dpi_changes: bool) void = null,
        drawAttention: ?fn (self: *Self, parameters: *const WindowDrawAttentionParameters) void = null,
        setNativeWindowButtonsVisibility: ?fn (self: *Self, visible: bool) void = null,
    } = undefined,

    pub fn init() GenericWindow {
        return GenericWindow{
            .definition = .{},
        };
    }

    pub fn deinit(self: *GenericWindow) void {
        if (self.virtual.deinit) |f| {
            f(&self);
        }
    }

    pub fn reshapeWindow(self: *GenericWindow, x: i32, y: i32, width: i32, height: i32) void {
        if (self.virtual.reshapeWindow) |f| {
            f(self, x, y, width, height);
        }
    }

    pub fn getFullscreenInfo(self: *const GenericWindow, x: ?*i32, y: ?*i32, width: ?*i32, height: ?*i32) void {
        if (self.virtual.getFullscreenInfo) |f| {
            f(self, x, y, width, height);
        }
    }

    pub fn moveWindowTo(self: *GenericWindow, x: i32, y: i32) void {
        if (self.virtual.moveWindowTo) |f| {
            f(self, x, y);
        }
    }

    pub fn bringToFront(self: *GenericWindow, force: ?bool) void {
        if (self.virtual.bringToFront) |f| {
            f(self, force orelse false);
        }
    }

    pub fn forceToFront(self: *GenericWindow) void {
        if (self.virtual.forceToFront) |f| {
            f(self);
        }
    }

    pub fn cleanup(self: *GenericWindow) void {
        if (self.virtual.cleanup) |f| {
            f(self);
        }
    }

    pub fn minimise(self: *GenericWindow) void {
        if (self.virtual.minimise) |f| {
            f(self);
        }
    }

    pub fn maximise(self: *GenericWindow) void {
        if (self.virtual.maximise) |f| {
            f(self);
        }
    }

    pub fn restore(self: *GenericWindow) void {
        if (self.virtual.restore) |f| {
            f(self);
        }
    }

    pub fn show(self: *GenericWindow) void {
        if (self.virtual.show) |f| {
            f(self);
        }
    }

    pub fn hide(self: *GenericWindow) void {
        if (self.virtual.hide) |f| {
            f(self);
        }
    }

    pub fn setWindowMode(self: *GenericWindow, new_mode: WindowMode) void {
        if (self.virtual.setWindowMode) |f| {
            f(self, new_mode);
        }
    }

    pub fn getWindowMode(self: *const GenericWindow) WindowMode {
        if (self.virtual.getWindowMode) |f| {
            return f(self);
        }
        return WindowMode.windowed;
    }

    pub fn isMaximised(self: *const GenericWindow) bool {
        if (self.virtual.isMaximised) |f| {
            return f(self);
        }
        return true;
    }

    pub fn isMinimised(self: *const GenericWindow) bool {
        if (self.virtual.isMinimised) |f| {
            return f(self);
        }
        return false;
    }

    pub fn isVisible(self: *const GenericWindow) bool {
        if (self.virtual.isVisible) |f| {
            return f(self);
        }
        return true;
    }

    pub fn getRestoredDimensions(self: *GenericWindow, x: ?*i32, y: ?*i32, width: ?*i32, height: ?*i32) bool {
        if (self.virtual.getRestoredDimensions) |f| {
            f(self, x, y, width, height);
        }
        return false;
    }

    pub fn setWindowFocus(self: *GenericWindow) void {
        if (self.virtual.setWindowFocus) |f| {
            f(self);
        }
    }

    pub fn setOpacity(self: *GenericWindow, opacity: f32) void {
        if (self.virtual.setOpacity) |f| {
            f(self, opacity);
        }
    }

    pub fn enable(self: *GenericWindow, should_enable: bool) void {
        if (self.virtual.enable) |f| {
            f(self, should_enable);
        }
    }

    pub fn isPointInWindow(self: *const GenericWindow, x: i32, y: i32) bool {
        if (self.virtual.isPointInWindow) |f| {
            return f(self, x, y);
        }
        return true;
    }

    pub fn getWindowBorderSize(self: *const GenericWindow) i32 {
        if (self.virtual.getWindowBorderSize) |f| {
            return f(self);
        }
        return 0;
    }

    pub fn getWindowTitleBarSize(self: *const GenericWindow) i32 {
        if (self.virtual.getWindowTitleBarSize) |f| {
            return f(self);
        }
        return 0;
    }

    pub fn getOsWindowHandle(self: *const GenericWindow) ?*void {
        if (self.virtual.getOsWindowHandle) |f| {
            return f(self);
        }
        return null;
    }

    pub fn isForegroundWindow(self: *const GenericWindow) bool {
        if (self.virtual.isForegroundWindow) |f| {
            return f(self);
        }
        return true;
    }

    pub fn isFullscreenSupported(self: *const GenericWindow) bool {
        if (self.virtual.isFullscreenSupported) |f| {
            return f(self);
        }
        return true;
    }

    pub fn setText(self: *GenericWindow, text: []const u8) void {
        if (self.virtual.setText) |f| {
            f(self, text);
        }
    }

    pub fn getDefinition(self: *const GenericWindow) *const GenericWindowDefinition {
        if (self.virtual.getDefinition) |f| {
            return f(self);
        }
        return &self.definition;
    }

    pub fn adjustCachedSize(self: *GenericWindow, size: *math.Vector2(f32)) void {
        if (self.virtual.adjustCachedSize) |f| {
            f(self, size);
        }
    }

    pub fn getDpiScaleFactor(self: *const GenericWindow) f32 {
        if (self.virtual.getDpiScaleFactor) |f| {
            return f(self);
        }
        return 1.0;
    }

    pub fn setDpiScaleFactor(self: *GenericWindow, dpi_scale_factor: f32) void {
        if (self.virtual.setDpiScaleFactor) |f| {
            f(self, dpi_scale_factor);
        }
    }

    pub fn isManualManageDpiChanges(self: *const GenericWindow) bool {
        if (self.virtual.isManualManageDpiChanges) |f| {
            return f(self);
        }
        return false;
    }

    pub fn setManualManageDpiChanges(self: *GenericWindow, manual_manage_dpi_changes: bool) void {
        if (self.virtual.setManualManageDpiChanges) |f| {
            f(self, manual_manage_dpi_changes);
        }
    }

    pub fn drawAttention(self: *GenericWindow, parameters: *const WindowDrawAttentionParameters) void {
        if (self.virtual.drawAttention) |f| {
            f(self, parameters);
        }
    }

    pub fn setNativeWindowButtonsVisibility(self: *GenericWindow, visible: bool) void {
        if (self.virtual.setNativeWindowButtonsVisibility) |f| {
            f(self, visible);
        }
    }
};
