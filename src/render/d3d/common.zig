const std = @import("std");

const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
// const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

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
    const failed = winapi.zig.FAILED(hr);
    if (failed) {
        std.log.warn("failed hr: {}", .{hr});
        if (@errorReturnTrace()) |trace| {
            std.log.warn("{}", .{trace});
        }
    }

    return failed == false;
}

// mapping functions
pub inline fn mapPowerPreference(pref: gpu.Adapter.PowerPreference) dxgi.DXGI_GPU_PREFERENCE {
    return switch (pref) {
        .undefined => .UNSPECIFIED,
        .low_power => .MINIMUM_POWER,
        .high_performance => .HIGH_PERFORMANCE,
    };
}
