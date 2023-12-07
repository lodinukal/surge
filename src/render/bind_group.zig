const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const BindGroup = opaque {
    pub const Error = error{
        BindGroupFailedToCreate,
        BindGroupUnknownBinding,
    };

    pub const Entry = struct {
        binding: u32,
        buffer: ?*gpu.Buffer = null,
        offset: u64 = 0,
        size: u64,
        element_size: u32 = 0,
        sampler: ?*gpu.Sampler = null,
        texture_view: ?*gpu.TextureView = null,

        pub fn fromBuffer(binding: u32, buffer: *gpu.Buffer, offset: u64, size: u64, elem_size: u32) Entry {
            return Entry{
                .binding = binding,
                .buffer = buffer,
                .offset = offset,
                .size = size,
                .element_size = elem_size,
            };
        }

        pub fn fromSampler(binding: u32, sampler: *gpu.Sampler) Entry {
            return Entry{
                .binding = binding,
                .sampler = sampler,
                .size = 0,
            };
        }

        pub fn fromTextureView(binding: u32, texture_view: *gpu.TextureView) Entry {
            return Entry{
                .binding = binding,
                .texture_view = texture_view,
                .size = 0,
            };
        }
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        layout: *gpu.BindGroupLayout,
        entries: ?[]const Entry = null,
    };

    pub inline fn destroy(self: *BindGroup) void {
        impl.bindGroupDestroy(self);
    }
};
