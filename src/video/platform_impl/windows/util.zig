const std = @import("std");

const windows_platform = @import("windows.zig");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;

pub fn utf8ToUtf16LeAlloc(allocator: std.mem.Allocator, utf8: []const u8) ![]u16 {
    const size = std.unicode.calcUtf16LeLen(utf8);
    var utf16le = try allocator.alloc(u16, size);
    try std.unicode.utf8ToUtf16Le(utf16le, utf8);
    return utf16le;
}

pub fn getWindowOuterRect(wnd: foundation.HWND) !foundation.RECT {
    var rect = std.mem.zeroes(foundation.RECT);
    wam.GetWindowRect(wnd, &rect);
    return rect;
}

pub fn getWindowInnerRect(wnd: foundation.HWND) !foundation.RECT {
    var rect = std.mem.zeroes(foundation.RECT);
    var top_left = std.mem.zeroes(foundation.POINT);
    wam.ClientToScreen(wnd, &top_left);
    wam.GetClientRect(wnd, &rect);

    rect.left += top_left.x;
    rect.right += top_left.x;
    rect.top += top_left.y;
    rect.bottom += top_left.y;

    return rect;
}

pub fn isWindowFocused(wnd: foundation.HWND) bool {
    return wam.GetActiveWindow() == wnd;
}

pub fn getCursorClip() !foundation.RECT {
    var rect = std.mem.zeroes(foundation.RECT);
    wam.GetClipCursor(&rect);
    return rect;
}

pub fn setCursorClip(rect: ?foundation.RECT) !void {
    wam.ClipCursor(if (rect) &rect else null);
}

pub fn setCursorHidden(hidden: bool) void {
    const Static = struct {
        var HIDDEN: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false);
    };
    const changed = Static.HIDDEN.swap(hidden, .SeqCst) != hidden;
    if (changed) {
        wam.ShowCursor(!hidden);
    }
}

pub fn getDesktopRect() foundation.RECT {
    const left = wam.GetSystemMetrics(wam.SM_XVIRTUALSCREEN);
    const top = wam.GetSystemMetrics(wam.SM_YVIRTUALSCREEN);
    return foundation.RECT{
        .left = left,
        .top = top,
        .right = left + wam.GetSystemMetrics(wam.SM_CXVIRTUALSCREEN),
        .bottom = top + wam.GetSystemMetrics(wam.SM_CYVIRTUALSCREEN),
    };
}
