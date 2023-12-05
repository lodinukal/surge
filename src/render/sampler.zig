const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Sampler = opaque {
    pub const Error = error{
        SamplerFailedToCreate,
        SamplerFailedToSubmit,
    };

    pub const AddressMode = enum(u32) {
        repeat = 0x00000000,
        mirror_repeat = 0x00000001,
        clamp_to_edge = 0x00000002,
    };

    pub const BindingType = enum(u32) {
        undefined = 0x00000000,
        filtering = 0x00000001,
        non_filtering = 0x00000002,
        comparison = 0x00000003,
    };

    pub const BindingLayout = extern struct {
        type: BindingType = .undefined,
    };

    pub const Descriptor = extern struct {
        label: ?[]const u8 = null,
        address_mode_u: AddressMode = .clamp_to_edge,
        address_mode_v: AddressMode = .clamp_to_edge,
        address_mode_w: AddressMode = .clamp_to_edge,
        mag_filter: gpu.FilterMode = .nearest,
        min_filter: gpu.FilterMode = .nearest,
        mipmap_filter: gpu.MipmapFilterMode = .nearest,
        lod_min_clamp: f32 = 0.0,
        lod_max_clamp: f32 = 32.0,
        compare: gpu.CompareFunction = .undefined,
        max_anisotropy: u16 = 1,
    };

    pub inline fn destroy(self: *Sampler) void {
        impl.samplerDestroy(self);
    }
};
