const std = @import("std");

const Renderer = @import("Renderer.zig");
const Resource = Renderer.Resource;

const Self = @This();

resource: Resource = undefined,

vtable: *const struct {
    getDescriptor: *const fn (*const Self) TextureDescriptor,
    getFormat: *const fn (*const Self) Renderer.format.Format,
    getMipExtent: *const fn (*const Self, u32) [3]u32,
    getSubresourceFootprint: *const fn (*const Self, u32) SubresourceFootprint,
},

texture_type: TextureType,
binding: Resource.BindingInfo,

pub const TextureType = enum {
    texture_1d,
    texture_2d,
    texture_3d,
    texture_cube,
    texture_1d_array,
    texture_2d_array,
    texture_cube_array,
    texture_2d_multisample,
    texture_2d_multisample_array,

    pub fn getTextureExtent(self: TextureType, extent: [3]u32, num_array_layers: u32) [3]u32 {
        return switch (self) {
            .texture_1d => .{ extent[0], 1, 1 },
            .texture_1d_array => .{ extent[0], num_array_layers, 1 },

            .texture_2d, .texture_2d_multisample => .{ extent[0], extent[1], 1 },

            .texture_cube,
            .texture_2d_array,
            .texture_cube_array,
            .texture_2d_multisample_array,
            => .{
                extent[0],
                extent[1],
                num_array_layers,
            },
            .texture_3d => extent,
        };
    }

    pub fn numberOfMipLevels(self: TextureType, extent: [3]u32) u32 {
        return switch (self) {
            .texture_1d => Self.numberOfMipLevels(.{ extent[0], 0, 0 }),
            .texture_2d => Self.numberOfMipLevels(.{ extent[0], extent[1], 0 }),
            .texture_3d => Self.numberOfMipLevels(extent),
            .texture_cube => Self.numberOfMipLevels(.{ extent[0], extent[1], 0 }),
            .texture_1d_array => Self.numberOfMipLevels(.{ extent[0], 0, 0 }),
            .texture_2d_array => Self.numberOfMipLevels(.{ extent[0], extent[1], 0 }),
            .texture_cube_array => Self.numberOfMipLevels(.{ extent[0], extent[1], 0 }),
            .texture_2d_multisample => 1,
            .texture_2d_multisample_array => 1,
            else => 0,
        };
    }

    pub fn getMipExtent(self: TextureType, extent: [3]u32, mip_level: u32) [3]u32 {
        return switch (self) {
            .texture_1d => .{ mipExtent(extent[0], mip_level), 1, 1 },
            .texture_2d => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                1,
            },
            .texture_3d => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                mipExtent(extent[2], mip_level),
            },
            .texture_cube => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                6,
            },
            .texture_1d_array => .{
                mipExtent(extent[0], mip_level),
                extent[1],
                1,
            },
            .texture_2d_array => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                extent[2],
            },
            .texture_cube_array => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                extent[2],
            },
            .texture_2d_multisample => .{ extent[0], extent[1], 1 },
            .texture_2d_multisample_array => .{ extent[0], extent[1], extent[2] },
        };
    }

    pub fn numberOfMipTexels(self: TextureType, extent: [3]u32, mip_level: u32) u32 {
        const mip_extent = self.getMipExtent(extent, mip_level);
        return mip_extent[0] * mip_extent[1] * mip_extent[2];
    }

    pub fn numberOfMipTexelsForSubresource(
        self: TextureType,
        extent: [3]u32,
        subresource: TextureSubresource,
    ) u32 {
        var num_texels: u32 = 0;

        const subresource_extent = self.getTextureExtent(
            extent,
            subresource.num_array_layers,
        );
        for (0..subresource.num_mip_levels) |i| {
            num_texels += self.numberOfMipTexels(subresource_extent, subresource.base_mip_level + i);
        }

        return num_texels;
    }

    pub fn getMemoryFootprint(
        self: TextureType,
        fmt: Renderer.format.Format,
        extent: [3]u32,
        subresource: TextureSubresource,
    ) usize {
        const num_texels = self.numberOfMipTexelsForSubresource(extent, subresource);
        return Renderer.format.getTexelMemoryFootprint(fmt, num_texels);
    }

    pub fn isMultisample(self: TextureType) bool {
        return switch (self) {
            .texture_2d_multisample, .texture_2d_multisample_array => true,
            else => false,
        };
    }

    pub fn isArray(self: TextureType) bool {
        return switch (self) {
            .texture_1d_array,
            .texture_2d_array,
            .texture_cube_array,
            .texture_2d_multisample_array,
            => true,
            else => false,
        };
    }

    pub fn isCube(self: TextureType) bool {
        return switch (self) {
            .texture_cube, .texture_cube_array => true,
            else => false,
        };
    }
};

