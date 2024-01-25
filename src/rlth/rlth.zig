const std = @import("std");

const parser = @import("parser.zig");
const Tree = @import("Tree.zig");

pub const Build = @import("project.zig").Build;

const util = @import("../util.zig");

pub fn handle_err(msg: []const u8) void {
    std.log.warn("{s}", .{msg});
}

test {
    var fs = util.LinearMemoryFileProvider{};
    try fs.init(std.testing.allocator);
    defer fs.deinit();
    _ = try fs.addFile("test/shader.rl",
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
        \\@(group = 1, binding = 0) base_color_sampler: Sampler;
        \\@(group = 1, binding = 1) base_color_texture: Texture_2D(f32);
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
    );
    _ = try fs.addFile("test/surge/shader/shader.rl",
        \\Sampler :: struct {}
        \\Texture_2d :: struct ($T: typeid) {}
        \\sample :: proc(texture: $Texture_T/$Texture_Dim($Texture_U), sampler: Sampler, uv: [2]f32) -> $TextureU { }
        \\magnitude :: proc(v: [3]f32) -> f32 { }
        \\normalise :: proc(v: [3]f32) -> [3]f32 { }
        \\dot :: proc(a: [3]f32, b: [3]f32) -> f32 { }
        \\max :: proc(a: f32, b: f32) -> f32 { }
        \\pow :: proc(a: f32, b: f32) -> f32 { }
    );

    const start = std.time.nanoTimestamp();
    var build = Build{};
    try build.init(std.testing.allocator, &.{
        .err_handler = @import("rlth.zig").handle_err,
    }, fs.file_provider);
    defer build.deinit();

    try build.addCollection("surge", "test/surge");
    try build.addPackage("test");
    build.wait();

    const end = std.time.nanoTimestamp();
    std.debug.print("time: {}\n", .{end - start});

    std.testing.refAllDecls(@This());
}
