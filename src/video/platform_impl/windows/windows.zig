const std = @import("std");

const win32 = @import("win32");

const display = @import("display.zig");
pub const VideoMode = display.VideoMode;
pub const DisplayHandle = display.DisplayHandle;

const icon = @import("icon.zig");
pub const Icon = icon.WinIcon;

const window = @import("window.zig");
pub const PlatformSpecificWindowAttributes = window.PlatformSpecificWindowAttributes;

const common = @import("../../../core/common.zig");

extern const __ImageBase: win32.system.system_services.IMAGE_DOS_HEADER;

pub fn getInstanceHandle() win32.foundation.HINSTANCE {
    return @ptrCast(&__ImageBase);
}

pub fn makeIntResource(i: u16) std.os.windows.PCWSTR {
    @setRuntimeSafety(false);
    return @ptrFromInt(i);
}

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const hi_dpi = win32.ui.hi_dpi;

pub fn getDllFunction(comptime T: type, comptime lib: []const u8, comptime name: []const u8) type {
    const null_terminated = name ++ "0";
    return common.Lazy(struct {
        pub fn init() ?T {
            var module = std.DynLib.open(lib) catch return null;
            defer module.close();
            return module.lookup(T, null_terminated);
        }
    }, ?T);
}

const GetDpiForMonitor = *fn (
    hmonitor: gdi.HMONITOR,
    dpi_type: hi_dpi.MONITOR_DPI_TYPE,
    x: *u32,
    y: *u32,
) callconv(.Win64) foundation.HRESULT;

const GetDpiForWindow = *fn (hwnd: foundation.HWND) callconv(.Win64) u32;

const AdjustWindowRectExForDpi = *fn (
    rect: *foundation.RECT,
    style: u32,
    menu: bool,
    ex_style: u32,
    dpi: u32,
) callconv(.Win64) foundation.BOOL;

const SetProcessDpiAwarenessContext = *fn (
    dpi_awareness_context: hi_dpi.DPI_AWARENESS_CONTEXT,
) callconv(.Win64) foundation.BOOL;

const SetProcessDpiAwareness = *fn (
    value: hi_dpi.PROCESS_DPI_AWARENESS,
) callconv(.Win64) foundation.BOOL;

const SetProcessDpiAware = *fn () callconv(.Win64) foundation.BOOL;

const EnableNonClientDpiScaling = *fn (hwnd: foundation.HWND) callconv(.Win64) foundation.BOOL;

pub var lazyGetDpiForMonitor = getDllFunction(
    GetDpiForMonitor,
    "shcore.dll",
    "GetDpiForMonitor",
){};
pub var lazyGetDpiForWindow = getDllFunction(
    GetDpiForWindow,
    "user32.dll",
    "GetDpiForWindow",
){};
pub var lazyAdjustWindowRectExForDpi = getDllFunction(
    AdjustWindowRectExForDpi,
    "user32.dll",
    "AdjustWindowRectExForDpi",
){};
pub var lazySetProcessDpiAwarenessContext = getDllFunction(
    SetProcessDpiAwarenessContext,
    "user32.dll",
    "SetProcessDpiAwarenessContext",
){};
pub var lazySetProcessDpiAwareness = getDllFunction(
    SetProcessDpiAwareness,
    "shcore.dll",
    "SetProcessDpiAwareness",
){};
pub var lazySetProcessDpiAware = getDllFunction(
    SetProcessDpiAware,
    "user32.dll",
    "SetProcessDpiAware",
){};
pub var lazyEnableNonClientDpiScaling = getDllFunction(
    EnableNonClientDpiScaling,
    "user32.dll",
    "EnableNonClientDpiScaling",
){};

test "ref" {
    std.testing.refAllDecls(icon);
    std.testing.refAllDecls(display);
}
