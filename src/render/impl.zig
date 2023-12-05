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

// Heap
pub inline fn heapGetDescriptor(heap: *gpu.Heap) *const gpu.Heap.Descriptor {
    return procs.Procs.loaded_procs.?.heapGetDescriptor(heap);
}

pub inline fn heapDestroy(heap: *gpu.Heap) void {
    return procs.Procs.loaded_procs.?.heapDestroy(heap);
}

// Texture
pub inline fn textureGetDescriptor(texture: *gpu.Texture) *const gpu.Texture.Descriptor {
    return procs.Procs.loaded_procs.?.textureGetDescriptor(texture);
}

pub inline fn textureDestroy(texture: *gpu.Texture) void {
    return procs.Procs.loaded_procs.?.textureDestroy(texture);
}

// StagingTexture
pub inline fn stagingTextureGetDescriptor(stagingTexture: *gpu.StagingTexture) *const gpu.Texture.Descriptor {
    return procs.Procs.loaded_procs.?.stagingTextureGetDescriptor(stagingTexture);
}

pub inline fn stagingTextureDestroy(stagingTexture: *gpu.StagingTexture) void {
    return procs.Procs.loaded_procs.?.stagingTextureDestroy(stagingTexture);
}

// InputLayout
pub inline fn inputLayoutGetAttributes(inputLayout: *gpu.InputLayout) []const gpu.VertexAttributeDescriptor {
    return procs.Procs.loaded_procs.?.inputLayoutGetAttributes(inputLayout);
}

pub inline fn inputLayoutDestroy(inputLayout: *gpu.InputLayout) void {
    return procs.Procs.loaded_procs.?.inputLayoutDestroy(inputLayout);
}

// Buffer
pub inline fn bufferGetDescriptor(buffer: *gpu.Buffer) *const gpu.Buffer.Descriptor {
    return procs.Procs.loaded_procs.?.bufferGetDescriptor(buffer);
}

pub inline fn bufferDestroy(buffer: *gpu.Buffer) void {
    return procs.Procs.loaded_procs.?.bufferDestroy(buffer);
}

// Shader
pub inline fn shaderGetDescriptor(shader: *const gpu.Shader) *const gpu.Shader.Descriptor {
    return procs.Procs.loaded_procs.?.shaderGetDescriptor(shader);
}

pub inline fn shaderGetBytecode(shader: *const gpu.Shader) *[]const u8 {
    return procs.Procs.loaded_procs.?.shaderGetBytecode(shader);
}

pub inline fn shaderDestroy(shader: *gpu.Shader) void {
    return procs.Procs.loaded_procs.?.shaderDestroy(shader);
}

// ShaderLibrary
pub inline fn shaderLibraryGetBytecode(shaderLibrary: *const gpu.ShaderLibrary) *[]const u8 {
    return procs.Procs.loaded_procs.?.shaderLibraryGetBytecode(shaderLibrary);
}

pub inline fn shaderLibraryGetShader(shaderLibrary: *const gpu.ShaderLibrary, name: []const u8, ty: gpu.Shader.Type) ?*gpu.Shader {
    return procs.Procs.loaded_procs.?.shaderLibraryGetShader(shaderLibrary, name, ty);
}

pub inline fn shaderLibraryDestroy(shaderLibrary: *gpu.ShaderLibrary) void {
    return procs.Procs.loaded_procs.?.shaderLibraryDestroy(shaderLibrary);
}

// Sampler
pub inline fn samplerGetDescriptor(sampler: *const gpu.Sampler) *const gpu.Sampler.Descriptor {
    return procs.Procs.loaded_procs.?.samplerGetDescriptor(sampler);
}

pub inline fn samplerDestroy(sampler: *gpu.Sampler) void {
    return procs.Procs.loaded_procs.?.samplerDestroy(sampler);
}

// Framebuffer
pub inline fn framebufferGetDescriptor(framebuffer: *const gpu.Framebuffer) *const gpu.Framebuffer.Descriptor {
    return procs.Procs.loaded_procs.?.framebufferGetDescriptor(framebuffer);
}

pub inline fn framebufferGetFramebufferInfo(framebuffer: *const gpu.Framebuffer) *const gpu.Framebuffer.Info {
    return procs.Procs.loaded_procs.?.framebufferGetFramebufferInfo(framebuffer);
}

pub inline fn framebufferDestroy(framebuffer: *gpu.Framebuffer) void {
    return procs.Procs.loaded_procs.?.framebufferDestroy(framebuffer);
}

// BindingLayout
pub inline fn bindingLayoutGetDescriptor(bindingLayout: *const gpu.BindingLayout) ?*const gpu.BindingLayout.Descriptor {
    return procs.Procs.loaded_procs.?.bindingLayoutGetDescriptor(bindingLayout);
}

pub inline fn bindingLayoutGetBindlessDescriptor(bindingLayout: *const gpu.BindingLayout) ?*const gpu.BindingLayout.BindlessDescriptor {
    return procs.Procs.loaded_procs.?.bindingLayoutGetBindlessDescriptor(bindingLayout);
}

