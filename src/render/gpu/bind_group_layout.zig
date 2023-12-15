const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const BindGroupLayout = opaque {
    pub const Error = error{
        BindGroupLayoutFailedToCreate,
    };

    pub const BindingType = enum {
        buffer,
        sampler,
        texture,
        storage_texture,
    };

    pub const BindingInfo = union(BindingType) {
        buffer: struct {
            type: gpu.Buffer.BindingType,
            has_dynamic_offset: bool,
            min_binding_size: u64,
        },
        sampler: struct {
            type: gpu.Sampler.BindingType,
        },
        texture: struct {
            sample_type: gpu.Texture.SampleType,
            view_dimension: gpu.TextureView.Dimension,
            multisampled: bool,
        },
        storage_texture: struct {
            access: gpu.StorageTextureAccess,
            format: gpu.Texture.Format,
            view_dimension: gpu.TextureView.Dimension,
        },

        pub inline fn hasDynamicOffset(self: BindingInfo) bool {
            return switch (self) {
                .buffer => |buffer| buffer.has_dynamic_offset,
                else => false,
            };
        }
    };

    pub const Entry = struct {
        binding: u32,
        visibility: gpu.ShaderStageFlags,
        type: BindingInfo,
        count: ?u32 = null,

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
                .type = .{
                    .buffer = .{
                        .type = binding_type,
                        .has_dynamic_offset = has_dynamic_offset,
                        .min_binding_size = min_binding_size,
                    },
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
                .type = .{
                    .sampler = .{
                        .type = binding_type,
                    },
                },
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
                .type = .{
                    .texture = .{
                        .sample_type = sample_type,
                        .view_dimension = view_dimension,
                        .multisampled = multisampled,
                    },
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
                .type = .{
                    .storage_texture = .{
                        .access = access,
                        .format = format,
                        .view_dimension = view_dimension,
                    },
                },
            };
        }
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        entries: []const Entry = &.{},
    };

    pub inline fn destroy(self: *BindGroupLayout) void {
        return impl.bindGroupLayoutDestroy(self);
    }
};
