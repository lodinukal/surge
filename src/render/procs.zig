const std = @import("std");
const gpu = @import("gpu.zig");

pub const ProcFn = *const fn () callconv(.C) ?*const Procs;
pub const Procs = struct {
    pub var loaded_procs: ?*const Procs = null;

    // BindGroup
    bindGroupDestroy: *const fn (bindGroup: *gpu.BindGroup) void,
    // BindGroupLayout
    bindGroupLayoutDestroy: *const fn (bindGroupLayout: *gpu.BindGroupLayout) void,
    // Buffer
    bufferGetSize: *const fn (buffer: *gpu.Buffer) u64,
    bufferGetUsage: *const fn (buffer: *gpu.Buffer) gpu.Buffer.UsageFlags,
    bufferMap: *const fn (buffer: *gpu.Buffer) gpu.Buffer.Error!void,
    bufferUnmap: *const fn (buffer: *gpu.Buffer) void,
    bufferGetMappedRange: *const fn (buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]u8,
    bufferGetMappedRangeConst: *const fn (buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]const u8,
    bufferDestroy: *const fn (buffer: *gpu.Buffer) void,
    // CommandBuffer
    commandBufferDestroy: *const fn (command_buffer: *gpu.CommandBuffer) void,
    // CommandEncoder
    commandEncoderFinish: *const fn (
        command_encoder: *gpu.CommandEncoder,
        desc: *const gpu.CommandBuffer.Descriptor,
    ) gpu.CommandBuffer.Error!*gpu.CommandBuffer,
    commandEncoderDestroy: *const fn (command_encoder: *gpu.CommandEncoder) void,
    // ComputePassEncoder
    // ComputePipeline
    // Device
    deviceCreateBindGroup: *const fn (device: *gpu.Device, desc: *const gpu.BindGroup.Descriptor) gpu.BindGroup.Error!*gpu.BindGroup,
    deviceCreateBindGroupLayout: *const fn (device: *gpu.Device, desc: *const gpu.BindGroupLayout.Descriptor) gpu.BindGroupLayout.Error!*gpu.BindGroupLayout,
    deviceCreatePipelineLayout: *const fn (device: *gpu.Device, desc: *const gpu.PipelineLayout.Descriptor) gpu.PipelineLayout.Error!*gpu.PipelineLayout,
    deviceCreateBuffer: *const fn (device: *gpu.Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer,
    deviceCreateCommandEncoder: *const fn (device: *gpu.Device, desc: *const gpu.CommandEncoder.Descriptor) gpu.CommandEncoder.Error!*gpu.CommandEncoder,
    deviceCreateSampler: *const fn (device: *gpu.Device, desc: *const gpu.Sampler.Descriptor) gpu.Sampler.Error!*gpu.Sampler,
    deviceCreateSwapChain: *const fn (
        device: *gpu.Device,
        surface: ?*gpu.Surface,
        desc: *const gpu.SwapChain.Descriptor,
    ) gpu.SwapChain.Error!*gpu.SwapChain,
    deviceCreateTexture: *const fn (device: *gpu.Device, desc: *const gpu.Texture.Descriptor) gpu.Texture.Error!*gpu.Texture,
    deviceGetQueue: *const fn (device: *gpu.Device) *gpu.Queue,
    deviceDestroy: *const fn (device: *gpu.Device) void,
    // Instance
    createInstance: *const fn (allocator: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance,
    instanceCreateSurface: *const fn (instance: *gpu.Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface,
    instanceRequestPhysicalDevice: *const fn (instance: *gpu.Instance, options: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice,
    instanceDestroy: *const fn (instance: *gpu.Instance) void,
    // PhysicalDevice
    physicalDeviceCreateDevice: *const fn (physicalDevice: *gpu.PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device,
    physicalDeviceGetProperties: *const fn (physicalDevice: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool,
    physicalDeviceDestroy: *const fn (physicalDevice: *gpu.PhysicalDevice) void,
    // PipelineLayout
    pipelineLayoutDestroy: *const fn (pipelineLayout: *gpu.PipelineLayout) void,
    // QuerySet
    // Queue
    queueSubmit: *const fn (
        queue: *gpu.Queue,
        command_buffers: []const *gpu.CommandBuffer,
    ) gpu.Queue.Error!void,
    // RenderBundle
    // RenderBundleEncoder
    // RenderPassEncoder
    renderPassEncoderDraw: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        vertexCount: u32,
        instanceCount: u32,
        firstVertex: u32,
        firstInstance: u32,
    ) void,
    renderPassEncoderDrawIndexed: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        indexCount: u32,
        instanceCount: u32,
        firstIndex: u32,
        baseVertex: i32,
        firstInstance: u32,
    ) void,
    renderPassEncoderDrawIndexedIndirect: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        indirectBuffer: *gpu.Buffer,
        indirectOffset: u64,
    ) void,
    renderPassEncoderDrawIndirect: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        indirectBuffer: *gpu.Buffer,
        indirectOffset: u64,
    ) void,
    renderPassEncoderEnd: *const fn (renderPassEncoder: *gpu.RenderPass.Encoder) gpu.RenderPass.Encoder.Error!void,
    renderPassEncoderExecuteBundles: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        bundles: []const *gpu.RenderBundle,
    ) void,
    renderPassEncoderInsertDebugMarker: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        label: []const u8,
    ) void,
    renderPassEncoderPopDebugGroup: *const fn (renderPassEncoder: *gpu.RenderPass.Encoder) void,
    renderPassEncoderPushDebugGroup: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        label: []const u8,
    ) void,
    renderPassEncoderSetBindGroup: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        index: u32,
        bindGroup: *gpu.BindGroup,
        dynamicOffsets: ?[]const u32,
    ) void,
    renderPassEncoderSetBlendConstant: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        color: [4]f32,
    ) void,
    renderPassEncoderSetIndexBuffer: *const fn () void,
    renderPassEncoderSetPipeline: *const fn () void,
    renderPassEncoderSetScissorRect: *const fn () void,
    renderPassEncoderSetStencilReference: *const fn () void,
    renderPassEncoderSetVertexBuffer: *const fn () void,
    renderPassEncoderSetViewport: *const fn () void,
    renderPassEncoderWriteTimestamp: *const fn () void,
    renderPassEncoderDestroy: *const fn (renderPassEncoder: *gpu.RenderPass.Encoder) void,
    // RenderPipeline
    // Sampler
    samplerDestroy: *const fn (sampler: *gpu.Sampler) void,
    // ShaderModule
    // Surface
    surfaceDestroy: *const fn (surface: *gpu.Surface) void,
    // SwapChain
    swapChainGetCurrentTexture: *const fn (swapchain: *gpu.SwapChain) ?*gpu.Texture,
    swapChainGetCurrentTextureView: *const fn (swapchain: *gpu.SwapChain) ?*gpu.TextureView,
    swapChainPresent: *const fn (swapchain: *gpu.SwapChain) gpu.SwapChain.Error!void,
    swapChainResize: *const fn (swapchain: *gpu.SwapChain, size: [2]u32) gpu.SwapChain.Error!void,
    swapChainDestroy: *const fn (swapchain: *gpu.SwapChain) void,
    // Texture
    textureCreateView: *const fn (texture: *gpu.Texture, descriptor: *const gpu.TextureView.Descriptor) gpu.TextureView.Error!*gpu.TextureView,
    textureDestroy: *const fn (texture: *gpu.Texture) void,
    textureGetFormat: *const fn (texture: *gpu.Texture) gpu.Texture.Format,
    textureGetDepthOrArrayLayers: *const fn (texture: *gpu.Texture) u32,
    textureGetDimension: *const fn (texture: *gpu.Texture) gpu.Texture.Dimension,
    textureGetHeight: *const fn (texture: *gpu.Texture) u32,
    textureGetWidth: *const fn (texture: *gpu.Texture) u32,
    textureGetMipLevelCount: *const fn (texture: *gpu.Texture) u32,
    textureGetSampleCount: *const fn (texture: *gpu.Texture) u32,
    textureGetUsage: *const fn (texture: *gpu.Texture) gpu.Texture.UsageFlags,
    // TextureView
    textureViewDestroy: *const fn (textureView: *gpu.TextureView) void,
};
