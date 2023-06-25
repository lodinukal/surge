const std = @import("std");
const builtin = @import("builtin");

pub const assert = std.debug.assert;
pub const err = std.log.err;

pub const Error = error{
    ComponentNotFound,
};
pub const EntityId = u32;

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
