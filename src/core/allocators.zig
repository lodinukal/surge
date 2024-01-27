const std = @import("std");

pub const ExternAllocator = @import("allocators/extern_allocator.zig").ExternAllocator;
pub const FailingAllocator = @import("allocators/FailingAllocator.zig");

pub fn ScratchSpace(comptime len: usize) type {
    return struct {
        buf: [len]u8 = .{0} ** len,
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
