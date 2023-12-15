const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const BindGroupLayout = opaque {
    pub const Error = error{
        BindGroupLayoutFailedToCreate,
    };

    pub const Entry = struct {
        binding: u32,
        visibility: gpu.ShaderStageFlags,
        buffer: gpu.Buffer.BindingLayout = .{},
        sampler: gpu.Sampler.BindingLayout = .{},
        texture: gpu.Texture.BindingLayout = .{},
        storage_texture: gpu.StorageTextureBindingLayout = .{},

        pub fn buffer(
            binding: u32,
            visibility: gpu.ShaderStageFlags,
            binding_type: gpu.Buffer.BindingType,
            has_dynamic_offset: bool,
            min_binding_size: u64,
        ) Entry {
            return .{
                .binding = binding,
                .visibility = visibility,
                .buffer = .{
                    .type = binding_type,
                    .has_dynamic_offset = has_dynamic_offset,
                    .min_binding_size = min_binding_size,
                },
            };
        }

        pub fn sampler(
            binding: u32,
            visibility: gpu.ShaderStageFlags,
            binding_type: gpu.Sampler.BindingType,
        ) Entry {
            return .{
                .binding = binding,
                .visibility = visibility,
                .sampler = .{ .type = binding_type },
            };
        }

        pub fn texture(
            binding: u32,
            visibility: gpu.ShaderStageFlags,
            sample_type: gpu.Texture.SampleType,
            view_dimension: gpu.TextureView.Dimension,
            multisampled: bool,
        ) Entry {
            return .{
                .binding = binding,
                .visibility = visibility,
                .texture = .{
                    .sample_type = sample_type,
                    .view_dimension = view_dimension,
                    .multisampled = multisampled,
                },
            };
        }

        pub fn storageTexture(
            binding: u32,
            visibility: gpu.ShaderStageFlags,
            access: gpu.StorageTextureAccess,
            format: gpu.Texture.Format,
            view_dimension: gpu.TextureView.Dimension,
        ) Entry {
            return .{
                .binding = binding,
                .visibility = visibility,
                .storage_texture = .{
                    .access = access,
                    .format = format,
                    .view_dimension = view_dimension,
                },
            };
        }
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        entries: ?[]const Entry = null,
    };

    pub inline fn destroy(self: *BindGroupLayout) void {
        return impl.bindGroupLayoutDestroy(self);
    }
};
