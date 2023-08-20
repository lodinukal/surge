const std = @import("std");

const windows_platform = @import("windows.zig");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const windows = @import("windows.zig");

const platform = @import("../platform_impl.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const wam = win32.ui.windows_and_messaging;
const hi_dpi = win32.ui.hi_dpi;
const z32 = win32.zig;

pub fn becomeDpiAware() void {
    const Static = struct {
        pub var enabled = false;
    };
    if (Static.enabled) return;
    Static.enabled = true;
    if (windows_platform.lazySetProcessDpiAwarenessContext.get()) |setProcessDpiAwarenessContext| {
        if (setProcessDpiAwarenessContext(hi_dpi.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) == z32.FALSE) {
            setProcessDpiAwarenessContext(hi_dpi.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE);
        } else if (windows_platform.lazySetProcessDpiAwareness.get()) |setProcessDpiAwareness| {
            setProcessDpiAwareness(hi_dpi.PROCESS_PER_MONITOR_DPI_AWARE);
        } else if (windows_platform.lazySetProcessDpiAware) |setProcessDpiAware| {
            setProcessDpiAware();
        }
    }
}

pub fn enableNonClientDpiScaling(wnd: foundation.HWND) void {
    if (windows_platform.lazyEnableNonClientDpiScaling.get()) |enableNonClientDpiScalingWin| {
        enableNonClientDpiScalingWin(wnd);
    }
}

pub fn getMonitorDpi(monitor: gdi.HMONITOR) ?u32 {
    if (windows_platform.lazyGetDpiForMonitor) |getDpiForMonitor| {
        var xdpi: u32 = 0;
        var ydpi: u32 = 0;
        if (getDpiForMonitor(monitor, hi_dpi.MDT_EFFECTIVE_DPI, &xdpi, &ydpi) == foundation.S_OK) {
            return xdpi;
        }
    }
}

pub const BASE_DPI: u32 = 96;
pub fn dpiToScaleFactor(indpi: u32) f64 {
    return @as(f64, @floatFromInt(indpi)) / @as(f64, @floatFromInt(BASE_DPI));
}

pub fn hwndDpi(wnd: foundation.HWND) u32 {
    const dc = gdi.GetDC(wnd);
    if (dc == null) unreachable;
    if (windows_platform.lazyGetDpiForWindow.get()) |getDpiForWindow| {
        switch (getDpiForWindow(wnd)) {
            0 => return BASE_DPI,
            else => |dpi| return dpi,
        }
    } else if (windows_platform.lazyGetDpiForMonitor.get()) |getDpiForMonitor| {
        var monitor = gdi.MonitorFromWindow(wnd, gdi.MONITOR_DEFAULTTONEAREST);
        if (monitor == null) return BASE_DPI;
        var xdpi: u32 = 0;
        var ydpi: u32 = 0;
        if (getDpiForMonitor(monitor, hi_dpi.MDT_EFFECTIVE_DPI, &xdpi, &ydpi) == foundation.S_OK) {
            return xdpi;
        } else {
            return BASE_DPI;
        }
    } else {
        if (wam.IsProcessDPIAware() != z32.FALSE) {
            return @intCast(gdi.GetDeviceCaps(dc, gdi.LOGPIXELSX));
        } else {
            return BASE_DPI;
        }
    }
}
