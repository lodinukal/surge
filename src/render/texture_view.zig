const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const TextureView = opaque {
    pub const Dimension = enum(u32) {
        dimension_undefined = 0x00000000,
        dimension_1d = 0x00000001,
        dimension_2d = 0x00000002,
        dimension_2d_array = 0x00000003,
        dimension_cube = 0x00000004,
        dimension_cube_array = 0x00000005,
        dimension_3d = 0x00000006,
    };

    pub const Descriptor = struct {
        format: gpu.Texture.Format = .undefined,
        dimension: Dimension = .dimension_undefined,
        base_mip_level: u32 = 0,
        mip_level_count: ?u32 = null,
        base_array_layer: u32 = 0,
        array_layer_count: ?u32 = null,
        aspect: gpu.Texture.Aspect = .all,
    };
};
