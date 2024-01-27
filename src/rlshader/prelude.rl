package shader

vec2i :: [2]i32
vec3i :: [3]i32
vec4i :: [4]i32
vec2u :: [2]u32
vec3u :: [3]u32
vec4u :: [4]u32
vec2f :: [2]f32
vec3f :: [3]f32
vec4f :: [4]f32

mat2x2f :: matrix[2, 2]f32
mat2x3f :: matrix[2, 3]f32
mat2x4f :: matrix[2, 4]f32
mat3x2f :: matrix[3, 2]f32
mat3x3f :: matrix[3, 3]f32
mat3x4f :: matrix[3, 4]f32
mat4x2f :: matrix[4, 2]f32
mat4x3f :: matrix[4, 3]f32
mat4x4f :: matrix[4, 4]f32

// atomic :: struct ($T: typeid) where type_is_integer(T) {}

Texel_Format :: enum {
    rgba8unorm,
    rgba8snorm,
    rgba8uint,
    rgba8sint,
    rgba16uint,
    rgba16sint,
    rgba16float,
    r32uint,
    r32sint,
    r32float,
    rg32uint,
    rg32sint,
    rg32float,
    rgba32uint,
    rgba32sint,
    rgba32float,
    bgra8unorm,
}

// @(builtin=x)
// vertex_index: u32, .vertex input
// instance_index: u32, .vertex input
// position: vec4f, .vertex output
//          .fragment input
// front_facing: bool, .fragment input
// frag_depth: f32, .fragment output
// sample_index: u32, .fragment input
// sample_mask: u32, .fragment input
//          .fragment output
// local_invocation_id: vec3u, .compute input
// local_invocation_index: u32, .compute input
// workgroup_id: vec3u, .compute input
// num_workgroups: vec3u, .compute input
