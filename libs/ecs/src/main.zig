const std = @import("std");
const testing = std.testing;

pub const composition = @import("composition.zig");
pub const component_tree = @import("component_tree.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

comptime {
    std.testing.refAllDeclsRecursive(@This());
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
