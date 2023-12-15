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
    commandEncoderBeginRenderPass: *const fn (
        command_encoder: *gpu.CommandEncoder,
        allocator: std.mem.Allocator,
        desc: *const gpu.RenderPass.Descriptor,
    ) gpu.RenderPass.Encoder.Error!*gpu.RenderPass.Encoder,
    commandEncoderFinish: *const fn (
        command_encoder: *gpu.CommandEncoder,
        desc: *const gpu.CommandBuffer.Descriptor,
    ) gpu.CommandBuffer.Error!*gpu.CommandBuffer,
    commandEncoderDestroy: *const fn (command_encoder: *gpu.CommandEncoder) void,
    // ComputePassEncoder
    // ComputePipeline
    // Device
    deviceCreateBindGroup: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.BindGroup.Descriptor) gpu.BindGroup.Error!*gpu.BindGroup,
    deviceCreateBindGroupLayout: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.BindGroupLayout.Descriptor) gpu.BindGroupLayout.Error!*gpu.BindGroupLayout,
    deviceCreatePipelineLayout: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.PipelineLayout.Descriptor) gpu.PipelineLayout.Error!*gpu.PipelineLayout,
    deviceCreateRenderPipeline: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.RenderPipeline.Descriptor) gpu.RenderPipeline.Error!*gpu.RenderPipeline,
    deviceCreateBuffer: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer,
    deviceCreateCommandEncoder: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.CommandEncoder.Descriptor) gpu.CommandEncoder.Error!*gpu.CommandEncoder,
    deviceCreateSampler: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.Sampler.Descriptor) gpu.Sampler.Error!*gpu.Sampler,
    deviceCreateShaderModule: *const fn (device: *gpu.Device, allocator: std.mem.Allocator, desc: *const gpu.ShaderModule.Descriptor) gpu.ShaderModule.Error!*gpu.ShaderModule,
    deviceCreateSwapChain: *const fn (
        device: *gpu.Device,
        allocator: std.mem.Allocator,
        surface: ?*gpu.Surface,
        desc: *const gpu.SwapChain.Descriptor,
    ) gpu.SwapChain.Error!*gpu.SwapChain,
    deviceCreateTexture: *const fn (
        device: *gpu.Device,
        allocator: std.mem.Allocator,
        desc: *const gpu.Texture.Descriptor,
    ) gpu.Texture.Error!*gpu.Texture,
    deviceGetQueue: *const fn (device: *gpu.Device) *gpu.Queue,
    deviceDestroy: *const fn (device: *gpu.Device) void,
    // Instance
    createInstance: *const fn (allocator: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance,
    instanceCreateSurface: *const fn (instance: *gpu.Instance, allocator: std.mem.Allocator, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface,
    instanceRequestPhysicalDevice: *const fn (instance: *gpu.Instance, allocator: std.mem.Allocator, options: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice,
    instanceDestroy: *const fn (instance: *gpu.Instance) void,
    // PhysicalDevice
    physicalDeviceCreateDevice: *const fn (physicalDevice: *gpu.PhysicalDevice, allocator: std.mem.Allocator, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device,
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
    queueWriteBuffer: *const fn (
        queue: *gpu.Queue,
        buffer: *gpu.Buffer,
        buffer_offset: u64,
        data: []const u8,
    ) gpu.Queue.Error!void,
    queueWriteTexture: *const fn (
        queue: *gpu.Queue,
        destination: *gpu.ImageCopyTexture,
        data: []const u8,
        data_layout: *const gpu.Texture.DataLayout,
        size: *const gpu.Extent3D,
    ) gpu.Queue.Error!void,
    queueWaitIdle: *const fn (queue: *gpu.Queue) gpu.Queue.Error!void,
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
    renderPassEncoderSetIndexBuffer: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        buffer: *gpu.Buffer,
        format: gpu.IndexFormat,
        offset: u64,
        size: u64,
    ) gpu.RenderPass.Encoder.Error!void,
    renderPassEncoderSetPipeline: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        pipeline: *gpu.RenderPipeline,
    ) gpu.RenderPass.Encoder.Error!void,
    renderPassEncoderSetScissorRect: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) gpu.RenderPass.Encoder.Error!void,
    renderPassEncoderSetStencilReference: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        reference: u32,
    ) void,
    renderPassEncoderSetVertexBuffer: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        slot: u32,
        buffer: *gpu.Buffer,
        offset: u64,
        size: u64,
    ) gpu.RenderPass.Encoder.Error!void,
    renderPassEncoderSetViewport: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        minDepth: f32,
        maxDepth: f32,
    ) gpu.RenderPass.Encoder.Error!void,
    renderPassEncoderWriteTimestamp: *const fn (
        renderPassEncoder: *gpu.RenderPass.Encoder,
        querySet: *gpu.QuerySet,
        queryIndex: u32,
    ) void,
    renderPassEncoderDestroy: *const fn (renderPassEncoder: *gpu.RenderPass.Encoder) void,
    // RenderPipeline
    renderPipelineDestroy: *const fn (renderPipeline: *gpu.RenderPipeline) void,
    // Sampler
    samplerDestroy: *const fn (sampler: *gpu.Sampler) void,
    // ShaderModule
    shaderModuleDestroy: *const fn (shaderModule: *gpu.ShaderModule) void,
    // Surface
    surfaceDestroy: *const fn (surface: *gpu.Surface) void,
    // SwapChain
    swapChainGetIndex: *const fn (swapchain: *gpu.SwapChain) u32,
    swapChainGetCurrentTexture: *const fn (swapchain: *gpu.SwapChain) ?*const gpu.Texture,
    swapChainGetCurrentTextureView: *const fn (swapchain: *gpu.SwapChain) ?*const gpu.TextureView,
    swapChainGetTextureViews: *const fn (swapchain: *gpu.SwapChain, views: *[3]?*const gpu.TextureView) u32,
    swapChainPresent: *const fn (swapchain: *gpu.SwapChain) gpu.SwapChain.Error!void,
    swapChainResize: *const fn (swapchain: *gpu.SwapChain, size: [2]u32) gpu.SwapChain.Error!bool,
    swapChainDestroy: *const fn (swapchain: *gpu.SwapChain) void,
    // Texture
    textureCreateView: *const fn (texture: *gpu.Texture, allocator: std.mem.Allocator, descriptor: *const gpu.TextureView.Descriptor) gpu.TextureView.Error!*gpu.TextureView,
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
