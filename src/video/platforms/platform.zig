const std = @import("std");
const definitions = @import("../definitions.zig");

const monitor = @import("../monitor.zig");
const window = @import("../window.zig");
const Cursor = window.Cursor;

const builtin = @import("builtin");
pub const impl = switch (builtin.os.tag) {
    .windows => @import("./windows/platform.zig"),
    inline else => @compileError("Unsupported OS"),
};

pub const InternalWindow = struct {
    next_window: *InternalWindow,
    resizable: bool,
    decorated: bool,
    auto_iconify: bool,
    floating: bool,
    focus_on_show: bool,
    mouse_passthrough: bool,
    should_close: bool,
    user_pointer: *void,
    double_buffer: bool,
    video_mode: definitions.VideoMode,
    monitor: *monitor.Monitor,
    cursor: *Cursor,
    min_width: i32,
    min_height: i32,
    max_width: i32,
    max_height: i32,
    numer: i32,
    denom: i32,
    sticky_keys: bool,
    sticky_mouse_buttons: bool,
    lock_key_mods: bool,
    cursor_mode: i32,
    mouse_buttons: [
        @intFromEnum(
            definitions.MouseButton.last,
        ) + 1
    ]definitions.ElementState,
    keys: [
        @intFromEnum(
            definitions.Key.last,
        ) + 1
    ]definitions.ElementState,
    virtual_cursor_pos_x: f64,
    virtual_cursor_pos_y: f64,
    raw_mouse_motion: bool,
    callbacks: struct {
        pos: window.WindowPosCallback,
        size: window.WindowSizeCallback,
        close: window.WindowCloseCallback,
        refresh: window.WindowRefreshCallback,
        focus: window.WindowFocusCallback,
        iconify: window.WindowIconifyCallback,
        maximise: window.WindowMaximiseCallback,
        framebuffer_changed: window.WindowFramebufferChangedCallback,
        content_scale: window.WindowContentScaleCallback,
        mouse_button: window.WindowMouseButtonCallback,
        cursor_pos: window.WindowCursorPosCallback,
        cursor_enter: window.WindowCursorEnterCallback,
        scroll: window.WindowScrollCallback,
        key: window.WindowKeyCallback,
        char: window.WindowCharCallback,
        char_mods: window.WindowCharModsCallback,
        drop: window.WindowDropCallback,
    },
    platform: impl.PlatformWindow,
};

pub const InternalMonitor = struct {
    name: [128]u8,
    user_pointer: *void,
    width_mm: i32,
    height_mm: i32,
    current_window: *InternalWindow,
    modes: []definitions.VideoMode,
    current_mode: definitions.VideoMode,
    original_ramp: definitions.GammaRamp,
    current_ramp: definitions.GammaRamp,
    platform: impl.PlatformMonitor,
};

pub const InternalCursor = struct {
    next_cursor: *InternalCursor,
    platform: impl.PlatformCursor,
};

pub const InternalMapElement = struct {
    type: u8,
    index: u8,
    axis_scale: i8,
    axis_offset: i8,
};

pub const InternalMapping = struct {
    name: [128]u8,
    guid: [128]u8,
    buttons: [15]InternalMapElement,
    axes: [6]InternalMapElement,
    platform: impl.PlatformJoystick,
};

pub const Platform = struct {
    platform_tag: builtin.os.tag,
};