pub inline fn bindingLayoutDestroy(bindingLayout: *gpu.BindingLayout) void {
    return procs.Procs.loaded_procs.?.bindingLayoutDestroy(bindingLayout);
}

// BindingSet
pub inline fn bindingSetGetDescriptor(bindingSet: *const gpu.BindingSet) *const gpu.BindingSet.Descriptor {
    return procs.Procs.loaded_procs.?.bindingSetGetDescriptor(bindingSet);
}

pub inline fn bindingSetGetLayout(bindingSet: *const gpu.BindingSet) *gpu.BindingLayout {
    return procs.Procs.loaded_procs.?.bindingSetGetLayout(bindingSet);
}

pub inline fn bindingSetDestroy(bindingSet: *gpu.BindingSet) void {
    return procs.Procs.loaded_procs.?.bindingSetDestroy(bindingSet);
}

// DescriptorTable
pub inline fn descriptorTableGetDescriptor(descriptorTable: *const gpu.DescriptorTable) *const gpu.BindingSet.Descriptor {
    return procs.Procs.loaded_procs.?.descriptorTableGetDescriptor(descriptorTable);
}

pub inline fn descriptorTableGetLayout(descriptorTable: *const gpu.DescriptorTable) *gpu.BindingLayout {
    return procs.Procs.loaded_procs.?.descriptorTableGetLayout(descriptorTable);
}

pub inline fn descriptorTableGetCapacity(descriptorTable: *const gpu.DescriptorTable) u32 {
    return procs.Procs.loaded_procs.?.descriptorTableGetCapacity(descriptorTable);
}

pub inline fn descriptorTableDestroy(descriptorTable: *gpu.DescriptorTable) void {
    return procs.Procs.loaded_procs.?.descriptorTableDestroy(descriptorTable);
}

// GraphicsPipeline
pub inline fn graphicsPipelineGetDescriptor(graphicsPipeline: *const gpu.GraphicsPipeline) *const gpu.GraphicsPipeline.Descriptor {
    return procs.Procs.loaded_procs.?.graphicsPipelineGetDescriptor(graphicsPipeline);
}

pub inline fn graphicsPipelineGetFramebufferInfo(graphicsPipeline: *const gpu.GraphicsPipeline) *const gpu.Framebuffer.Info {
    return procs.Procs.loaded_procs.?.graphicsPipelineGetFramebufferInfo(graphicsPipeline);
}

pub inline fn graphicsPipelineDestroy(graphicsPipeline: *gpu.GraphicsPipeline) void {
    return procs.Procs.loaded_procs.?.graphicsPipelineDestroy(graphicsPipeline);
}

// MeshletPipeline
pub inline fn meshletPipelineGetDescriptor(meshletPipeline: *const gpu.MeshletPipeline) *const gpu.MeshletPipeline.Descriptor {
    return procs.Procs.loaded_procs.?.meshletPipelineGetDescriptor(meshletPipeline);
}

pub inline fn meshletPipelineGetFramebufferInfo(meshletPipeline: *const gpu.MeshletPipeline) *const gpu.Framebuffer.Info {
    return procs.Procs.loaded_procs.?.meshletPipelineGetFramebufferInfo(meshletPipeline);
}

pub inline fn meshletPipelineDestroy(meshletPipeline: *gpu.MeshletPipeline) void {
    return procs.Procs.loaded_procs.?.meshletPipelineDestroy(meshletPipeline);
}

// EventQuery
pub inline fn eventQueryDestroy(eventQuery: *gpu.EventQuery) void {
    return procs.Procs.loaded_procs.?.eventQueryDestroy(eventQuery);
}

// TimerQuery
pub inline fn timerQueryDestroy(timerQuery: *gpu.TimerQuery) void {
    return procs.Procs.loaded_procs.?.timerQueryDestroy(timerQuery);
}

// ComputePipeline
pub inline fn computePipelineGetDescriptor(computePipeline: *const gpu.ComputePipeline) *const gpu.ComputePipeline.Descriptor {
    return procs.Procs.loaded_procs.?.computePipelineGetDescriptor(computePipeline);
}

pub inline fn computePipelineDestroy(computePipeline: *gpu.ComputePipeline) void {
    return procs.Procs.loaded_procs.?.computePipelineDestroy(computePipeline);
}

// Device
pub inline fn deviceCreateSwapChain(
    device: *gpu.Device,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    return procs.Procs.loaded_procs.?.deviceCreateSwapChain(device, surface, desc);
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

// Surface
pub inline fn surfaceDestroy(surface: *gpu.Surface) void {
    return procs.Procs.loaded_procs.?.surfaceDestroy(surface);
}

// SwapChain
pub inline fn swapChainPresent(swap_chain: *gpu.SwapChain) gpu.SwapChain.Error!void {
    return procs.Procs.loaded_procs.?.swapChainPresent(swap_chain);
}

pub inline fn swapChainResize(swap_chain: *gpu.SwapChain, size: [2]u32) gpu.SwapChain.Error!void {
    return procs.Procs.loaded_procs.?.swapChainResize(swap_chain, size);
}

pub inline fn swapChainDestroy(swap_chain: *gpu.SwapChain) void {
    return procs.Procs.loaded_procs.?.swapChainDestroy(swap_chain);
}
