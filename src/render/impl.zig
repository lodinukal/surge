const std = @import("std");
const gpu = @import("gpu.zig");
const procs = @import("procs.zig");

var dynamic_lib: ?std.DynLib = null;
pub fn loadBackend(backend: gpu.BackendType) bool {
    switch (backend) {
        .undefined => return false,
        .null => return false,
        .webgpu => return false,
        .d3d11 => {
            dynamic_lib = std.DynLib.open("render_d3d11") catch return false;
            if (dynamic_lib == null) return false;
            const getter = dynamic_lib.?.lookup(procs.ProcFn, "getProcs") orelse return false;
            procs.Procs.loaded_procs = getter() orelse return false;
            return true;
        },
        .d3d12 => {
            dynamic_lib = std.DynLib.open("render_d3d12") catch return false;
            if (dynamic_lib == null) return false;
            const getter = dynamic_lib.?.lookup(procs.ProcFn, "getProcs") orelse return false;
            procs.Procs.loaded_procs = getter() orelse return false;
            return true;
        },
        .metal => return false,
        .vulkan => return false,
        .opengl => return false,
        .opengles => return false,
    }
}

pub fn closeBackend() void {
    if (dynamic_lib) |dl| {
        dl.close();
        dynamic_lib = null;
    }
}

// BindGroup
pub inline fn bindGroupDestroy(bind_group: *gpu.BindGroup) void {
    return procs.Procs.loaded_procs.?.bindGroupDestroy(bind_group);
}

// BindGroupLayout
pub inline fn bindGroupLayoutDestroy(bind_group_layout: *gpu.BindGroupLayout) void {
    return procs.Procs.loaded_procs.?.bindGroupLayoutDestroy(bind_group_layout);
}

// Buffer
pub inline fn bufferGetSize(buffer: *gpu.Buffer) u64 {
    return procs.Procs.loaded_procs.?.bufferGetSize(buffer);
}

pub inline fn bufferGetUsage(buffer: *gpu.Buffer) gpu.Buffer.Usage {
    return procs.Procs.loaded_procs.?.bufferGetUsage(buffer);
}

pub inline fn bufferMap(buffer: *gpu.Buffer) gpu.Buffer.Error!void {
    return procs.Procs.loaded_procs.?.bufferMap(buffer);
}

pub inline fn bufferUnmap(buffer: *gpu.Buffer) void {
    return procs.Procs.loaded_procs.?.bufferUnmap(buffer);
}

pub inline fn bufferGetMappedRange(buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]u8 {
    return procs.Procs.loaded_procs.?.bufferGetMappedRange(buffer, offset, size);
}

pub inline fn bufferGetMappedRangeConst(buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]u8 {
    return procs.Procs.loaded_procs.?.bufferGetMappedRangeConst(buffer, offset, size);
}

pub inline fn bufferDestroy(buffer: *gpu.Buffer) void {
    return procs.Procs.loaded_procs.?.bufferDestroy(buffer);
}

// CommandBuffer
pub inline fn commandBufferDestroy(command_buffer: *gpu.CommandBuffer) void {
    return procs.Procs.loaded_procs.?.commandBufferDestroy(command_buffer);
}

// CommandEncoder
pub inline fn commandEncoderBeginRenderPass(
    command_encoder: *gpu.CommandEncoder,
    desc: *const gpu.RenderPass.Descriptor,
) gpu.RenderPass.Encoder.Error!*gpu.RenderPass.Encoder {
    return procs.Procs.loaded_procs.?.commandEncoderBeginRenderPass(command_encoder, desc);
}

pub inline fn commandEncoderFinish(
    command_encoder: *gpu.CommandEncoder,
    desc: ?*const gpu.CommandBuffer.Descriptor,
) gpu.CommandBuffer.Error!*gpu.CommandBuffer {
    return procs.Procs.loaded_procs.?.commandEncoderFinish(command_encoder, desc orelse &.{});
}

pub inline fn commandEncoderDestroy(command_encoder: *gpu.CommandEncoder) void {
    return procs.Procs.loaded_procs.?.commandEncoderDestroy(command_encoder);
}

// Device
pub inline fn deviceCreateBindGroup(device: *gpu.Device, desc: *const gpu.BindGroup.Descriptor) gpu.BindGroup.Error!*gpu.BindGroup {
    return procs.Procs.loaded_procs.?.deviceCreateBindGroup(device, desc);
}

pub inline fn deviceCreateBindGroupLayout(device: *gpu.Device, desc: *const gpu.BindGroupLayout.Descriptor) gpu.BindGroupLayout.Error!*gpu.BindGroupLayout {
    return procs.Procs.loaded_procs.?.deviceCreateBindGroupLayout(device, desc);
}

