const std = @import("std");

pub const Format = enum {
    undefined, // Undefined format.

    // Alpha channel color formats
    A8UNorm, // Alpha channel format: alpha 8-bit normalised unsigned integer component.

    // Red channel color formats
    R8UNorm, // Ordinary color format: red 8-bit normalised unsigned integer component.
    R8SNorm, // Ordinary color format: red 8-bit normalised signed integer component.
    R8UInt, // Ordinary color format: red 8-bit unsigned integer component.
    R8SInt, // Ordinary color format: red 8-bit signed integer component.

    R16UNorm, // Ordinary color format: red 16-bit normalised unsigned interger component.
    R16SNorm, // Ordinary color format: red 16-bit normalised signed interger component.
    R16UInt, // Ordinary color format: red 16-bit unsigned interger component.
    R16SInt, // Ordinary color format: red 16-bit signed interger component.
    R16Float, // Ordinary color format: red 16-bit floating point component.

    R32UInt, // Ordinary color format: red 32-bit unsigned interger component.
    R32SInt, // Ordinary color format: red 32-bit signed interger component.
    R32Float, // Ordinary color format: red 32-bit floating point component.

    R64Float, // Ordinary color format: red 64-bit floating point component. \note Only supported with: Vulkan.

    // RG color formats
    RG8UNorm, // Ordinary color format: red, green 8-bit normalised unsigned integer components.
    RG8SNorm, // Ordinary color format: red, green 8-bit normalised signed integer components.
    RG8UInt, // Ordinary color format: red, green 8-bit unsigned integer components.
    RG8SInt, // Ordinary color format: red, green 8-bit signed integer components.

    RG16UNorm, // Ordinary color format: red, green 16-bit normalised unsigned interger components.
    RG16SNorm, // Ordinary color format: red, green 16-bit normalised signed interger components.
    RG16UInt, // Ordinary color format: red, green 16-bit unsigned interger components.
    RG16SInt, // Ordinary color format: red, green 16-bit signed interger components.
    RG16Float, // Ordinary color format: red, green 16-bit floating point components.

    RG32UInt, // Ordinary color format: red, green 32-bit unsigned interger components.
    RG32SInt, // Ordinary color format: red, green 32-bit signed interger components.
    RG32Float, // Ordinary color format: red, green 32-bit floating point components.

    RG64Float, // Ordinary color format: red, green 64-bit floating point components. \note Only supported with: Vulkan.

    // RGB color formats
    RGB8UNorm, // Ordinary color format: red, green, blue 8-bit normalised unsigned integer components. \note Only supported with: OpenGL, Vulkan.
    RGB8UNorm_sRGB, // Ordinary color format: red, green, blue 8-bit normalised unsigned integer components in non-linear sRGB color space. \note Only supported with: OpenGL, Vulkan.
    RGB8SNorm, // Ordinary color format: red, green, blue 8-bit normalised signed integer components. \note Only supported with: OpenGL, Vulkan.
    RGB8UInt, // Ordinary color format: red, green, blue 8-bit unsigned integer components. \note Only supported with: OpenGL, Vulkan.
    RGB8SInt, // Ordinary color format: red, green, blue 8-bit signed integer components. \note Only supported with: OpenGL, Vulkan.

    RGB16UNorm, // Ordinary color format: red, green, blue 16-bit normalised unsigned interger components. \note Only supported with: OpenGL, Vulkan.
    RGB16SNorm, // Ordinary color format: red, green, blue 16-bit normalised signed interger components. \note Only supported with: OpenGL, Vulkan.
    RGB16UInt, // Ordinary color format: red, green, blue 16-bit unsigned interger components. \note Only supported with: OpenGL, Vulkan.
    RGB16SInt, // Ordinary color format: red, green, blue 16-bit signed interger components. \note Only supported with: OpenGL, Vulkan.
    RGB16Float, // Ordinary color format: red, green, blue 16-bit floating point components. \note Only supported with: OpenGL, Vulkan.

    RGB32UInt, // Ordinary color format: red, green, blue 32-bit unsigned interger components. \note As texture format only supported with: OpenGL, Vulkan, Direct3D 11, Direct3D 12.
    RGB32SInt, // Ordinary color format: red, green, blue 32-bit signed interger components. \note As texture format only supported with: OpenGL, Vulkan, Direct3D 11, Direct3D 12.
    RGB32Float, // Ordinary color format: red, green, blue 32-bit floating point components. \note As texture format only supported with: OpenGL, Vulkan, Direct3D 11, Direct3D 12.

    RGB64Float, // Ordinary color format: red, green, blue 64-bit floating point components. \note Only supported with: Vulkan.

    // RGBA color formats
    RGBA8UNorm, // Ordinary color format: red, green, blue, alpha 8-bit normalised unsigned integer components.
    RGBA8UNorm_sRGB, // Ordinary color format: red, green, blue, alpha 8-bit normalised unsigned integer components in non-linear sRGB color space.
    RGBA8SNorm, // Ordinary color format: red, green, blue, alpha 8-bit normalised signed integer components.
    RGBA8UInt, // Ordinary color format: red, green, blue, alpha 8-bit unsigned integer components.
    RGBA8SInt, // Ordinary color format: red, green, blue, alpha 8-bit signed integer components.

    RGBA16UNorm, // Ordinary color format: red, green, blue, alpha 16-bit normalised unsigned interger components.
    RGBA16SNorm, // Ordinary color format: red, green, blue, alpha 16-bit normalised signed interger components.
    RGBA16UInt, // Ordinary color format: red, green, blue, alpha 16-bit unsigned interger components.
    RGBA16SInt, // Ordinary color format: red, green, blue, alpha 16-bit signed interger components.
    RGBA16Float, // Ordinary color format: red, green, blue, alpha 16-bit floating point components.

    RGBA32UInt, // Ordinary color format: red, green, blue, alpha 32-bit unsigned interger components.
    RGBA32SInt, // Ordinary color format: red, green, blue, alpha 32-bit signed interger components.
    RGBA32Float, // Ordinary color format: red, green, blue, alpha 32-bit floating point components.

    RGBA64Float, // Ordinary color format: red, green, blue, alpha 64-bit floating point components. \note Only supported with: Vulkan.

    // BGRA color formats
    BGRA8UNorm, // Ordinary color format: blue, green, red, alpha 8-bit normalised unsigned integer components.
    BGRA8UNorm_sRGB, // Ordinary color format: blue, green, red, alpha 8-bit normalised unsigned integer components in non-linear sRGB color space.
    BGRA8SNorm, // Ordinary color format: blue, green, red, alpha 8-bit normalised signed integer components. \note Only supported with: Vulkan.
    BGRA8UInt, // Ordinary color format: blue, green, red, alpha 8-bit unsigned integer components. \note Only supported with: Vulkan.
    BGRA8SInt, // Ordinary color format: blue, green, red, alpha 8-bit signed integer components. \note Only supported with: Vulkan.

    // Packed formats
    RGB10A2UNorm, // Packed color format: red, green, blue 10-bit and alpha 2-bit normalised unsigned integer components.
    RGB10A2UInt, // Packed color format: red, green, blue 10-bit and alpha 2-bit unsigned integer components.
    RG11B10Float, // Packed color format: red, green 11-bit and blue 10-bit unsigned floating point, i.e. 6-bit mantissa for red and green, 5-bit mantissa for blue, and 5-bit exponent for all components.
    RGB9E5Float, // Packed color format: red, green, blue 9-bit unsigned floating-point with shared 5-bit exponent, i.e. 9-bit mantissa for each component and one 5-bit exponent for all components.

    // Depth-stencil formats
    D16UNorm, // Depth-stencil format: depth 16-bit normalised unsigned integer component.
    D24UNormS8UInt, // Depth-stencil format: depth 24-bit normalised unsigned integer component, and 8-bit unsigned integer stencil component.
    D32Float, // Depth-stencil format: depth 32-bit floating point component.
    D32FloatS8X24UInt, // Depth-stencil format: depth 32-bit floating point component, and 8-bit unsigned integer stencil components (where the remaining 24 bits are unused).
    //S8UInt,             // Stencil only format: 8-bit unsigned integer stencil component. \note Only supported with: OpenGL, Vulkan, Metal.

    // Block compression (BC) formats
    BC1UNorm, // Compressed color format: S3TC BC1 compressed RGBA with normalised unsigned integer components in 64-bit per 4x4 block.
    BC1UNorm_sRGB, // Compressed color format: S3TC BC1 compressed RGBA with normalised unsigned integer components in 64-bit per 4x4 block in non-linear sRGB color space.
    BC2UNorm, // Compressed color format: S3TC BC2 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block.
    BC2UNorm_sRGB, // Compressed color format: S3TC BC2 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block in non-linear sRGB color space.
    BC3UNorm, // Compressed color format: S3TC BC3 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block.
    BC3UNorm_sRGB, // Compressed color format: S3TC BC3 compressed RGBA with normalised unsigned integer components in 128-bit per 4x4 block in non-linear sRGB color space.
    BC4UNorm, // Compressed color format: S3TC BC4 compressed red channel with normalised unsigned integer component in 64-bit per 4x4 block.
    BC4SNorm, // Compressed color format: S3TC BC4 compressed red channel with normalised signed integer component 64-bit per 4x4 block.
    BC5UNorm, // Compressed color format: S3TC BC5 compressed red and green channels with normalised unsigned integer components in 64-bit per 4x4 block.
    BC5SNorm, // Compressed color format: S3TC BC5 compressed red and green channels with normalised signed integer components in 128-bit per 4x4 block.
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
        return self.depth or self.stencil;
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
        },
    },
    // rgb
};

pub fn getFormatAttributes(fmt: Format) *const FormatAttributes {
    const index = @intFromEnum(fmt);
    return &format_attributes[index];
}

test {
    std.testing.refAllDecls(@This());
}
