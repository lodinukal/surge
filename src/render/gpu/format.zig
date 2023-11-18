const std = @import("std");

pub const Format = enum {
    undefined, // Undefined format.

    // Alpha channel color formats
    a8unorm, // Alpha channel format: alpha 8-bit normalised unsigned integer component.

    // Red channel color formats
    r8unorm, // Ordinary color format: red 8-bit normalised unsigned integer component.
    r8snorm, // Ordinary color format: red 8-bit normalised signed integer component.
    r8uint, // Ordinary color format: red 8-bit unsigned integer component.
    r8sint, // Ordinary color format: red 8-bit signed integer component.

    r16unorm, // Ordinary color format: red 16-bit normalised unsigned interger component.
    r16snorm, // Ordinary color format: red 16-bit normalised signed interger component.
    r16uint, // Ordinary color format: red 16-bit unsigned interger component.
    r16sint, // Ordinary color format: red 16-bit signed interger component.
    r16float, // Ordinary color format: red 16-bit floating point component.

    r32uint, // Ordinary color format: red 32-bit unsigned interger component.
    r32sint, // Ordinary color format: red 32-bit signed interger component.
    r32float, // Ordinary color format: red 32-bit floating point component.

    r64float, // Ordinary color format: red 64-bit floating point component. \note Only supported with: Vulkan.

    // RG color formats
    rg8unorm, // Ordinary color format: red, green 8-bit normalised unsigned integer components.
    rg8snorm, // Ordinary color format: red, green 8-bit normalised signed integer components.
    rg8uint, // Ordinary color format: red, green 8-bit unsigned integer components.
    rg8sint, // Ordinary color format: red, green 8-bit signed integer components.

    rg16unorm, // Ordinary color format: red, green 16-bit normalised unsigned interger components.
    rg16snorm, // Ordinary color format: red, green 16-bit normalised signed interger components.
    rg16uint, // Ordinary color format: red, green 16-bit unsigned interger components.
    rg16sint, // Ordinary color format: red, green 16-bit signed interger components.
    rg16float, // Ordinary color format: red, green 16-bit floating point components.

    rg32uint, // Ordinary color format: red, green 32-bit unsigned interger components.
    rg32sint, // Ordinary color format: red, green 32-bit signed interger components.
    rg32float, // Ordinary color format: red, green 32-bit floating point components.

    rg64float, // Ordinary color format: red, green 64-bit floating point components. \note Only supported with: Vulkan.

    // RGB color formats
    rgb8unorm, // Ordinary color format: red, green, blue 8-bit normalised unsigned integer components. \note Only supported with: OpenGL, Vulkan.
    rgb8unorm_srgb, // Ordinary color format: red, green, blue 8-bit normalised unsigned integer components in non-linear sRGB color space. \note Only supported with: OpenGL, Vulkan.
    rgb8snorm, // Ordinary color format: red, green, blue 8-bit normalised signed integer components. \note Only supported with: OpenGL, Vulkan.
    rgb8uint, // Ordinary color format: red, green, blue 8-bit unsigned integer components. \note Only supported with: OpenGL, Vulkan.
    rgb8sint, // Ordinary color format: red, green, blue 8-bit signed integer components. \note Only supported with: OpenGL, Vulkan.

    rgb16unorm, // Ordinary color format: red, green, blue 16-bit normalised unsigned interger components. \note Only supported with: OpenGL, Vulkan.
    rgb16snorm, // Ordinary color format: red, green, blue 16-bit normalised signed interger components. \note Only supported with: OpenGL, Vulkan.
    rgb16uint, // Ordinary color format: red, green, blue 16-bit unsigned interger components. \note Only supported with: OpenGL, Vulkan.
    rgb16sint, // Ordinary color format: red, green, blue 16-bit signed interger components. \note Only supported with: OpenGL, Vulkan.
    rgb16float, // Ordinary color format: red, green, blue 16-bit floating point components. \note Only supported with: OpenGL, Vulkan.

    rgb32uint, // Ordinary color format: red, green, blue 32-bit unsigned interger components. \note As texture format only supported with: OpenGL, Vulkan, Direct3D 11, Direct3D 12.
    rgb32sint, // Ordinary color format: red, green, blue 32-bit signed interger components. \note As texture format only supported with: OpenGL, Vulkan, Direct3D 11, Direct3D 12.
    rgb32float, // Ordinary color format: red, green, blue 32-bit floating point components. \note As texture format only supported with: OpenGL, Vulkan, Direct3D 11, Direct3D 12.

    rgb64float, // Ordinary color format: red, green, blue 64-bit floating point components. \note Only supported with: Vulkan.

    // RGBA color formats
    rgba8unorm, // Ordinary color format: red, green, blue, alpha 8-bit normalised unsigned integer components.
    rgba8unorm_srgb, // Ordinary color format: red, green, blue, alpha 8-bit normalised unsigned integer components in non-linear sRGB color space.
    rgba8snorm, // Ordinary color format: red, green, blue, alpha 8-bit normalised signed integer components.
    rgba8uint, // Ordinary color format: red, green, blue, alpha 8-bit unsigned integer components.
    rgba8sint, // Ordinary color format: red, green, blue, alpha 8-bit signed integer components.

    rgba16unorm, // Ordinary color format: red, green, blue, alpha 16-bit normalised unsigned interger components.
    rgba16snorm, // Ordinary color format: red, green, blue, alpha 16-bit normalised signed interger components.
    rgba16uint, // Ordinary color format: red, green, blue, alpha 16-bit unsigned interger components.
    rgba16sint, // Ordinary color format: red, green, blue, alpha 16-bit signed interger components.
    rgba16float, // Ordinary color format: red, green, blue, alpha 16-bit floating point components.

    rgba32uint, // Ordinary color format: red, green, blue, alpha 32-bit unsigned interger components.
    rgba32sint, // Ordinary color format: red, green, blue, alpha 32-bit signed interger components.
    rgba32float, // Ordinary color format: red, green, blue, alpha 32-bit floating point components.

    rgba64float, // Ordinary color format: red, green, blue, alpha 64-bit floating point components. \note Only supported with: Vulkan.

    // BGRA color formats
    bgra8unorm, // Ordinary color format: blue, green, red, alpha 8-bit normalised unsigned integer components.
    bgra8unorm_srgb, // Ordinary color format: blue, green, red, alpha 8-bit normalised unsigned integer components in non-linear sRGB color space.
    bgra8snorm, // Ordinary color format: blue, green, red, alpha 8-bit normalised signed integer components. \note Only supported with: Vulkan.
    bgra8uint, // Ordinary color format: blue, green, red, alpha 8-bit unsigned integer components. \note Only supported with: Vulkan.
    bgra8sint, // Ordinary color format: blue, green, red, alpha 8-bit signed integer components. \note Only supported with: Vulkan.

    // Packed formats
    rgb10a2unorm, // Packed color format: red, green, blue 10-bit and alpha 2-bit normalised unsigned integer components.
    rgb10a2uint, // Packed color format: red, green, blue 10-bit and alpha 2-bit unsigned integer components.
    rg11b10float, // Packed color format: red, green 11-bit and blue 10-bit unsigned floating point, i.e. 6-bit mantissa for red and green, 5-bit mantissa for blue, and 5-bit exponent for all components.
    rgb9e5float, // Packed color format: red, green, blue 9-bit unsigned floating-point with shared 5-bit exponent, i.e. 9-bit mantissa for each component and one 5-bit exponent for all components.

    // Depth-stencil formats
    d16unorm, // Depth-stencil format: depth 16-bit normalised unsigned integer component.
    d24unorms8uint, // Depth-stencil format: depth 24-bit normalised unsigned integer component, and 8-bit unsigned integer stencil component.
    d32float, // Depth-stencil format: depth 32-bit floating point component.
    d32floats8x24uint, // Depth-stencil format: depth 32-bit floating point component, and 8-bit unsigned integer stencil components (where the remaining 24 bits are unused).
    //S8UInt,             // Stencil only format: 8-bit unsigned integer stencil component. \note Only supported with: OpenGL, Vulkan, Metal.

    // Block compression (BC) formats
    bc1unorm, // Compressed color format: S3TC BC1 compressed RGBA with normalised unsigned integer components in 64-bit per 4x4 block.
    bc1unorm_srgb, // Compressed color format: S3TC BC1 compressed RGBA with normalised unsigned integer components in 64-bit per 4x4 block in non-linear sRGB color space.
    bc2unorm, // Compressed color format: S3TC BC2 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block.
    bc2unorm_srgb, // Compressed color format: S3TC BC2 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block in non-linear sRGB color space.
    bc3unorm, // Compressed color format: S3TC BC3 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block.
    bc3unorm_srgb, // Compressed color format: S3TC BC3 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block in non-linear sRGB color space.
    bc4unorm, // Compressed color format: S3TC BC4 compressed red channel with normalised unsigned integer component in 64-bit per 4x4 block.
    bc4snorm, // Compressed color format: S3TC BC4 compressed red channel with normalised signed integer component 64-bit per 4x4 block.
    bc5unorm, // Compressed color format: S3TC BC5 compressed red and green channels with normalised unsigned integer components in 64-bit per 4x4 block.
    bc5snorm, // Compressed color format: S3TC BC5 compressed red and green channels with normalised signed integer components in 128-bit per 4x4 block.
};

