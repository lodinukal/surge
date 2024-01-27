const std = @import("std");
const util = @import("core").util;

pub const Context = @import("Context.zig");

pub const parse = @import("parser.zig").parse;
pub const Validator = @import("Validator.zig");
pub const Tree = @import("Tree.zig");
pub const Build = @import("project.zig").Build;

test {
    var p = util.LinearMemoryFileProvider{};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    try p.init(gpa.allocator());

    const fp = p.fileProvider();

    const root = fp.getRootNode();
    const test_folder = try root.createDirectory("test");
    _ = try test_folder.createFile("shader.rl",
        \\using import "surge:shader";
        \\x: Texture_2D(f32);
        \\
    );
    // _ = try test_folder.createFile("shader.rl",
    //     \\using import "surge:shader";
    //     \\PointLight :: struct {
    //     \\  position: [3]f32,
    //     \\  color: [3]f32,
    //     \\}
    //     \\
    //     \\LightStorage :: struct {
    //     \\  point_count: u32,
    //     \\  point: []PointLight,
    //     \\}
    //     \\
    //     \\@(storage, group = 0, binding = 0)
    //     \\lights: LightStorage;
    //     \\
    //     \\@(group = 1, binding = 0) base_color_sampler: Sampler;
    //     \\@(group = 1, binding = 1) base_color_texture: Texture_2D(f32);
    //     \\
    //     \\@fragment
    //     \\fp_main :: proc(@location(0) world_pos: [3]f32,
    //     \\                @location(1) normal: [3]f32,
    //     \\                @location(2) uv: [2]f32) -> (@location(0) res: [4]f32) {
    //     \\  base_color := sample(base_color_texture, base_color_sampler, uv);
    //     \\
    //     \\  N := normalise(normal);
    //     \\  surface_color: [3]f32;
    //     \\
    //     \\  for i in 0..<lights.point_count {
    //     \\    world_to_light := lights.point[i].position - world_pos;
    //     \\    dist := magnitude(world_to_ight);
    //     \\    dir := normalise(world_to_light);
    //     \\
    //     \\    radiance := lights.point[i].color * (1 / pow(dist, 2));
    //     \\    n_dot_l := max(dot(N, dir), 0);
    //     \\
    //     \\    surface_color += base_color.rgb * radiance * n_dot_l;
    //     \\  }
    //     \\  res.rgb = surface_color;
    //     \\}
    // );
    const surge_collection = try test_folder.createDirectory("surge");
    const shader_folder = try surge_collection.createDirectory("shader");
    _ = try shader_folder.createFile("shader.rl",
        \\Sampler :: struct {}
        \\
        \\Texel_Format :: enum {
        \\    rgba8unorm,
        \\    rgba8snorm,
        \\    rgba8uint,
        \\    rgba8sint,
        \\    rgba16uint,
        \\    rgba16sint,
        \\    rgba16float,
        \\    r32uint,
        \\    r32sint,
        \\    r32float,
        \\    rg32uint,
        \\    rg32sint,
        \\    rg32float,
        \\    rgba32uint,
        \\    rgba32sint,
        \\    rgba32float,
        \\    bgra8unorm,
        \\}
        \\
        \\Texture_2D :: struct ($T: typeid) where is(T, {f32, i32}) {}
        \\sample :: proc(texture: $Texture_T/$Texture_Dim($Texture_U), sampler: Sampler, uv: [2]f32) -> $TextureU { }
        \\magnitude :: proc(v: [3]f32) -> f32 { }
        \\normalise :: proc(v: [3]f32) -> [3]f32 { }
        \\dot :: proc(a: [3]f32, b: [3]f32) -> f32 { }
        \\max :: proc(a: f32, b: f32) -> f32 { }
        \\pow :: proc(a: f32, b: f32) -> f32 { }
    );

    const start = std.time.nanoTimestamp();
    var build = Build{};
    const context: *const @import("Context.zig") = &.{
        .err_handler = handle_err,
        .file_provider = fp,
        .allocator = std.heap.page_allocator,
    };
    try build.init(context);
    defer build.deinit();

    try build.addCollection("surge", "test/surge");
    try build.addPackage("test");
    build.wait();

    const end = std.time.nanoTimestamp();
    std.debug.print("time: {}\n", .{end - start});

    for (build.project.packages.items) |px| {
        std.debug.print("{s}\n", .{px.pathname});
    }

    var va = Validator{};
    try va.init(context, &build);
    defer va.deinit();

    try va.scanPackageRoot(&build.project.packages.items[0]);
}

pub fn handle_err(msg: []const u8) void {
    std.log.warn("{s}", .{msg});
}
