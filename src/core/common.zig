const std = @import("std");

pub const assert = std.debug.assert;
pub const err = std.log.err;

pub fn ScratchSpace(comptime len: usize) type {
    return struct {
        buf: [len]u8 = undefined,
        fba: std.heap.FixedBufferAllocator = undefined,

        pub fn init(s: @This()) @This() {
            s.fba = std.heap.FixedBufferAllocator.init(&s.buf);
            return s;
        }

        pub fn allocator(s: @This()) std.mem.Allocator {
            return s.fba.allocator();
        }
    };
}

const math = @import("math.zig");

pub const Point2 = math.Point2;
pub const Point3 = math.Point3;

pub const Point2i = math.Point2i;
pub const Point3i = math.Point3i;
pub const Point2f = math.Point2f;
pub const Point3f = math.Point3f;
