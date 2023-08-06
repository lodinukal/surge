const std = @import("std");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const platform = @import("../platform_impl.zig");
const icon = @import("../../icon.zig");
const dpi = @import("../../dpi.zig");
const keyboard = @import("../../keyboard.zig");
const theme = @import("../../theme.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;

pub const WindowState = struct {
    mouse: MouseProperties,

    min_size: ?dpi.Size,
    max_size: ?dpi.Size,

    window_icon: ?icon.Icon,
    taskbar_icon: ?icon.Icon,

    saved_window: ?SavedWindow,
    scale_factor: f64,

    modifiers_state: keyboard.ModifiersState,
    fullscreen: ?platform.Fullscreen,
    current_theme: theme.Theme,
    preferred_theme: ?theme.Theme,

    window_flags: WindowFlags,

    ime_state: ImeState,
    ime_allowed: bool,

    is_active: bool,
    is_focused: bool,

    dragging: bool,

    skip_taskbar: bool,
};

pub const SavedWindow = struct {
    placement: wam.WINDOWPLACEMENT,
};

pub const MouseProperties = struct {
    cursor: icon.CursorIcon,
    capture_count: u32,
    cursor_flags: CursorFlags,
    last_position: ?dpi.PhysicalPosition,
};

pub const CursorFlags = enum(u8) {
    grabbed = 1 << 0,
    hidden = 1 << 1,
    in_window = 1 << 2,
};

pub const WindowFlags = enum(u32) {
    const Self = @This();

    resizable = 1 << 0,
    minimizable = 1 << 1,
    maximizable = 1 << 2,
    closable = 1 << 3,
    visble = 1 << 4,
    on_taskbar = 1 << 5,
    always_on_top = 1 << 6,
    always_on_bottom = 1 << 7,
    no_back_buffer = 1 << 8,
    transparent = 1 << 9,
    child = 1 << 10,
    maximized = 1 << 11,
    popup = 1 << 12,

    exclusive_fullscreen = 1 << 13,
    borderless_fullscreen = 1 << 14,

    retain_state_on_resize = 1 << 15,

    in_size_move = 1 << 16,

    minimized = 1 << 17,

    ignore_cursor_events = 1 << 18,

    decorations = 1 << 19,

    undecorated_shadow = 1 << 20,

    activate = 1 << 21,

    fullscreen_or_mask = Self.always_on_top,
};

pub const ImeState = enum {
    disabled,
    enabled,
    pre_edit,
};