pub const ImageFormat = enum {
    alpha,
    r,
    rg,
    rgb,
    bgr,
    rgba,
    bgra,
    argb,
    abgr,

    depth,
    depth_stencil,
    stencil,

    bc1,
    bc2,
    bc3,
    bc4,
    bc5,
};

pub const DataType = enum {
    undefined,
    i8,
    u8,
    i16,
    u16,
    i32,
    u32,
    f16,
    f32,
    f64,
};

pub const FormatInfo = packed struct {
    depth: bool = false,
    stencil: bool = false,
    srgb: bool = false,
    compressed: bool = false,
    normalised: bool = false,
    integer: bool = false,
    unsigned: bool = false,
    @"packed": bool = false,
    supports_render_target: bool = false,
    supports_mips: bool = false,
    supports_generate_mips: bool = false,
    supports_texture_1d: bool = false,
    supports_texture_2d: bool = false,
    supports_texture_3d: bool = false,
    supports_texture_cube: bool = false,
    supports_vertex: bool = false,

    pub fn unsignedInteger(self: FormatInfo) bool {
        return self.integer and self.unsigned;
    }

    pub fn depthStencil(self: FormatInfo) bool {
        return self.depth and self.stencil;
    }
};

pub const FormatAttributes = struct {
    bit_size: u16,
    block_width: u8,
    block_height: u8,
    component_count: u8,
    format: ImageFormat,
    data_type: DataType,
    info: FormatInfo,
};

