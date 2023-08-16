const std = @import("std");

const win32 = @import("win32");

const display = @import("display.zig");
pub const VideoMode = display.VideoMode;
pub const DisplayHandle = display.DisplayHandle;

const icon = @import("icon.zig");
pub const Icon = icon.WinIcon;

extern const __ImageBase: win32.system.system_services.IMAGE_DOS_HEADER;

pub fn getInstanceHandle() win32.foundation.HINSTANCE {
    return @ptrCast(&__ImageBase);
}

pub fn makeIntResource(i: u16) std.os.windows.PCWSTR {
    @setRuntimeSafety(false);
    return @ptrFromInt(i);
}

test "ref" {
    std.testing.refAllDecls(icon);
    std.testing.refAllDecls(display);
}