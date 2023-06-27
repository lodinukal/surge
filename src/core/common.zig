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

const point = @import("math/point.zig");

pub const Point2 = point.Point2;
pub const Point3 = point.Point3;

pub const Point2i = point.Point2i;
pub const Point3i = point.Point3i;
pub const Point2f = point.Point2f;
pub const Point3f = point.Point3f;

const rect = @import("math/rect.zig");

pub const Rect2 = rect.Rect2;
pub const Rect3 = rect.Rect3;

pub const Rect2i = rect.Rect2i;
pub const Rect3i = rect.Rect3i;
pub const Rect2f = rect.Rect2f;
pub const Rect3f = rect.Rect3f;