const format_attributes = [_]FormatAttributes{
    // undefined
    .{
        .bit_size = 0,
        .block_width = 0,
        .block_height = 0,
        .component_count = 0,
        .format = .r,
        .data_type = .undefined,
        .info = .{},
    },
    // a8unorm
    .{
        .bit_size = 8,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .alpha,
        .data_type = .u8,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // red
    // r8unorm
    .{
        .bit_size = 8,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // r8snorm
    .{
        .bit_size = 8,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // r8uint
    .{
        .bit_size = 8,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // r8sint
    .{
        .bit_size = 8,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // r16unorm
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // r16snorm
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // r16uint
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // r16sint
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // r16float
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .f16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // r32uint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .u32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // r32sint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .i32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // r32float
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .f32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // r64float
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .r,
        .data_type = .f64,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rg
    // rg8unorm
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rg8snorm
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // rg8uint
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rg8sint
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rg16unorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rg16snorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // rg16uint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rg16sint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rg16float
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .f16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rg32uint
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .u32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rg32sint
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .i32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rg32float
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .f32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rg64float
    .{
        .bit_size = 128,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .rg,
        .data_type = .f64,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rgb
    // rgb8unorm
    .{
        .bit_size = 24,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rgb8unorm_srgb
    .{
        .bit_size = 24,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .u8,
        .info = .{
            .srgb = true,
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rgb8snorm
    .{
        .bit_size = 24,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // rgb8uint
    .{
        .bit_size = 24,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rgb8sint
    .{
        .bit_size = 24,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rgb16unorm
    .{
        .bit_size = 48,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rgb16snorm
    .{
        .bit_size = 48,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // rgb16uint
    .{
        .bit_size = 48,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rgb16sint
    .{
        .bit_size = 48,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rgb16float
    .{
        .bit_size = 48,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .f16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rgb32uint
    .{
        .bit_size = 96,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .u32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rgb32sint
    .{
        .bit_size = 96,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .i32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rgb32float
    .{
        .bit_size = 96,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .f32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rgb64float
    .{
        .bit_size = 192,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .f64,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rgba
    // rgba8unorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rgba8unorm_srgb
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u8,
        .info = .{
            .srgb = true,
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rgba8snorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // rgba8uint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rgba8sint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .i8,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rgba16unorm
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // rgba16snorm
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // rgba16uint
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rgba16sint
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .i16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rgba16float
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .f16,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rgba32uint
    .{
        .bit_size = 128,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // rgba32sint
    .{
        .bit_size = 128,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .i32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // rgba32float
    .{
        .bit_size = 128,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .f32,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // rgba64float
    .{
        .bit_size = 256,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .f64,
        .info = .{
            .supports_vertex = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
        },
    },
    // bgra
    // bgra8unorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .bgra,
        .data_type = .u8,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bgra8unorm_srgb
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .bgra,
        .data_type = .u8,
        .info = .{
            .srgb = true,
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bgra8snorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .bgra,
        .data_type = .i8,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
        },
    },
    // bgra8uint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .bgra,
        .data_type = .u8,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
        },
    },
    // bgra8sint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .bgra,
        .data_type = .i8,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
        },
    },
    // packed
    // rgb10a2unorm
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .u32,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .normalised = true,
            .@"packed" = true,
        },
    },
    // rgb10a2uint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 4,
        .format = .rgba,
        .data_type = .undefined,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .@"packed" = true,
        },
    },
    // rg11b10float
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .undefined,
        .info = .{
            .supports_generate_mips = true,
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .unsigned = true, // ufloat
            .@"packed" = true,
        },
    },
    // rgb9e5float
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 3,
        .format = .rgb,
        .data_type = .undefined,
        .info = .{
            .supports_mips = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .unsigned = true, // ufloat
            .@"packed" = true,
        },
    },
    // depth
    // d16unorm
    .{
        .bit_size = 16,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .depth,
        .data_type = .u16,
        .info = .{
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
            .depth = true,
        },
    },
    // d24unorms8uint
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .depth_stencil,
        .data_type = .u32,
        .info = .{
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_cube = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
            .depth = true,
            .stencil = true,
        },
    },
    // d32float
    .{
        .bit_size = 32,
        .block_width = 1,
        .block_height = 1,
        .component_count = 1,
        .format = .depth,
        .data_type = .f32,
        .info = .{
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_cube = true,
            .depth = true,
        },
    },
    // d32floats8x24uint
    .{
        .bit_size = 64,
        .block_width = 1,
        .block_height = 1,
        .component_count = 2,
        .format = .depth_stencil,
        .data_type = .f32,
        .info = .{
            .supports_mips = true,
            .supports_render_target = true,
            .supports_texture_1d = true,
            .supports_texture_2d = true,
            .supports_texture_cube = true,
            .depth = true,
            .stencil = true,
        },
    },
    // s8uint
    // .{
    //    .bit_size = 8,
    //    .block_width = 1,
    //    .block_height = 1,
    //    .component_count = 1,
    //    .format = .stencil,
    //    .data_type = .u8,
    //    .info = .{
    //        .supports_mips = true,
    //        .supports_render_target = true,
    //        .supports_texture_1d = true,
    //        .supports_texture_2d = true,
    //        .supports_texture_cube = true,
    //        .integer = true,
    //        .unsigned = true,
    //        .stencil = true,
    // }
    // block compressed
    // bc1unorm
    .{
        .bit_size = 64,
        .block_width = 4,
        .block_height = 4,
        .component_count = 4,
        .format = .bc2,
        .data_type = .u8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc1unorm_srgb
    .{
        .bit_size = 64,
        .block_width = 4,
        .block_height = 4,
        .component_count = 4,
        .format = .bc2,
        .data_type = .u8,
        .info = .{
            .srgb = true,
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc2unorm
    .{
        .bit_size = 128,
        .block_width = 4,
        .block_height = 4,
        .component_count = 4,
        .format = .bc2,
        .data_type = .u8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc2unorm_srgb
    .{
        .bit_size = 128,
        .block_width = 4,
        .block_height = 4,
        .component_count = 4,
        .format = .bc2,
        .data_type = .u8,
        .info = .{
            .srgb = true,
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc3unorm
    .{
        .bit_size = 128,
        .block_width = 4,
        .block_height = 4,
        .component_count = 4,
        .format = .bc3,
        .data_type = .u8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc3unorm_srgb
    .{
        .bit_size = 128,
        .block_width = 4,
        .block_height = 4,
        .component_count = 4,
        .format = .bc3,
        .data_type = .u8,
        .info = .{
            .srgb = true,
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc4unorm
    .{
        .bit_size = 64,
        .block_width = 4,
        .block_height = 4,
        .component_count = 1,
        .format = .bc4,
        .data_type = .u8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc4snorm
    .{
        .bit_size = 64,
        .block_width = 4,
        .block_height = 4,
        .component_count = 1,
        .format = .bc4,
        .data_type = .i8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .normalised = true,
        },
    },
    // bc5unorm
    .{
        .bit_size = 128,
        .block_width = 4,
        .block_height = 4,
        .component_count = 2,
        .format = .bc5,
        .data_type = .u8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .unsigned = true,
            .normalised = true,
        },
    },
    // bc5snorm
    .{
        .bit_size = 128,
        .block_width = 4,
        .block_height = 4,
        .component_count = 2,
        .format = .bc5,
        .data_type = .i8,
        .info = .{
            .supports_mips = true,
            .supports_texture_2d = true,
            .supports_texture_3d = true,
            .supports_texture_cube = true,
            .compressed = true,
            .integer = true,
            .normalised = true,
        },
    },
};

pub fn getFormatAttributes(fmt: Format) ?*const FormatAttributes {
    const index = @intFromEnum(fmt);
    if (index >= format_attributes.len) return null;
    return &format_attributes[index];
}

pub fn getTexelMemoryFootprint(fmt: Format, texels: usize) usize {
    const attribs = getFormatAttributes(fmt) orelse return 0;
    const block_size = attribs.block_width * attribs.block_height;
    if (block_size > 0 and texels % block_size != 0) {
        return @divExact(@divExact(texels, block_size) * attribs.bit_size, 8);
    }
    return 0;
}

pub inline fn getImageFormatSize(ifmt: ImageFormat) u32 {
    return switch (ifmt) {
        .alpha => 1,
        .r => 1,
        .rg => 2,
        .rgb => 3,
        .bgr => 3,
        .rgba => 4,
        .bgra => 4,
        .argb => 4,
        .abgr => 4,
        .depth => 1,
        .depth_stencil => 2,
        .stencil => 1,
        .bc1 => 0,
        .bc2 => 0,
        .bc3 => 0,
        .bc4 => 0,
        .bc5 => 0,
    };
}

pub fn getBytesPerPixel(imft: ImageFormat, dtype: DataType) u32 {
    if (imft == .depth_stencil) {
        if (dtype == .u32) return 4;
        if (dtype == .f32) return 4;
    }
    return getImageFormatSize(imft) * getDataTypeSize(dtype);
}

pub fn getDataTypeMemoryFootprint(imft: ImageFormat, dtype: DataType, texels: usize) usize {
    return getBytesPerPixel(imft, dtype) * texels;
}

pub fn isCompressedFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.compressed;
}

pub fn isCompressedImageFormat(imft: ImageFormat) bool {
    return switch (imft) {
        .bc1 => true,
        .bc2 => true,
        .bc3 => true,
        .bc4 => true,
        .bc5 => true,
        else => false,
    };
}

pub fn isDepthFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.depth;
}

pub fn isDepthImageFormat(imft: ImageFormat) bool {
    return switch (imft) {
        .depth => true,
        .depth_stencil => true,
        else => false,
    };
}

pub fn isStencilFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.stencil;
}

pub fn isStencilImageFormat(imft: ImageFormat) bool {
    return switch (imft) {
        .stencil => true,
        .depth_stencil => true,
        else => false,
    };
}

pub fn isDepthOrStencilFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.depth or attribs.info.stencil;
}

pub fn isDepthOrStencilImageFormat(imft: ImageFormat) bool {
    return switch (imft) {
        .depth => true,
        .stencil => true,
        .depth_stencil => true,
        else => false,
    };
}

pub fn isDepthStencilFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.depth and attribs.info.stencil;
}

pub fn isDepthStencilImageFormat(imft: ImageFormat) bool {
    return switch (imft) {
        .depth_stencil => true,
        else => false,
    };
}

pub fn isNormalisedFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.normalised;
}

pub fn isIntegralFormat(fmt: Format) bool {
    const attribs = getFormatAttributes(fmt) orelse return false;
    return attribs.info.integer;
}

pub fn isFloatFormat(fmt: Format) bool {
    return switch (fmt) {
        .r16float => true,
        .r32float => true,
        .r64float => true,
        .rg16float => true,
        .rg32float => true,
        .rg64float => true,
        .rgb16float => true,
        .rgb32float => true,
        .rgb64float => true,
        .rgba16float => true,
        .rgba32float => true,
        .rgba64float => true,
        else => false,
    };
}

pub fn getDataTypeSize(dtype: DataType) u32 {
    return switch (dtype) {
        .u8 => 1,
        .i8 => 1,
        .u16 => 2,
        .i16 => 2,
        .u32 => 4,
        .i32 => 4,
        .f16 => 2,
        .f32 => 4,
        .f64 => 8,
        else => 0,
    };
}

pub fn isIntDataType(dtype: DataType) bool {
    return switch (dtype) {
        .i8 => true,
        .i16 => true,
        .i32 => true,
        else => false,
    };
}

pub fn isUIntDataType(dtype: DataType) bool {
    return switch (dtype) {
        .u8 => true,
        .u16 => true,
        .u32 => true,
        else => false,
    };
}

pub fn isFloatDataType(dtype: DataType) bool {
    return switch (dtype) {
        .f16 => true,
        .f32 => true,
        .f64 => true,
        else => false,
    };
}

test {
    std.testing.refAllDecls(@This());
    inline for (std.meta.fields(Format)) |f| {
        const fmt = @field(Format, f.name);
        const attrs = getFormatAttributes(fmt);
        _ = attrs;
    }
}
