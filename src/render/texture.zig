const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Texture = opaque {
    pub const Error = error{
        TextureFailedToCreate,
    };

    pub const Aspect = enum(u32) {
        all = 0x00000000,
        stencil_only = 0x00000001,
        depth_only = 0x00000002,
        plane0_only = 0x00000003,
        plane1_only = 0x00000004,
    };

    pub const Dimension = enum(u32) {
        dimension_1d = 0x00000000,
        dimension_2d = 0x00000001,
        dimension_3d = 0x00000002,
    };

    pub const Format = enum(u32) {
        undefined = 0x00000000,
        r8_unorm = 0x00000001,
        r8_snorm = 0x00000002,
        r8_uint = 0x00000003,
        r8_sint = 0x00000004,
        r16_uint = 0x00000005,
        r16_sint = 0x00000006,
        r16_float = 0x00000007,
        rg8_unorm = 0x00000008,
        rg8_snorm = 0x00000009,
        rg8_uint = 0x0000000a,
        rg8_sint = 0x0000000b,
        r32_float = 0x0000000c,
        r32_uint = 0x0000000d,
        r32_sint = 0x0000000e,
        rg16_uint = 0x0000000f,
        rg16_sint = 0x00000010,
        rg16_float = 0x00000011,
        rgba8_unorm = 0x00000012,
        rgba8_unorm_srgb = 0x00000013,
        rgba8_snorm = 0x00000014,
        rgba8_uint = 0x00000015,
        rgba8_sint = 0x00000016,
        bgra8_unorm = 0x00000017,
        bgra8_unorm_srgb = 0x00000018,
        rgb10_a2_unorm = 0x00000019,
        rg11_b10_ufloat = 0x0000001a,
        rgb9_e5_ufloat = 0x0000001b,
        rg32_float = 0x0000001c,
        rg32_uint = 0x0000001d,
        rg32_sint = 0x0000001e,
        rgba16_uint = 0x0000001f,
        rgba16_sint = 0x00000020,
        rgba16_float = 0x00000021,
        rgba32_float = 0x00000022,
        rgba32_uint = 0x00000023,
        rgba32_sint = 0x00000024,
        stencil8 = 0x00000025,
        depth16_unorm = 0x00000026,
        depth24_plus = 0x00000027,
        depth24_plus_stencil8 = 0x00000028,
        depth32_float = 0x00000029,
        depth32_float_stencil8 = 0x0000002a,
        bc1_rgba_unorm = 0x0000002b,
        bc1_rgba_unorm_srgb = 0x0000002c,
        bc2_rgba_unorm = 0x0000002d,
        bc2_rgba_unorm_srgb = 0x0000002e,
        bc3_rgba_unorm = 0x0000002f,
        bc3_rgba_unorm_srgb = 0x00000030,
        bc4_runorm = 0x00000031,
        bc4_rsnorm = 0x00000032,
        bc5_rg_unorm = 0x00000033,
        bc5_rg_snorm = 0x00000034,
        bc6_hrgb_ufloat = 0x00000035,
        bc6_hrgb_float = 0x00000036,
        bc7_rgba_unorm = 0x00000037,
        bc7_rgba_unorm_srgb = 0x00000038,
        etc2_rgb8_unorm = 0x00000039,
        etc2_rgb8_unorm_srgb = 0x0000003a,
        etc2_rgb8_a1_unorm = 0x0000003b,
        etc2_rgb8_a1_unorm_srgb = 0x0000003c,
        etc2_rgba8_unorm = 0x0000003d,
        etc2_rgba8_unorm_srgb = 0x0000003e,
        eacr11_unorm = 0x0000003f,
        eacr11_snorm = 0x00000040,
        eacrg11_unorm = 0x00000041,
        eacrg11_snorm = 0x00000042,
        astc4x4_unorm = 0x00000043,
        astc4x4_unorm_srgb = 0x00000044,
        astc5x4_unorm = 0x00000045,
        astc5x4_unorm_srgb = 0x00000046,
        astc5x5_unorm = 0x00000047,
        astc5x5_unorm_srgb = 0x00000048,
        astc6x5_unorm = 0x00000049,
        astc6x5_unorm_srgb = 0x0000004a,
        astc6x6_unorm = 0x0000004b,
        astc6x6_unorm_srgb = 0x0000004c,
        astc8x5_unorm = 0x0000004d,
        astc8x5_unorm_srgb = 0x0000004e,
        astc8x6_unorm = 0x0000004f,
        astc8x6_unorm_srgb = 0x00000050,
        astc8x8_unorm = 0x00000051,
        astc8x8_unorm_srgb = 0x00000052,
        astc10x5_unorm = 0x00000053,
        astc10x5_unorm_srgb = 0x00000054,
        astc10x6_unorm = 0x00000055,
        astc10x6_unorm_srgb = 0x00000056,
        astc10x8_unorm = 0x00000057,
        astc10x8_unorm_srgb = 0x00000058,
        astc10x10_unorm = 0x00000059,
        astc10x10_unorm_srgb = 0x0000005a,
        astc12x10_unorm = 0x0000005b,
        astc12x10_unorm_srgb = 0x0000005c,
        astc12x12_unorm = 0x0000005d,
        astc12x12_unorm_srgb = 0x0000005e,
        r8_bg8_biplanar420_unorm = 0x0000005f,

        pub const Kind = enum {
            integer,
            normalised,
            float,
            depth_stencil,
        };

        pub const Info = struct {
            format: Format,
            name: []const u8,
            bytes_per_block: u8,
            block_size: u8,
            kind: Kind,
            has_red: bool = false,
            has_green: bool = false,
            has_blue: bool = false,
            has_alpha: bool = false,
            has_depth: bool = false,
            has_stencil: bool = false,
            signed: bool = false,
            rgb: bool = false,
        };

        const format_map = [_]Info{.{
            .format = .undefined,
            .name = "undefined",
            .bytes_per_block = 0,
            .block_size = 0,
            .kind = .integer,
        }};
    };

    pub const SampleType = enum(u32) {
        undefined = 0x00000000,
        float = 0x00000001,
        unfilterable_float = 0x00000002,
        depth = 0x00000003,
        sint = 0x00000004,
        uint = 0x00000005,
    };

    pub const UsageFlags = packed struct(u32) {
        copy_src: bool = false,
        copy_dst: bool = false,
        texture_binding: bool = false,
        storage_binding: bool = false,
        render_attachment: bool = false,
        transient_attachment: bool = false,

        _padding: u26 = 0,

        comptime {
            std.debug.assert(
                @sizeOf(@This()) == @sizeOf(u32) and
                    @bitSizeOf(@This()) == @bitSizeOf(u32),
            );
        }

        pub const none = UsageFlags{};

        pub fn equal(a: UsageFlags, b: UsageFlags) bool {
            return @as(u6, @truncate(@as(u32, @bitCast(a)))) == @as(u6, @truncate(@as(u32, @bitCast(b))));
        }
    };

    pub const BindingLayout = struct {
        sample_type: SampleType = .undefined,
        view_dimension: gpu.TextureView.Dimension = .dimension_undefined,
        multisampled: bool = false,
    };

    pub const DataLayout = struct {
        offset: u64 = 0,
        bytes_per_row: u32 = gpu.copy_stride_undefined,
        rows_per_image: u32 = gpu.copy_stride_undefined,
    };

    pub const Descriptor = struct {
        usage: UsageFlags,
        dimension: Dimension = .dimension_2d,
        size: gpu.Extent3D,
        format: Format,
        mip_level_count: u32 = 1,
        sample_count: u32 = 1,
        view_formats: ?[]const Format = null,
    };

    pub inline fn createView(texture: *Texture, descriptor: ?*const gpu.TextureView.Descriptor) *gpu.TextureView {
        return impl.textureCreateView(texture, descriptor);
    }

    pub inline fn destroy(texture: *Texture) void {
        impl.textureDestroy(texture);
    }

    pub inline fn getDepthOrArrayLayers(texture: *Texture) u32 {
        return impl.textureGetDepthOrArrayLayers(texture);
    }

    pub inline fn getDimension(texture: *Texture) Dimension {
        return impl.textureGetDimension(texture);
    }

    pub inline fn getFormat(texture: *Texture) Format {
        return impl.textureGetFormat(texture);
    }

    pub inline fn getHeight(texture: *Texture) u32 {
        return impl.textureGetHeight(texture);
    }

    pub inline fn getWidth(texture: *Texture) u32 {
        return impl.textureGetWidth(texture);
    }

    pub inline fn getMipLevelCount(texture: *Texture) u32 {
        return impl.textureGetMipLevelCount(texture);
    }

    pub inline fn getSampleCount(texture: *Texture) u32 {
        return impl.textureGetSampleCount(texture);
    }

    pub inline fn getUsage(texture: *Texture) UsageFlags {
        return impl.textureGetUsage(texture);
    }
};
