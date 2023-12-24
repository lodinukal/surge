const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const BindGroup = opaque {
    pub const Error = error{
        BindGroupFailedToCreate,
        BindGroupUnknownBinding,
        BindGroupMismatchedBindingType,
    };

    pub const Entry = struct {
        binding: u32,
        type: union(enum) {
            buffers: []const gpu.Buffer.Binding,
            samplers: []const *gpu.Sampler,
            texture_views: []const *gpu.TextureView,
        },

        pub fn fromBuffers(binding: u32, buffers: []const gpu.Buffer.Binding) Entry {
            return Entry{
                .binding = binding,
                .type = .{
                    .buffers = buffers,
                },
            };
        }

        pub fn fromSamplers(binding: u32, samplers: []const *gpu.Sampler) Entry {
            return Entry{
                .binding = binding,
                .type = .{
                    .samplers = samplers,
                },
            };
        }

        pub fn fromTextureViews(binding: u32, texture_views: []const *gpu.TextureView) Entry {
            return Entry{
                .binding = binding,
                .type = .{
                    .texture_views = texture_views,
                },
            };
        }
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        layout: *gpu.BindGroupLayout,
        entries: []const Entry = &.{},
    };

    pub inline fn destroy(self: *BindGroup) void {
        impl.bindGroupDestroy(self);
    }
};
