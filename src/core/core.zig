pub const util = @import("util.zig");
pub const math = @import("math.zig");
pub const allocators = @import("allocators.zig");

const std = @import("std");

pub fn assert(ok: bool, comptime format: []const u8, args: anytype) noreturn {
    if (!ok) {
        std.debug.panic(format, args);
        unreachable;
    }
}

pub const Lazy = @import("lazy.zig").Lazy;

pub const Rc = @import("rc.zig").Rc;
pub const Arc = @import("rc.zig").Arc;
pub const rc = @import("rc.zig").rc;
pub const arc = @import("rc.zig").arc;

pub inline fn clamp(x: anytype, min: @TypeOf(x), max: @TypeOf(x)) @TypeOf(x) {
    return @min(@max(x, min), max);
}

pub inline fn bit(x: anytype, shift: anytype) @TypeOf(x) {
    return x << shift;
}

pub const Delegate = @import("delegate.zig").Delegate;
