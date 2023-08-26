const std = @import("std");

const common = @import("../core/common.zig");

const platform = @import("./platform_impl/platform_impl.zig");
const dpi = @import("dpi.zig");
const keyboard = @import("keyboard.zig");
const theme = @import("theme.zig");

pub const ControlFlow = union(enum) {
    poll,
    wait,
    wait_until: std.time.Instant,
    exit_with_code: i32,
};

pub fn EventLoop(comptime T: type) type {
    return struct {
        event_loop: platform.impl.EventLoop(T),
        _marker: ?*void = null,
    };
}

pub fn EventLoopWindowTarget(comptime T: type) type {
    return struct {
        p: platform.impl.EventLoopWindowTarget(T),
        _marker: ?*void = null,
    };
}

pub fn EventLoopProxy(comptime T: type) type {
    return struct {
        const Self = @This();

        p: platform.impl.EventLoopProxy(T),

        pub fn sendEvent(elp: *Self, event: T) !void {
            return elp.p.sendEvent(event);
        }
    };
}

pub const DeviceEvents = enum {
    always,
    when_focused,
    never,

    pub const default = @This().when_focused;
};