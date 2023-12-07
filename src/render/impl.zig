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
pub inline fn commandEncoderDestroy(command_encoder: *gpu.CommandEncoder) void {
    return procs.Procs.loaded_procs.?.commandEncoderDestroy(command_encoder);
}

// Device
pub inline fn deviceCreateBuffer(device: *gpu.Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer {
    return procs.Procs.loaded_procs.?.deviceCreateBuffer(device, desc);
}

pub inline fn deviceCreateSampler(device: *gpu.Device, desc: *const gpu.Sampler.Descriptor) gpu.Sampler.Error!*gpu.Sampler {
    return procs.Procs.loaded_procs.?.deviceCreateSampler(device, desc);
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

// Queue
pub inline fn queueSubmit(
    queue: *gpu.Queue,
    command_buffers: []const *gpu.CommandBuffer,
) gpu.Queue.Error!void {
    return procs.Procs.loaded_procs.?.queueSubmit(queue, command_buffers);
}

// Sampler
pub inline fn samplerDestroy(sampler: *gpu.Sampler) void {
    return procs.Procs.loaded_procs.?.samplerDestroy(sampler);
}

// Surface
pub inline fn surfaceDestroy(surface: *gpu.Surface) void {
    return procs.Procs.loaded_procs.?.surfaceDestroy(surface);
}

// SwapChain
pub inline fn swapChainGetCurrentTexture(swap_chain: *gpu.SwapChain) ?*gpu.Texture {
    return procs.Procs.loaded_procs.?.swapChainGetCurrentTexture(swap_chain);
}

pub inline fn swapChainGetCurrentTextureView(swap_chain: *gpu.SwapChain) ?*gpu.TextureView {
    return procs.Procs.loaded_procs.?.swapChainGetCurrentTextureView(swap_chain);
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
