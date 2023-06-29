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

pub const Vec2 = point.Vec2;
pub const Vec3 = point.Vec3;

pub const Vec2i = point.Vec2i;
pub const Vec3i = point.Vec3i;
pub const Vec2f = point.Vec2f;
pub const Vec3f = point.Vec3f;

const rect = @import("math/rect.zig");

pub const Rect2 = rect.Rect2;
pub const Rect3 = rect.Rect3;

pub const Rect2i = rect.Rect2i;
pub const Rect3i = rect.Rect3i;
pub const Rect2f = rect.Rect2f;
pub const Rect3f = rect.Rect3f;

pub inline fn clamp(x: anytype, min: @TypeOf(x), max: @TypeOf(x)) @TypeOf(x) {
    return @min(@max(x, min), max);
}
