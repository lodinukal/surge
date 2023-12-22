const std = @import("std");

// example:
// Uniforms :: struct {
//     rotation: f32,
//     resolution: vec2f,
// }
// @set(0, 0) lights: uniform<Uniforms>;
//
// // texture
// @set(1, 1) texture: texture2D;
// @set(1, 2) sampler: sampler;
//
// InputVS :: struct {
//     @location(0) position: vec3f,
//     @location(1) tex_coords: vec2f,
// }
//
// OutputVS :: struct {
//     position: vec4f,
//     tex_coords: vec2f,
// }
//
// @vertex
// vs_main :: fn(inp: InputVS) -> OutputVS {
//     outp := OutputVS{};
//     outp.position = inp.position;
//     outp.tex_coords = inp.tex_coords;
//     return outp;
// }
//
// @pixel
// ps_main :: fn(inp: OutputVS) -> vec4f {
//     aspect := lights.resolution.x / lights.resolution.y;
//     uv := inp.tex_coords;
//     uv -= vec2f{0.5, 0.5};
//     uv.x *= aspect;
//     uv += vec2f{0.5, 0.5};
//     if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
//         discard;
//     }
//     colour := texture.sample(sampler, uv);
//     return colour;
// }
