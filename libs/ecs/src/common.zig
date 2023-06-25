const std = @import("std");
const builtin = @import("builtin");

pub const assert = std.debug.assert;
pub const err = std.log.err;

pub const Error = error{
    ComponentNotFound,
};
pub const EntityId = u32;

inline fn scratch(comptime size: usize) std.mem.Allocator {
    var buf = [_]u8{0} ** size;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    return fba.allocator();
}
