const std = @import("std");

const platform = @import("./platform_impl/platform_impl.zig");

const PlatformWindowHandle = platform.impl.WindowHandle;

pub const WindowHandle = struct {
    platform_window_handle: PlatformWindowHandle,

    pub fn deinit(self: *WindowHandle) void {
        _ = self;
        // switch (self.)
    }
};
