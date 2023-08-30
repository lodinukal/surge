const std = @import("std");

const win32 = @import("win32");

const display = @import("display.zig");
pub const VideoMode = display.VideoMode;
pub const DisplayHandle = display.DisplayHandle;

const event_loop = @import("event_loop.zig");
pub const EventLoop = event_loop.EventLoop;
pub const EventLoopWindowTarget = event_loop.EventLoopWindowTarget;
pub const EventLoopProxy = event_loop.EventLoopProxy;

const icon = @import("icon.zig");
pub const Icon = icon.WinIcon;

const window = @import("window.zig");
pub const PlatformSpecificWindowAttributes = window.PlatformSpecificWindowAttributes;
pub const Window = window.Window;

const raw_input = @import("raw_input.zig");

const common = @import("../../../core/common.zig");

const event = @import("../../event.zig");

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
const wam = win32.ui.windows_and_messaging;

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

pub var lazy_get_dpi_for_monitor = getDllFunction(
    GetDpiForMonitor,
    "shcore.dll",
    "GetDpiForMonitor",
){};
pub var lazy_get_dpi_for_window = getDllFunction(
    GetDpiForWindow,
    "user32.dll",
    "GetDpiForWindow",
){};
pub var lazy_adjust_window_rect_ex_for_dpi = getDllFunction(
    AdjustWindowRectExForDpi,
    "user32.dll",
    "AdjustWindowRectExForDpi",
){};
pub var lazy_set_process_dpi_awareness_context = getDllFunction(
    SetProcessDpiAwarenessContext,
    "user32.dll",
    "SetProcessDpiAwarenessContext",
){};
pub var lazy_set_process_dpi_awareness = getDllFunction(
    SetProcessDpiAwareness,
    "shcore.dll",
    "SetProcessDpiAwareness",
){};
pub var lazy_set_process_dpi_aware = getDllFunction(
    SetProcessDpiAware,
    "user32.dll",
    "SetProcessDpiAware",
){};
pub var lazy_enable_non_client_dpi_scaling = getDllFunction(
    EnableNonClientDpiScaling,
    "user32.dll",
    "EnableNonClientDpiScaling",
){};

pub const WindowId = struct {
    hwnd: foundation.HWND,

    pub fn dummy() WindowId {
        return WindowId{ .hwnd = @ptrCast(0) };
    }
};

pub inline fn getPrimaryLangId(lang: u16) u16 {
    return lang & 0x3FF;
}

pub inline fn loword(l: u32) u16 {
    return @bitCast(l & 0xFFFF);
}

pub inline fn hiword(l: u32) u16 {
    return @bitCast((l >> 16) & 0xFFFF);
}

pub fn getWindowLong(wnd: foundation.HWND, nindex: wam.WINDOW_LONG_PTR_INDEX) isize {
    return wam.GetWindowLongPtrW(wnd, nindex);
}

pub fn setWindowLong(wnd: foundation.HWND, nindex: wam.WINDOW_LONG_PTR_INDEX, dwnew_long: isize) isize {
    return wam.SetWindowLongPtrW(wnd, nindex, dwnew_long);
}

pub const DeviceId = struct {
    id: u32,

    pub fn dummy() DeviceId {
        return DeviceId{ .id = 0 };
    }

    pub fn getPersistentId(self: *const DeviceId, allocator: std.mem.Allocator) ?[]u8 {
        if (self.id != 0) {
            raw_input.getRawInputDeviceName(allocator, @ptrFromInt(self.id));
        }
        return null;
    }
};

pub const root_device_id = event.DeviceId{ .platform_device_id = .{ .id = 0 } };
pub fn wrapDeviceId(id: u32) event.DeviceId {
    return event.DeviceId{ .platform_device_id = .{ .id = id } };
}

test "ref" {
    std.testing.refAllDecls(icon);
    std.testing.refAllDecls(display);
}