pub inline fn deviceCreatePipelineLayout(device: *gpu.Device, desc: *const gpu.PipelineLayout.Descriptor) gpu.PipelineLayout.Error!*gpu.PipelineLayout {
    return procs.Procs.loaded_procs.?.deviceCreatePipelineLayout(device, desc);
}

pub inline fn deviceCreateRenderPipeline(device: *gpu.Device, desc: *const gpu.RenderPipeline.Descriptor) gpu.RenderPipeline.Error!*gpu.RenderPipeline {
    return procs.Procs.loaded_procs.?.deviceCreateRenderPipeline(device, desc);
}

pub inline fn deviceCreateBuffer(device: *gpu.Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer {
    return procs.Procs.loaded_procs.?.deviceCreateBuffer(device, desc);
}

pub inline fn deviceCreateCommandEncoder(device: *gpu.Device, desc: *const gpu.CommandEncoder.Descriptor) gpu.CommandEncoder.Error!*gpu.CommandEncoder {
    return procs.Procs.loaded_procs.?.deviceCreateCommandEncoder(device, desc);
}

pub inline fn deviceCreateSampler(device: *gpu.Device, desc: *const gpu.Sampler.Descriptor) gpu.Sampler.Error!*gpu.Sampler {
    return procs.Procs.loaded_procs.?.deviceCreateSampler(device, desc);
}

pub inline fn deviceCreateShaderModule(device: *gpu.Device, desc: *const gpu.ShaderModule.Descriptor) gpu.ShaderModule.Error!*gpu.ShaderModule {
    return procs.Procs.loaded_procs.?.deviceCreateShaderModule(device, desc);
}

pub inline fn deviceCreateSwapChain(
    device: *gpu.Device,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    return procs.Procs.loaded_procs.?.deviceCreateSwapChain(device, surface, desc);
}

pub inline fn deviceCreateTexture(
    device: *gpu.Device,
    desc: *const gpu.Texture.Descriptor,
) gpu.Texture.Error!*gpu.Texture {
    return procs.Procs.loaded_procs.?.deviceCreateTexture(device, desc);
}

pub inline fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
    return procs.Procs.loaded_procs.?.deviceGetQueue(device);
}

pub inline fn deviceDestroy(device: *gpu.Device) void {
    return procs.Procs.loaded_procs.?.deviceDestroy(device);
}

// Instance
pub inline fn createInstance(
    allocator: std.mem.Allocator,
    desc: *const gpu.Instance.Descriptor,
) gpu.Instance.Error!*gpu.Instance {
    return procs.Procs.loaded_procs.?.createInstance(allocator, desc);
}

pub inline fn instanceCreateSurface(
    instance: *gpu.Instance,
    desc: *const gpu.Surface.Descriptor,
) gpu.Surface.Error!*gpu.Surface {
    return procs.Procs.loaded_procs.?.instanceCreateSurface(instance, desc);
}

pub inline fn instanceRequestPhysicalDevice(
    instance: *gpu.Instance,
    options: *const gpu.PhysicalDevice.Options,
) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
    return procs.Procs.loaded_procs.?.instanceRequestPhysicalDevice(instance, options);
}

pub inline fn instanceDestroy(instance: *gpu.Instance) void {
    return procs.Procs.loaded_procs.?.instanceDestroy(instance);
}

// PhysicalDevice
pub inline fn physicalDeviceCreateDevice(physicalDevice: *gpu.PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device {
    return procs.Procs.loaded_procs.?.physicalDeviceCreateDevice(physicalDevice, desc);
}

pub inline fn physicalDeviceGetProperties(physicalDevice: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
    return procs.Procs.loaded_procs.?.physicalDeviceGetProperties(physicalDevice, out_props);
}

pub inline fn physicalDeviceDestroy(physicalDevice: *gpu.PhysicalDevice) void {
    return procs.Procs.loaded_procs.?.physicalDeviceDestroy(physicalDevice);
}

// PipelineLayout
pub inline fn pipelineLayoutDestroy(pipeline_layout: *gpu.PipelineLayout) void {
    return procs.Procs.loaded_procs.?.pipelineLayoutDestroy(pipeline_layout);
}

// Queue
pub inline fn queueSubmit(
    queue: *gpu.Queue,
    command_buffers: []const *gpu.CommandBuffer,
) gpu.Queue.Error!void {
    return procs.Procs.loaded_procs.?.queueSubmit(queue, command_buffers);
}

pub inline fn queueWriteBuffer(
    queue: *gpu.Queue,
    buffer: *gpu.Buffer,
    buffer_offset: u64,
    comptime T: type,
    data: []const T,
) gpu.Queue.Error!void {
    return procs.Procs.loaded_procs.?.queueWriteBuffer(
        queue,
        buffer,
        buffer_offset,
        std.mem.sliceAsBytes(data),
    );
}

pub inline fn queueWriteTexture(
    queue: *gpu.Queue,
    destination: *gpu.ImageCopyTexture,
    comptime T: type,
    data: []const T,
    data_layout: *const gpu.Texture.DataLayout,
    size: *const gpu.Extent3D,
) gpu.Queue.Error!void {
    return procs.Procs.loaded_procs.?.queueWriteTexture(
        queue,
        destination,
        std.mem.sliceAsBytes(data),
        data_layout,
        size,
    );
}

// RenderPassEncoder
pub inline fn renderPassEncoderDraw(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    vertex_count: u32,
    instance_count: ?u32,
    first_vertex: ?u32,
    first_instance: ?u32,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderDraw(
        render_pass_encoder,
        vertex_count,
        instance_count orelse 1,
        first_vertex orelse 0,
        first_instance orelse 0,
    );
}

pub inline fn renderPassEncoderDrawIndexed(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    index_count: usize,
    instance_count: ?u32,
    first_index: ?u32,
    base_vertex: ?i32,
    first_instance: ?u32,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderDrawIndexed(
        render_pass_encoder,
        @intCast(index_count),
        instance_count orelse 1,
        first_index orelse 0,
        base_vertex orelse 0,
        first_instance orelse 0,
    );
}

pub inline fn renderPassEncoderDrawIndexedIndirect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    indirect_buffer: *gpu.Buffer,
    indirect_offset: u64,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderDrawIndexedIndirect(
        render_pass_encoder,
        indirect_buffer,
        indirect_offset,
    );
}

