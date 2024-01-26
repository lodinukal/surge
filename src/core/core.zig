pub const util = @import("util.zig");
pub const math = @import("math.zig");
pub const allocators = @import("allocators/allocators.zig");

const std = @import("std");

pub fn assert(ok: bool, comptime format: []const u8, args: anytype) noreturn {
    if (!ok) {
        std.debug.panic(format, args);
        unreachable;
    }
}

const lazy = @import("lazy.zig");
pub const Lazy = lazy.Lazy;

const _rc = @import("rc.zig");
pub const Rc = _rc.Rc;
pub const Arc = _rc.Arc;
pub const rc = _rc.rc;
pub const arc = _rc.arc;

pub inline fn clamp(x: anytype, min: @TypeOf(x), max: @TypeOf(x)) @TypeOf(x) {
    return @min(@max(x, min), max);
}

pub inline fn bit(x: anytype, shift: anytype) @TypeOf(x) {
    return x << shift;
}

pub const Delegate = @import("delegate.zig").Delegate;
