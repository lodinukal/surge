const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");

const Self = @This();

pub const UniformType = enum {
    undefined,
    float1,
    float2,
    float3,
    float4,
    double1,
    double2,
    double3,
    double4,
    int1,
    int2,
    int3,
    int4,
    uint1,
    uint2,
    uint3,
    uint4,
    bool1,
    bool2,
    bool3,
    bool4,

    float2x2,
    float2x3,
    float2x4,
    float3x2,
    float3x3,
    float3x4,
    float4x2,
    float4x3,
    float4x4,
    double2x2,
    double2x3,
    double2x4,
    double3x2,
    double3x3,
    double3x4,
    double4x2,
    double4x3,
    double4x4,

    sampler,
    image,
    atomic,
};

pub const BindingSlot = struct {
    index: u32 = 0,
    set: u32 = 0,

    pub fn eql(self: BindingSlot, other: BindingSlot) bool {
        return self.index == other.index and self.set == other.set;
    }
};

pub const BindingDescriptor = struct {
    allocator: ?std.mem.Allocator = null,
    name: ?[]const u8 = null,
    resource_type: Renderer.Resource.ResourceType,
    binding: Renderer.Resource.BindingInfo = .{},
    stages: Renderer.Shader.ShaderStages = .{},
    slot: BindingSlot = .{},
    array_size: u32 = 0,

    pub fn deinit(self: *BindingDescriptor) void {
        if (self.name) |n| {
            self.allocator.?.free(n);
        }
    }
};

pub const StaticSamplerDescriptor = struct {
    allocator: ?std.mem.Allocator = null,
    name: ?[]const u8 = null,
    stages: Renderer.Shader.ShaderStages = .{},
    slot: BindingSlot = .{},
    sampler: Renderer.Sampler.SamplerDescriptor = .{},

    pub fn deinit(self: *BindingDescriptor) void {
        if (self.name) |n| {
            self.allocator.?.free(n);
        }
    }
};

pub const UniformDescriptor = struct {
    allocator: ?std.mem.Allocator = null,
    name: ?[]const u8 = null,
    uniform_type: UniformType = .undefined,
    array_size: u32 = 0,
};

pub const PipelineLayoutDescriptor = struct {
    heap_bindings: []const BindingDescriptor,
    bindings: []const BindingDescriptor,
    static_samplers: []const StaticSamplerDescriptor,
    uniforms: []const UniformDescriptor,
};
