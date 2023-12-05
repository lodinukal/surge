const std = @import("std");
const gpu = @import("gpu.zig");

pub const ProcFn = *const fn () callconv(.C) ?*const Procs;
pub const Procs = struct {
    pub var loaded_procs: ?*const Procs = null;

    // Heap
    heapGetDescriptor: *const fn (heap: *gpu.Heap) *const gpu.Heap.Descriptor,
    heapDestroy: *const fn (heap: *gpu.Heap) void,

    // Texture
    textureGetDescriptor: *const fn (texture: *gpu.Texture) *const gpu.Texture.Descriptor,
    textureDestroy: *const fn (texture: *gpu.Texture) void,

    // StagingTexture
    stagingTextureGetDescriptor: *const fn (stagingTexture: *gpu.StagingTexture) *const gpu.Texture.Descriptor,
    stagingTextureDestroy: *const fn (stagingTexture: *gpu.StagingTexture) void,

    // InputLayout
    inputLayoutGetAttributes: *const fn (inputLayout: *gpu.InputLayout) []const gpu.VertexAttributeDescriptor,
    inputLayoutDestroy: *const fn (inputLayout: *gpu.InputLayout) void,

    // Buffer
    bufferGetDescriptor: *const fn (buffer: *gpu.Buffer) *const gpu.Buffer.Descriptor,
    bufferDestroy: *const fn (buffer: *gpu.Buffer) void,

    // Shader
    shaderGetDescriptor: *const fn (shader: *const gpu.Shader) *const gpu.Shader.Descriptor,
    shaderGetBytecode: *const fn (shader: *const gpu.Shader) *[]const u8,
    shaderDestroy: *const fn (shader: *gpu.Shader) void,

    // ShaderLibrary
    shaderLibraryGetBytecode: *const fn (shaderLibrary: *const gpu.ShaderLibrary) *[]const u8,
    shaderLibraryGetShader: *const fn (shaderLibrary: *const gpu.ShaderLibrary, name: []const u8, ty: gpu.Shader.Type) ?*gpu.Shader,
    shaderLibraryDestroy: *const fn (shaderLibrary: *gpu.ShaderLibrary) void,

    // Sampler
    samplerGetDescriptor: *const fn (sampler: *const gpu.Sampler) *const gpu.Sampler.Descriptor,
    samplerDestroy: *const fn (sampler: *gpu.Sampler) void,

    // Framebuffer
    framebufferGetDescriptor: *const fn (framebuffer: *const gpu.Framebuffer) *const gpu.Framebuffer.Descriptor,
    framebufferGetFramebufferInfo: *const fn (framebuffer: *const gpu.Framebuffer) *const gpu.Framebuffer.Info,
    framebufferDestroy: *const fn (framebuffer: *gpu.Framebuffer) void,

    // BindingLayout
    bindingLayoutGetDescriptor: *const fn (binding_layout: *const gpu.BindingLayout) ?*const gpu.BindingLayout.Descriptor,
    bindingLayoutGetBindlessDescriptor: *const fn (binding_layout: *const gpu.BindingLayout) ?*const gpu.BindingLayout.BindlessDescriptor,
    bindingLayoutDestroy: *const fn (binding_layout: *gpu.BindingLayout) void,

    // BindingSet
    bindingSetGetDescriptor: *const fn (binding_set: *const gpu.BindingSet) *const gpu.BindingSet.Descriptor,
    bindingSetGetLayout: *const fn (binding_set: *const gpu.BindingSet) *gpu.BindingLayout,
    bindingSetDestroy: *const fn (binding_set: *gpu.BindingSet) void,

    // DescriptorTable
    descriptorTableGetDescriptor: *const fn (descriptor_table: *const gpu.DescriptorTable) *const gpu.BindingSet.Descriptor,
    descriptorTableGetLayout: *const fn (descriptor_table: *const gpu.DescriptorTable) *gpu.BindingLayout,
    descriptorTableGetCapacity: *const fn (descriptor_table: *const gpu.DescriptorTable) u32,
    descriptorTableDestroy: *const fn (descriptor_table: *gpu.DescriptorTable) void,

    // GraphicsPipeline
    graphicsPipelineGetDescriptor: *const fn (graphics_pipeline: *const gpu.GraphicsPipeline) *const gpu.GraphicsPipeline.Descriptor,
    graphicsPipelineGetFramebufferInfo: *const fn (graphics_pipeline: *const gpu.GraphicsPipeline) *const gpu.Framebuffer.Info,
    graphicsPipelineDestroy: *const fn (graphics_pipeline: *gpu.GraphicsPipeline) void,

    // ComputePipeline
    computePipelineGetDescriptor: *const fn (compute_pipeline: *const gpu.ComputePipeline) *const gpu.ComputePipeline.Descriptor,
    computePipelineDestroy: *const fn (compute_pipeline: *gpu.ComputePipeline) void,

    // MeshletPipeline
    meshletPipelineGetDescriptor: *const fn (meshlet_pipeline: *const gpu.MeshletPipeline) *const gpu.MeshletPipeline.Descriptor,
    meshletPipelineGetFramebufferInfo: *const fn (meshlet_pipeline: *const gpu.MeshletPipeline) *const gpu.Framebuffer.Info,
    meshletPipelineDestroy: *const fn (meshlet_pipeline: *gpu.MeshletPipeline) void,

    // EventQuery
    eventQueryDestroy: *const fn (event_query: *gpu.EventQuery) void,

    // TimerQuery
    timerQueryDestroy: *const fn (timer_query: *gpu.TimerQuery) void,

    // Device
    deviceCreateSwapChain: *const fn (
        device: *gpu.Device,
        surface: ?*gpu.Surface,
        desc: *const gpu.SwapChain.Descriptor,
    ) gpu.SwapChain.Error!*gpu.SwapChain,
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
    // Surface
    surfaceDestroy: *const fn (surface: *gpu.Surface) void,
    // SwapChain
    swapChainGetCurrentTexture: *const fn (swapchain: *gpu.SwapChain) ?*gpu.Texture,
    swapChainGetCurrentTextureView: *const fn (swapchain: *gpu.SwapChain) ?*gpu.TextureView,
    swapChainPresent: *const fn (swapchain: *gpu.SwapChain) gpu.SwapChain.Error!void,
    swapChainResize: *const fn (swapchain: *gpu.SwapChain, size: [2]u32) gpu.SwapChain.Error!void,
    swapChainDestroy: *const fn (swapchain: *gpu.SwapChain) void,
};
