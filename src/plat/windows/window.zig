const std = @import("std");
const testing = std.testing;

const c = @import("c.zig");

const common = @import("../../core/common.zig");
const input_enums = @import("../../core/input_enums.zig");
const window = @import("../window.zig");

const DWORD = std.os.windows.DWORD;
const RECT = std.os.windows.RECT;

pub fn createWindow(info: window.WindowCreateInfo) !window.WindowHandle {
    const styles = get_window_style(.{
        .fullscreen = (info.mode == .fullscreen) or (info.mode == .exclusive_fullscreen),
        .multiwindow_fs = info.mode != .exclusive_fullscreen,
        .borderless = info.flags.borderless,
        .resizable = !info.flags.resized_disabled,
        .maximized = info.mode == .maximized,
        .no_activate_focus = info.flags.no_focus or info.flags.popup,
    });
    const style = styles.style;
    _ = style;
    const ex_style = styles.ex_style;
    _ = ex_style;

    var window_rect: RECT = undefined;
    window_rect.left = info.rect.position.x;
    window_rect.top = info.rect.position.y;
    window_rect.right = info.rect.position.x + info.rect.size.x;
    window_rect.bottom = info.rect.position.y + info.rect.size.y;

    // TODO: Screen from rect

    if (info.mode == .fullscreen or info.mode == .exclusive_fullscreen) {
        // TODO: Use from screen
        // const screen_rect = common.Rect2i.from_components(, size: U)
    }

    return 0;
}

const WindowStyleInfo = struct {
    fullscreen: bool,
    multiwindow_fs: bool,
    borderless: bool,
    resizable: bool,
    maximized: bool,
    no_activate_focus: bool,
};

fn get_window_style(info: WindowStyleInfo) struct { style: DWORD, ex_style: DWORD } {
    var style: DWORD = 0;
    var ex_style: DWORD = c.windows.WS_EX_WINDOWEDGE;

    ex_style |= c.windows.WS_EX_APPWINDOW;
    style |= c.windows.WS_VISIBLE;

    if (info.fullscreen or info.borderless) {
        style |= c.windows.WS_POPUP;
        if (info.fullscreen and info.multiwindow_fs) {
            style |= c.windows.WS_BORDER;
        }
    } else {
        if (info.resizable) {
            if (info.maximized) {
                style |= c.windows.WS_OVERLAPPEDWINDOW | c.windows.WS_MAXIMIZE;
            } else {
                style |= c.windows.WS_OVERLAPPEDWINDOW;
            }
        } else {
            style |= c.windows.WS_OVERLAPPED | c.windows.WS_CAPTION | c.windows.WS_SYSMENU | c.windows.WS_MINIMIZEBOX;
        }
    }

    if (info.no_activate_focus) {
        ex_style |= c.windows.WS_EX_TOPMOST | c.windows.WS_EX_NOACTIVATE;
    }

    if (!info.borderless and !info.no_activate_focus) {
        ex_style |= c.windows.WS_VISIBLE;
    }

    return .{
        .style = style | c.windows.WS_CLIPCHILDREN | c.windows.WS_CLIPSIBLINGS,
        .ex_style = ex_style | c.windows.WS_EX_ACCEPTFILES,
    };
}
