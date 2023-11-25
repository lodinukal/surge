const std = @import("std");

pub fn assert(ok: bool, comptime format: []const u8, args: anytype) noreturn {
    if (!ok) {
        std.debug.panic(format, args);
        unreachable;
    }
}
pub const err = std.log.err;
pub const panic = std.debug.panic;

pub fn ScratchSpace(comptime len: usize) type {
    return struct {
        buf: [len]u8 = undefined,
        fba: std.heap.FixedBufferAllocator = undefined,

        pub fn init(s: *@This()) *@This() {
            s.fba = std.heap.FixedBufferAllocator.init(&s.buf);
            return s;
        }

        pub fn allocator(s: *@This()) std.mem.Allocator {
            return s.fba.allocator();
        }
    };
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

pub inline fn flagDiff(x: anytype, y: @TypeOf(x)) @TypeOf(x) {
    const T = @TypeOf(x);
    if (comptime !std.meta.trait.isPacked(T)) {
        @compileError("diff only works on packed types");
    }
    const Backing = @typeInfo(T).Struct.backing_integer.?;
    return @as(T, @bitCast(@as(Backing, @bitCast(x)) ^ @as(Backing, @bitCast(y))));
}

pub inline fn flagEmpty(x: anytype) bool {
    const T = @TypeOf(x);
    if (comptime !std.meta.trait.isPacked(T)) {
        @compileError("isEmpty only works on packed types");
    }

    const Backing = @typeInfo(T).Struct.backing_integer.?;
    return @as(Backing, @bitCast(x)) == 0;
}

const _delegate = @import("delegate.zig");
pub const Delegate = _delegate.Delegate;
pub const delegate = _delegate.delegate;

const interface = @import("interface.zig");
pub const getRoot = interface.getRoot;