pub const TextureSwizzle = enum {
    zero,
    one,
    red,
    green,
    blue,
    alpha,
};

pub const TextureSwizzleRGBA = struct {
    r: TextureSwizzle = .red,
    g: TextureSwizzle = .green,
    b: TextureSwizzle = .blue,
    a: TextureSwizzle = .alpha,

    pub fn isIdentity(self: TextureSwizzleRGBA) bool {
        return self.r == .red and self.g == .green and self.b == .blue and self.a == .alpha;
    }
};

pub const TextureSubresource = struct {
    base_array_layer: u32 = 0,
    num_array_layers: u32 = 1,
    base_mip_level: u32 = 0,
    num_mip_levels: u32 = 1,
};

pub const TextureLocation = struct {
    offset: [3]i32 = .{ 0, 0, 0 },
    array_layer: u32 = 0,
    mip_level: u32 = 0,
};

pub const TextureRegion = struct {
    subresource: TextureSubresource = .{},
    offset: [3]i32 = .{ 0, 0, 0 },
    extent: [3]u32 = .{ 0, 0, 0 },
};

pub const TextureDescriptor = struct {
    texture_type: TextureType = .texture_2d,
    binding: Resource.BindingInfo = .{},
    info: Resource.ResourceInfo = .{},
    format: Renderer.format.Format = .rgba8unorm,
    extent: [3]u32 = .{ 1, 1, 1 },
    array_layers: u32 = 1,
    mip_levels: u32 = 0,
    samples: u32 = 1,
    clear_value: Renderer.CommandBuffer.ClearValue = .{},

    pub fn numberOfMipLevels(self: TextureDescriptor) u32 {
        if (self.mip_levels == 0) return self.texture_type.numberOfMipLevels(self.extent);
        return self.mip_levels;
    }

    pub fn getMipExtent(self: TextureDescriptor, mip_level: u32) [3]u32 {
        const extent = self.extent;
        if (mip_level >= self.texture_type.numberOfMipLevels(extent)) return;
        const array_layers = self.array_layers;
        return switch (self) {
            .texture_1d => .{ mipExtent(extent[0], mip_level), 1, 1 },
            .texture_2d => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                1,
            },
            .texture_3d => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                mipExtent(extent[2], mip_level),
            },
            .texture_cube => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                6,
            },
            .texture_1d_array => .{
                mipExtent(extent[0], mip_level),
                array_layers,
                1,
            },
            .texture_2d_array => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                array_layers,
            },
            .texture_cube_array => .{
                mipExtent(extent[0], mip_level),
                mipExtent(extent[1], mip_level),
                std.mem.alignForward(u32, array_layers, 6),
            },
            .texture_2d_multisample => .{ extent[0], extent[1], 1 },
            .texture_2d_multisample_array => .{ extent[0], extent[1], array_layers },
        };
    }

    pub fn numberOfMipTexels(self: TextureDescriptor, mip_level: ?u32) u32 {
        const extent = self.texture_type.getTextureExtent(
            self.extent,
            self.array_layers,
        );

        if (mip_level == null) {
            var num_texels: u32 = 0;
            for (0..self.numberOfMipLevels()) |i| {
                num_texels += self.texture_type.numberOfMipTexels(extent, i);
            }
            return num_texels;
        }

        return self.texture_type.numberOfMipTexels(extent, mip_level.?);
    }

    pub fn isMipMapped(self: TextureDescriptor) bool {
        return !self.texture_type.isMultisample() and (self.mip_levels == 0 or self.mip_levels > 0);
    }
};

pub const TextureViewDescriptor = struct {
    texture_type: TextureType = .texture_2d,
    format: Renderer.format.Format = .rgba8unorm,
    subresource: TextureSubresource = .{},
    swizzle: TextureSwizzleRGBA = .{},
};

pub const SubresourceFootprint = struct {
    size: u64 = 0,
    row_alignment: u32 = 0,
    row_size: u32 = 0,
    row_stride: u32 = 0,
    layer_size: u32 = 0,
    layer_stride: u32 = 0,
};

pub inline fn numberOfMipLevels(extent: [3]u32) u32 {
    const width: u32 = extent[0];
    const height: u32 = extent[1];
    const depth: u32 = extent[2];
    const max_size = @max(@max(width, height), depth);
    const log2size: u32 = @intFromFloat(@round(
        @log2(@as(f64, @floatFromInt(max_size))),
    ));
    return 1 + log2size;
}

pub inline fn mipExtent(extent: u32, mip_level: u32) u32 {
    return @max(1, extent >> mip_level);
}

