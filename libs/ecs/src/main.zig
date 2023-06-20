const std = @import("std");
const testing = std.testing;

pub const Composition = @import("composition.zig");
pub const composition_storage = @import("composition_storage.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

comptime {
    std.testing.refAllDeclsRecursive(@This());
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
