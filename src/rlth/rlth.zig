const std = @import("std");

const parser = @import("parser.zig");
const Tree = @import("tree.zig").Tree;

const test_code =
    \\using import "surge:shader";
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
    \\@(fragment)
    \\fs_main :: proc(@(location=0) world_pos: [3]f32, 
    \\                @(location=1) normal: [3]f32, 
    \\                @(location=2) uv: [2]f32) -> (@(location=0) res: [4]f32) {
    \\  base_color := sample(base_color_texture, base_color_sampler, uv);
    \\  
    \\  N := normalise(normal);
    \\  surface_color: [3]f32;
    \\  
    \\  for i in 0..<lights.point_count {
    \\    world_to_light := lights.point[i].position - world_pos;
    \\    dist := magnitude(world_to_ight);
    \\    dir := normalise(world_to_light);
    \\    
    \\    radiance := lights.point[i].color * (1 / pow(dist, 2));
    \\    n_dot_l := max(dot(N, dir), 0);
    \\    
    \\    surface_color += base_color.rgb * radiance * n_dot_l;
    \\  }
    \\  res.rgb = surface_color;
    \\}
;

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const al = allocator;

    var tree = Tree{};
    try tree.init(al, "hii");

    try parser.parse(&tree, test_code);

    // std.log.warn("tokens: {}", .{tree.tokens.items.len});
    // std.log.warn("for block statements: {}", .{tree.statements.items[5]
    //     .declaration.values.?.expressions.items[0]
    //     .procedure.body.?.statements.items[3]
    //     .@"for".body.statements.items.len});
    // std.log.warn("imports: {}", .{tree.imports.items.len});
}
