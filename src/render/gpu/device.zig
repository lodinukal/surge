const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Device = opaque {
    pub const Error = error{
        DeviceFailedToCreate,
    };

    pub const LostReason = enum {
        undefined,
        destroyed,
    };

    pub const LostCallback = *const fn (
        reason: LostReason,
        message: []const u8,
    ) void;

    pub const Descriptor = struct {
        label: []const u8,
        lost_callback: ?LostCallback = null,
    };

    pub inline fn getQueue(self: *Device) *gpu.Queue {
        return impl.deviceGetQueue(self);
    }

    pub inline fn createBindGroup(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.BindGroup.Descriptor,
    ) !*gpu.BindGroup {
        return try impl.deviceCreateBindGroup(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createBindGroupLayout(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.BindGroupLayout.Descriptor,
    ) !*gpu.BindGroupLayout {
        return try impl.deviceCreateBindGroupLayout(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createPipelineLayout(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.PipelineLayout.Descriptor,
    ) !*gpu.PipelineLayout {
        return try impl.deviceCreatePipelineLayout(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createRenderPipeline(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.RenderPipeline.Descriptor,
    ) !*gpu.RenderPipeline {
        return try impl.deviceCreateRenderPipeline(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createBuffer(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.Buffer.Descriptor,
    ) !*gpu.Buffer {
        return try impl.deviceCreateBuffer(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createCommandEncoder(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.CommandEncoder.Descriptor,
    ) !*gpu.CommandEncoder {
        return try impl.deviceCreateCommandEncoder(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createSampler(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.Sampler.Descriptor,
    ) !*gpu.Sampler {
        return try impl.deviceCreateSampler(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createShaderModule(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.ShaderModule.Descriptor,
    ) !*gpu.ShaderModule {
        return try impl.deviceCreateShaderModule(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn createSwapChain(
        self: *Device,
        allocator: std.mem.Allocator,
        surface: ?*gpu.Surface,
        descriptor: *const gpu.SwapChain.Descriptor,
    ) !*gpu.SwapChain {
        return try impl.deviceCreateSwapChain(
            self,
            allocator,
            surface,
            descriptor,
        );
    }

    pub inline fn createTexture(
        self: *Device,
        allocator: std.mem.Allocator,
        descriptor: *const gpu.Texture.Descriptor,
    ) !*gpu.Texture {
        return try impl.deviceCreateTexture(
            self,
            allocator,
            descriptor,
        );
    }

    pub inline fn destroy(self: *Device) void {
        impl.deviceDestroy(self);
    }
};