pub fn calculatePackedSubResourceFootprint(
    texture_type: TextureType,
    fmt: Renderer.format.Format,
    extent: [3]u32,
    mip_level: u32,
    num_array_layers: u32,
    alignment: ?u32,
) SubresourceFootprint {
    var footprint: SubresourceFootprint = .{};
    const _alignment = alignment orelse 1;
    const mip_extent = texture_type.getMipExtent(extent, mip_level);
    const num_layers = mip_extent[2] * num_array_layers;
    footprint.row_alignment = _alignment;
    footprint.row_size = Renderer.format.getTexelMemoryFootprint(fmt, mip_extent[0]);
    footprint.row_stride = std.mem.alignForward(u32, footprint.row_size, _alignment);
    footprint.layer_size = if (mip_extent[1] > 1)
        footprint.row_stride * (mip_extent[1] - 1) + footprint.row_size
    else
        footprint.row_size * mip_extent[1];
    footprint.layer_stride = footprint.row_stride * mip_extent[1];
    footprint.size = if (num_layers > 1)
        footprint.layer_stride * (num_layers - 1) + footprint.layer_size
    else
        footprint.layer_size * num_layers;
    return footprint;
}

pub const SubresourceLayout = struct {
    row_stride: u32 = 0,
    layer_stride: u32 = 0,
    subresource_size: u32 = 0,
};

pub const SubresourceCPUMappingLayout = struct {
    base: SubresourceLayout = .{},
    num_texels_per_layer: u32 = 0,
    num_texels_total: u32 = 0,
    image_size: usize = 0,
};

// pub const CompressedTextureView = struct {

// };

pub fn calculateTextureOffset(texture_type: TextureType, offset: [3]i32, base_array_layer: ?u32) [3]i32 {
    const array_layer: i32 = @intCast(base_array_layer orelse 0);
    return switch (texture_type) {
        .texture_1d => .{ offset[0], 0, 0 },
        .texture_1d_array => .{ offset[0], array_layer, 0 },
        .texture_2d, .texture_2d_multisample => .{ offset[0], offset[1], 0 },
        .texture_2d_array,
        .texture_2d_multisample_array,
        .texture_cube,
        .texture_cube_array,
        => .{ offset[0], offset[1], array_layer },
        .texture_3d => offset,
    };
}

pub fn calculateTextureExtent(texture_type: TextureType, extent: [3]u32, num_array_layers: ?u32) [3]u32 {
    const array_layers = num_array_layers orelse 1;
    return switch (texture_type) {
        .texture_1d => .{ extent[0], 1, 1 },
        .texture_1d_array => .{ extent[0], array_layers, 1 },
        .texture_2d, .texture_2d_multisample => .{ extent[0], extent[1], 1 },
        .texture_2d_array,
        .texture_2d_multisample_array,
        .texture_cube,
        .texture_cube_array,
        => .{ extent[0], extent[1], array_layers },
        .texture_3d => extent,
    };
}

pub fn calculateSubresourceLayoutPrimary(
    out_layout: *SubresourceLayout,
    format: Renderer.format.Format,
    extent: [3]u32,
    num_array_layers: u32,
) void {
    const format_attributes = Renderer.format.getFormatAttributes(format) orelse return;
    if (format_attributes.block_width > 0 and format_attributes.block_height > 0) {
        out_layout.row_stride = extent[0] * format_attributes.bit_size / format_attributes.block_width / 8;
        out_layout.layer_stride = extent[1] * out_layout.row_stride / format_attributes.block_height;
        out_layout.subresource_size = extent[2] * out_layout.layer_stride * @max(1, num_array_layers);
    }
}

pub fn calculateSubresourceCPUMappingLayout(
    format: Renderer.format.Format,
    extent: [3]u32,
    num_array_layers: u32,
    image_format: Renderer.format.ImageFormat,
    image_data_type: Renderer.format.DataType,
) SubresourceCPUMappingLayout {
    _ = image_format;
    var layout = SubresourceCPUMappingLayout{};
    calculateSubresourceLayoutPrimary(
        &layout.base,
        format,
        extent,
        num_array_layers,
    );
    layout.num_texels_per_layer = extent[0] * extent[1] * extent[2];
    layout.num_texels_total = layout.num_texels_per_layer * num_array_layers;
    layout.image_size = Renderer.format.getDataTypeMemoryFootprint(
        format,
        image_data_type,
        layout.num_texels_total,
    );
    return layout;
}

pub fn init(self: *Self, texture_type: TextureType, binding: Renderer.Resource.BindingInfo) void {
    self.* = .{
        .resource = .{
            .fn_getResourceType = &Self._getResourceType,
        },
        .texture_type = texture_type,
        .binding = binding,
    };
}

fn _getResourceType(self: *const Resource) Resource.ResourceType {
    _ = self;
    return .texture;
}