pub inline fn renderPassEncoderDrawIndirect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    indirect_buffer: *gpu.Buffer,
    indirect_offset: u64,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderDrawIndirect(
        render_pass_encoder,
        indirect_buffer,
        indirect_offset,
    );
}

pub inline fn renderPassEncoderEnd(render_pass_encoder: *gpu.RenderPass.Encoder) !void {
    return procs.Procs.loaded_procs.?.renderPassEncoderEnd(render_pass_encoder);
}

pub inline fn renderPassEncoderExecuteBundles(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    bundles: []const *gpu.RenderBundle,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderExecuteBundles(render_pass_encoder, bundles);
}

pub inline fn renderPassEncoderInsertDebugMarker(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    label: []const u8,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderInsertDebugMarker(render_pass_encoder, label);
}

pub inline fn renderPassEncoderPopDebugGroup(render_pass_encoder: *gpu.RenderPass.Encoder) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderPopDebugGroup(render_pass_encoder);
}

pub inline fn renderPassEncoderPushDebugGroup(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    label: []const u8,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderPushDebugGroup(render_pass_encoder, label);
}

pub inline fn renderPassEncoderSetBindGroup(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    index: u32,
    bind_group: *gpu.BindGroup,
    dynamic_offsets: ?[]const u32,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderSetBindGroup(
        render_pass_encoder,
        index,
        bind_group,
        dynamic_offsets,
    );
}

pub inline fn renderPassEncoderSetBlendConstant(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    color: [4]f32,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderSetBlendConstant(
        render_pass_encoder,
        color,
    );
}

pub inline fn renderPassEncoderSetIndexBuffer(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    buffer: *gpu.Buffer,
    format: gpu.IndexFormat,
    offset: ?u64,
    size: ?u64,
) !void {
    try procs.Procs.loaded_procs.?.renderPassEncoderSetIndexBuffer(
        render_pass_encoder,
        buffer,
        format,
        offset orelse 0,
        size orelse gpu.whole_size,
    );
}

pub inline fn renderPassEncoderSetPipeline(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    pipeline: *gpu.RenderPipeline,
) !void {
    return procs.Procs.loaded_procs.?.renderPassEncoderSetPipeline(render_pass_encoder, pipeline);
}

pub inline fn renderPassEncoderSetScissorRect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) !void {
    try procs.Procs.loaded_procs.?.renderPassEncoderSetScissorRect(
        render_pass_encoder,
        x,
        y,
        width,
        height,
    );
}

pub inline fn renderPassEncoderSetStencilReference(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    reference: u32,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderSetStencilReference(render_pass_encoder, reference);
}

pub inline fn renderPassEncoderSetVertexBuffer(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    slot: u32,
    buffer: *gpu.Buffer,
    offset: ?u64,
    size: ?u64,
) !void {
    try procs.Procs.loaded_procs.?.renderPassEncoderSetVertexBuffer(
        render_pass_encoder,
        slot,
        buffer,
        offset orelse 0,
        size orelse gpu.whole_size,
    );
}

pub inline fn renderPassEncoderSetViewport(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
) !void {
    try procs.Procs.loaded_procs.?.renderPassEncoderSetViewport(
        render_pass_encoder,
        x,
        y,
        width,
        height,
        min_depth,
        max_depth,
    );
}

