const std = @import("std");

const core = @import("core/common.zig");
const ecs = @import("ecs/main.zig");

const pixels = @import("platform/pixels.zig");

const World = ecs.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;

    const hdr_format = pixels.Formats.rgba8888;
    const stringed = hdr_format.getName();
    std.debug.print("hdr_format: {s}\n", .{stringed});
}

test {
    std.testing.refAllDeclsRecursive(core);
    std.testing.refAllDeclsRecursive(ecs);
}
