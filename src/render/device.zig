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

    pub inline fn createBindGroup(self: *Device, descriptor: *const gpu.BindGroup.Descriptor) !*gpu.BindGroup {
        return try impl.deviceCreateBindGroup(self, descriptor);
    }

    pub inline fn createBindGroupLayout(self: *Device, descriptor: *const gpu.BindGroupLayout.Descriptor) !*gpu.BindGroupLayout {
        return try impl.deviceCreateBindGroupLayout(self, descriptor);
    }

    pub inline fn createPipelineLayout(self: *Device, descriptor: *const gpu.PipelineLayout.Descriptor) !*gpu.PipelineLayout {
        return try impl.deviceCreatePipelineLayout(self, descriptor);
    }

    pub inline fn createRenderPipeline(self: *Device, descriptor: *const gpu.RenderPipeline.Descriptor) !*gpu.RenderPipeline {
        return try impl.deviceCreateRenderPipeline(self, descriptor);
    }

    pub inline fn createBuffer(self: *Device, descriptor: *const gpu.Buffer.Descriptor) !*gpu.Buffer {
        return try impl.deviceCreateBuffer(self, descriptor);
    }

    pub inline fn createCommandEncoder(self: *Device, descriptor: *const gpu.CommandEncoder.Descriptor) !*gpu.CommandEncoder {
        return try impl.deviceCreateCommandEncoder(self, descriptor);
    }

    pub inline fn createSampler(self: *Device, descriptor: *const gpu.Sampler.Descriptor) !*gpu.Sampler {
        return try impl.deviceCreateSampler(self, descriptor);
    }

    pub inline fn createShaderModule(self: *Device, descriptor: *const gpu.ShaderModule.Descriptor) !*gpu.ShaderModule {
        return try impl.deviceCreateShaderModule(self, descriptor);
    }

    pub inline fn createSwapChain(self: *Device, surface: ?*gpu.Surface, descriptor: *const gpu.SwapChain.Descriptor) !*gpu.SwapChain {
        return try impl.deviceCreateSwapChain(self, surface, descriptor);
    }

    pub inline fn createTexture(self: *Device, descriptor: *const gpu.Texture.Descriptor) !*gpu.Texture {
        return try impl.deviceCreateTexture(self, descriptor);
    }

    pub inline fn destroy(self: *Device) void {
        impl.deviceDestroy(self);
    }
};