pub inline fn renderPassEncoderWriteTimestamp(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    query_set: *gpu.QuerySet,
    query_index: u32,
) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderWriteTimestamp(
        render_pass_encoder,
        query_set,
        query_index,
    );
}

pub inline fn renderPassEncoderDestroy(render_pass_encoder: *gpu.RenderPass.Encoder) void {
    return procs.Procs.loaded_procs.?.renderPassEncoderDestroy(render_pass_encoder);
}

// RenderPipeline
pub inline fn renderPipelineDestroy(render_pipeline: *gpu.RenderPipeline) void {
    return procs.Procs.loaded_procs.?.renderPipelineDestroy(render_pipeline);
}

// Sampler
pub inline fn samplerDestroy(sampler: *gpu.Sampler) void {
    return procs.Procs.loaded_procs.?.samplerDestroy(sampler);
}

// ShaderModule
pub inline fn shaderModuleDestroy(shader_module: *gpu.ShaderModule) void {
    return procs.Procs.loaded_procs.?.shaderModuleDestroy(shader_module);
}

// Surface
pub inline fn surfaceDestroy(surface: *gpu.Surface) void {
    return procs.Procs.loaded_procs.?.surfaceDestroy(surface);
}

// SwapChain
pub inline fn swapChainGetIndex(swap_chain: *gpu.SwapChain) u32 {
    return procs.Procs.loaded_procs.?.swapChainGetIndex(swap_chain);
}

pub inline fn swapChainGetCurrentTexture(swap_chain: *gpu.SwapChain) ?*const gpu.Texture {
    return procs.Procs.loaded_procs.?.swapChainGetCurrentTexture(swap_chain);
}

pub inline fn swapChainGetCurrentTextureView(swap_chain: *gpu.SwapChain) ?*const gpu.TextureView {
    return procs.Procs.loaded_procs.?.swapChainGetCurrentTextureView(swap_chain);
}

pub inline fn swapChainGetTextureViews(
    swap_chain: *gpu.SwapChain,
    out_texture_views: *[3]?*const gpu.TextureView,
) !u32 {
    return procs.Procs.loaded_procs.?.swapChainGetTextureViews(swap_chain, out_texture_views);
}

pub inline fn swapChainPresent(swap_chain: *gpu.SwapChain) gpu.SwapChain.Error!void {
    return procs.Procs.loaded_procs.?.swapChainPresent(swap_chain);
}

pub inline fn swapChainResize(swap_chain: *gpu.SwapChain, size: [2]u32) gpu.SwapChain.Error!void {
    return procs.Procs.loaded_procs.?.swapChainResize(swap_chain, size);
}

pub inline fn swapChainDestroy(swap_chain: *gpu.SwapChain) void {
    return procs.Procs.loaded_procs.?.swapChainDestroy(swap_chain);
}

// Texture
pub inline fn textureCreateView(texture: *gpu.Texture, descriptor: *const gpu.TextureView.Descriptor) gpu.TextureView.Error!*gpu.TextureView {
    return procs.Procs.loaded_procs.?.textureCreateView(texture, descriptor);
}

pub inline fn textureDestroy(texture: *gpu.Texture) void {
    procs.Procs.loaded_procs.?.textureDestroy(texture);
}

pub inline fn textureGetFormat(texture: *gpu.Texture) gpu.Texture.Format {
    return procs.Procs.loaded_procs.?.textureGetFormat(texture);
}

pub inline fn textureGetDepthOrArrayLayers(texture: *gpu.Texture) u32 {
    return procs.Procs.loaded_procs.?.textureGetDepthOrArrayLayers(texture);
}

pub inline fn textureGetDimension(texture: *gpu.Texture) gpu.Texture.Dimension {
    return procs.Procs.loaded_procs.?.textureGetDimension(texture);
}

pub inline fn textureGetHeight(texture: *gpu.Texture) u32 {
    return procs.Procs.loaded_procs.?.textureGetHeight(texture);
}

pub inline fn textureGetWidth(texture: *gpu.Texture) u32 {
    return procs.Procs.loaded_procs.?.textureGetWidth(texture);
}

pub inline fn textureGetMipLevelCount(texture: *gpu.Texture) u32 {
    return procs.Procs.loaded_procs.?.textureGetMipLevelCount(texture);
}

pub inline fn textureGetSampleCount(texture: *gpu.Texture) u32 {
    return procs.Procs.loaded_procs.?.textureGetSampleCount(texture);
}

pub inline fn textureGetUsage(texture: *gpu.Texture) gpu.Texture.UsageFlags {
    return procs.Procs.loaded_procs.?.textureGetUsage(texture);
}

// TextureView
pub inline fn textureViewDestroy(texture_view: *gpu.TextureView) void {
    return procs.Procs.loaded_procs.?.textureViewDestroy(texture_view);
}
