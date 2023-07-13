const std = @import("std");

const core = @import("core/common.zig");
const ecs = @import("ecs/main.zig");

const pixels = @import("video/pixels.zig");
const video = @import("video/video.zig");

const World = ecs.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;
}

test {
    std.testing.refAllDecls(core);
    std.testing.refAllDecls(ecs);

    std.testing.refAllDecls(pixels);
    std.testing.refAllDecls(video);
}
