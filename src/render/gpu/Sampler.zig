const std = @import("std");

const Renderer = @import("Renderer.zig");
const Resource = Renderer.Resource;

const Self = @This();

resource: Resource = undefined,

pub const SamplerAddressMode = enum {
    repeat,
    mirror,
    clamp,
    border,
    mirror_once,
};

pub const SamplerFilter = enum { nearest, linear };

pub const SamplerDescriptor = struct {
    address_u: SamplerAddressMode = .repeat,
    address_v: SamplerAddressMode = .repeat,
    address_w: SamplerAddressMode = .repeat,
    min_filter: SamplerFilter = .linear,
    mag_filter: SamplerFilter = .linear,
    mip_filter: SamplerFilter = .linear,
    mip_map_filer: SamplerFilter = .linear,
    mip_map_enabled: bool = false,
    mip_map_lod_bias: f32 = 0.0,
    min_lod: f32 = 0.0,
    max_lod: f32 = 1000.0,
    max_anisotropy: f32 = 1.0,
    compare_enabled: bool = false,
    compare_operation: Renderer.PipelineState.CompareOperation = .less,
    border_colour: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
};

pub fn init(self: *Self) void {
    self.* = .{
        .resource = .{
            .fn_getResourceType = _getResourceType,
        },
    };
}

fn _getResourceType(self: *const Resource) Resource.ResourceType {
    _ = self;
    return .sampler;
}
