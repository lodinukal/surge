const std = @import("std");

const core = @import("core/common.zig");
const ecs = @import("ecs/main.zig");

const World = ecs.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
    }){};
    defer gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;
}

test {
    std.testing.refAllDeclsRecursive(core);
    std.testing.refAllDeclsRecursive(ecs);
}
