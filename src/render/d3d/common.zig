const std = @import("std");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

pub fn releaseIUnknown(comptime T: type, obj: ?*?*T) void {
    if (obj) |o| {
        if (o.*) |unwrapped| {
            if (unwrapped.IUnknown_Release() == 0) {
                o.* = null;
            }
        }
    }
}

pub fn refIUnknown(comptime T: type, obj: ?*?*T) void {
    if (obj) |o| {
        if (o.*) |unwrapped| {
            unwrapped.IUnknown_AddRef();
        }
    }
}

pub fn checkHResult(hr: win32.foundation.HRESULT) bool {
    return winapi.zig.FAILED(hr) == true;
}
