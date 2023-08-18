const std = @import("std");

const win32 = @import("win32");

const display = @import("display.zig");
pub const VideoMode = display.VideoMode;
pub const DisplayHandle = display.DisplayHandle;

const icon = @import("icon.zig");
pub const Icon = icon.WinIcon;

const window = @import("window.zig");
pub const PlatformSpecificWindowAttributes = window.PlatformSpecificWindowAttributes;

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

pub const MonitorDpiType = enum(u8) {
    EffectiveDpi = 0,
    AngularDpi = 1,
    RawDpi = 2,
};
const GetDpiForMonitor = *fn (
    hmonitor: gdi.HMONITOR,
    dpi_type: MonitorDpiType,
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

fn getFunctionWrap(comptime T: type, comptime lib: []const u8, comptime name: []const u8) type {
    const null_terminated = name ++ "0";
    return struct {
        cached: ?T = null,

        pub fn get(self: *@This()) ?T {
            if (self.cached == null) {
                var module = std.DynLib.open(lib) catch return null;
                defer module.close();
                self.cached = module.lookup(T, null_terminated);
            }
            return self.cached;
        }
    };
}

pub var lazyGetDpiForMonitor = getFunctionWrap(
    GetDpiForMonitor,
    "shcore.dll",
    "GetDpiForMonitor",
){};
pub var lazyGetDpiForWindow = getFunctionWrap(
    GetDpiForWindow,
    "user32.dll",
    "GetDpiForWindow",
){};
pub var lazyAdjustWindowRectExForDpi = getFunctionWrap(
    AdjustWindowRectExForDpi,
    "user32.dll",
    "AdjustWindowRectExForDpi",
){};

test "ref" {
    std.testing.refAllDecls(icon);
    std.testing.refAllDecls(display);
}
