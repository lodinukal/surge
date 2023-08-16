const std = @import("std");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const platform = @import("../platform_impl.zig");
const icon = @import("../../icon.zig");
const dpi = @import("../../dpi.zig");
const keyboard = @import("../../keyboard.zig");
const theme = @import("../../theme.zig");

const window = @import("../../window.zig");

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

    pub fn init(
        attributes: *const window.WindowAttributes,
        scale_factor: f64,
        current_theme: theme.Theme,
        preferred_theme: ?theme.Theme,
    ) WindowState {
        return WindowState{
            .mouse = MouseProperties{
                .cursor = icon.CursorIcon.default,
                .capture_count = 0,
                .cursor_flags = CursorFlags{},
                .last_position = null,
            },
            .min_size = attributes.min_inner_size,
            .max_size = attributes.max_inner_size,

            .window_icon = attributes.window_icon,
            .taskbar_icon = null,

            .saved_window = null,
            .scale_factor = scale_factor,

            .modifiers_state = keyboard.ModifiersState{},
            .fullscreen = null,
            .current_theme = current_theme,
            .preferred_theme = preferred_theme,
            .window_flags = WindowFlags{},

            .ime_state = ImeState.disabled,
            .ime_allowed = false,

            .is_active = false,
            .is_focused = false,

            .dragging = false,

            .skip_taskbar = false,
        };
    }

    pub fn getWindowFlags(ws: *const WindowState) WindowFlags {
        return ws.window_flags;
    }

    pub fn setWindowFlags(ws: *WindowState, wnd: foundation.HWND, f: fn (*WindowFlags) void) void {
        const old_flags = ws.window_flags;
        f(&ws.window_flags);
        const new_flags = ws.window_flags;

        old_flags.applyDiff(wnd, new_flags);
    }

    pub fn setWindowFlagsInPlace(ws: *WindowState, f: fn (*WindowFlags) void) void {
        f(&ws.window_flags);
    }

    pub fn hasActiveFocus(ws: *const WindowState) bool {
        return ws.is_active and ws.is_focused;
    }

    pub fn setActive(ws: *WindowState, is_active: bool) bool {
        const old = ws.hasActiveFocus();
        ws.is_active = is_active;
        return old != ws.hasActiveFocus();
    }

    pub fn setFocused(ws: *WindowState, is_focused: bool) bool {
        const old = ws.hasActiveFocus();
        ws.is_focused = is_focused;
        return old != ws.hasActiveFocus();
    }
};

pub const SavedWindow = struct {
    placement: wam.WINDOWPLACEMENT,
};

pub const MouseProperties = struct {
    cursor: icon.CursorIcon,
    capture_count: u32,
    cursor_flags: CursorFlags,
    last_position: ?dpi.PhysicalPosition,

    pub fn getCursorFlags(mp: *const MouseProperties) CursorFlags {
        return mp.cursor_flags;
    }

    pub fn setCursorFlags(mp: *MouseProperties, wnd: foundation.HWND, f: fn (*CursorFlags) void) !void {
        const old_flags = mp.cursor_flags;
        f(&mp.cursor_flags);
        try mp.cursor_flags.refreshOsCursor(wnd) catch |e| {
            mp.cursor_flags = old_flags;
            return e;
        };
    }
};

pub const CursorFlags = packed struct {
    grabbed: bool = false,
    hidden: bool = false,
    in_window: bool = false,
};

pub const WindowFlags = packed struct(u32) {
    const Self = @This();

    resizable: bool = false,
    minimizable: bool = false,
    maximizable: bool = false,
    closable: bool = false,
    visble: bool = false,
    on_taskbar: bool = false,
    always_on_top: bool = false,
    always_on_bottom: bool = false,
    no_back_buffer: bool = false,
    transparent: bool = false,
    child: bool = false,
    maximized: bool = false,
    popup: bool = false,

    exclusive_fullscreen: bool = false,
    borderless_fullscreen: bool = false,

    retain_state_on_resize: bool = false,

    in_size_move: bool = false,

    minimized: bool = false,

    ignore_cursor_events: bool = false,

    decorations: bool = false,

    undecorated_shadow: bool = false,

    activate: bool = false,
    _: u12 = 0,

    // fullscreen_or_mask = Self.always_on_top,

    pub fn asNumber(wf: WindowFlags) u32 {
        return @bitCast(wf);
    }

    pub fn mask(wf: *WindowFlags) WindowFlags {
        if (wf.exclusive_fullscreen) {
            wf.always_on_top = true;
        }
        return wf.*;
    }

    pub fn toWindowStyles(wf: WindowFlags) struct { wam.WINDOW_STYLE, wam.WINDOW_EX_STYLE } {
        var style = wam.WS_CAPTION | wam.WS_BORDER | wam.WS_CLIPSIBLINGS | wam.WS_CLIPCHILDREN | wam.WS_SYSMENU;
        var style_ex = wam.WS_EX_WINDOWEDGE | wam.WS_EX_ACCEPTFILES;

        if (wf.resizable) {
            style |= wam.WS_SIZEBOX;
        }
        if (wf.maximizable) {
            style |= wam.WS_MAXIMIZEBOX;
        }
        if (wf.minimizable) {
            style |= wam.WS_MINIMIZEBOX;
        }
        if (wf.visible) {
            style |= wam.WS_VISIBLE;
        }
        if (wf.on_taskbar) {
            style_ex |= wam.WS_EX_APPWINDOW;
        }
        if (wf.always_on_top) {
            style_ex |= wam.WS_EX_TOPMOST;
        }
        if (wf.no_back_buffer) {
            style_ex |= wam.WS_EX_NOREDIRECTIONBITMAP;
        }
        if (wf.child) {
            style |= wam.WS_CHILD;
        }
        if (wf.popup) {
            style |= wam.WS_POPUP;
        }
        if (wf.maximized) {
            style |= wam.WS_MAXIMIZE;
        }
        if (wf.minimized) {
            style |= wam.WS_MINIMIZE;
        }
        if (wf.ignore_cursor_events) {
            style_ex |= wam.WS_EX_TRANSPARENT | wam.WS_EX_LAYERED;
        }

        if (wf.exclusive_fullscreen or wf.borderless_fullscreen) {
            style &= !wam.WS_OVERLAPPEDWINDOW;
        }

        return .{ style, style_ex };
    }

    fn applyDiff(wf: WindowFlags, wnd: foundation.HWND, new: *WindowFlags) void {
        wf = wf.mask();
        new = new.mask();

        var diff = common.flagDiff(wf, new);

        if (common.flagEmpty(diff)) {
            return;
        }

        if (new.visble) {
            const flag = blk: {
                if (!wf.activate) {
                    wf.activate = true;
                    break :blk wam.SW_SHOWNOACTIVATE;
                } else {
                    break :blk wam.SW_SHOW;
                }
            };
            wam.ShowWindow(wnd, flag);
        }
    }
};

pub const ImeState = enum {
    disabled,
    enabled,
    pre_edit,
};
