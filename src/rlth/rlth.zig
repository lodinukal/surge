const std = @import("std");

const parser = @import("parser.zig");
const Tree = @import("tree.zig").Tree;

const test_code =
    \\PointLight :: struct {
    \\  position: [3]f32,
    \\  color: [3]f32,
    \\}
    \\
    \\LightStorage :: struct {
    \\  point_count: u32,
    \\  point: []PointLight,
    \\}
    \\
    \\@(storage, group = 0, binding = 0)
    \\lights: LightStorage;
    \\
    \\@(group = 1, binding = 0) base_color_sampler: sampler;
    \\@(group = 1, binding = 1) base_color_texture: texture_2d(f32);
    \\
    \\@fragment
    \\fs_main :: proc (i: i32 ) [4]f32 {
    \\  base_color: sample(base_color_texture, base_color_sampler, uv);
    \\}
;

test {
    const allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const al = arena.allocator();

    var tree = Tree{};
    try tree.init(al, "hii");

    try parser.parse(&tree, test_code);

    for (tree.tokens.items) |tkn| {
        std.debug.print("tkn: {s}\n", .{tkn.string});
    }
}
