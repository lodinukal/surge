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
    textureGetView: *const fn (texture: *gpu.Texture, desc: *const gpu.TextureView.Descriptor) gpu.TextureView.Error!*gpu.TextureView,
    textureDestroy: *const fn (texture: *gpu.Texture) void,

    // TextureView
    textureViewDestroy: *const fn (texture_view: *gpu.TextureView) void,

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
    shaderGetBytecode: *const fn (shader: *const gpu.Shader) []const u8,
    shaderDestroy: *const fn (shader: *gpu.Shader) void,

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

    // CommandList
    commandListOpen: *const fn (command_list: *gpu.CommandList) void,
    commandListClose: *const fn (command_list: *gpu.CommandList) void,
    commandListClearState: *const fn (command_list: *gpu.CommandList) void,
    commandListClearTextureFloat: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        subresources: gpu.Texture.SubresourceSet,
        clear_value: [4]f32,
    ) void,
    commandListClearDepthStencilTexture: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        subresources: gpu.Texture.SubresourceSet,
        clear_depth: bool,
        depth: f32,
        clear_stencil: bool,
        stencil: u8,
    ) void,
    commandListClearTextureUint: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        subresources: gpu.Texture.SubresourceSet,
        clear_value: u32,
    ) void,
    commandListCopyTextureToTexture: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.Texture,
        dst_slice: gpu.Texture.Slice,
        src: *gpu.Texture,
        src_slice: gpu.Texture.Slice,
    ) void,
    commandListCopyToStagingTexture: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.StagingTexture,
        dst_slice: gpu.Texture.Slice,
        src: *gpu.Texture,
        src_slice: gpu.Texture.Slice,
    ) void,
    commandListCopyStagingTextureToTexture: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.Texture,
        dst_slice: gpu.Texture.Slice,
        src: *gpu.StagingTexture,
        src_slice: gpu.Texture.Slice,
    ) void,
    commandListWriteTexture: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.Texture,
        array_slice: u32,
        mip_level: u32,
        data: []const u8,
        row_pitch: usize,
        depth_pitch: usize,
    ) void,
    commandListResolveTexture: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.Texture,
        dst_subresources: gpu.Texture.SubresourceSet,
        src: *gpu.Texture,
        src_subresources: gpu.Texture.SubresourceSet,
    ) void,
    commandListWriteBuffer: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.Buffer,
        data: []const u8,
        offset: u64,
    ) void,
    commandListClearBufferUint: *const fn (
        command_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
        value: u32,
    ) void,
    commandListCopyBufferToBuffer: *const fn (
        command_list: *gpu.CommandList,
        dst: *gpu.Buffer,
        dst_offset: u64,
        src: *gpu.Buffer,
        src_offset: u64,
        byte_size: u64,
    ) void,
    commandListSetPushConstants: *const fn (
        command_list: *gpu.CommandList,
        data: []const u8,
    ) void,
    commandListSetGraphicsState: *const fn (
        command_list: *gpu.CommandList,
        state: *const gpu.GraphicsPipeline,
    ) void,
    commandListDraw: *const fn (
        command_list: *gpu.CommandList,
        args: gpu.DrawArguments,
    ) void,
    commandListDrawIndexed: *const fn (
        command_list: *gpu.CommandList,
        args: gpu.DrawArguments,
    ) void,
    commandListDrawIndirect: *const fn (
        command_list: *gpu.CommandList,
        offset_bytes: u32,
        draw_count: u32,
    ) void,
    commandListDrawIndexedIndirect: *const fn (
        command_list: *gpu.CommandList,
        offset_bytes: u32,
        draw_count: u32,
    ) void,
    commandListSetComputeState: *const fn (
        command_list: *gpu.CommandList,
        state: *const gpu.ComputePipeline,
    ) void,
    commandListDispatch: *const fn (
        command_list: *gpu.CommandList,
        x: u32,
        y: u32,
        z: u32,
    ) void,
    commandListDispatchIndirect: *const fn (
        command_list: *gpu.CommandList,
        offset_bytes: u32,
    ) void,
    commandListSetMeshletState: *const fn (
        command_list: *gpu.CommandList,
        state: *const gpu.MeshletPipeline,
    ) void,
    commandListDispatchMesh: *const fn (
        command_list: *gpu.CommandList,
        x: u32,
        y: u32,
        z: u32,
    ) void,
    commandListBeginTimerQuery: *const fn (
        command_list: *gpu.CommandList,
        query: *gpu.TimerQuery,
    ) void,
    commandListEndTimerQuery: *const fn (
        command_list: *gpu.CommandList,
        query: *gpu.TimerQuery,
    ) void,
    commandListBeginMarker: *const fn (
        command_list: *gpu.CommandList,
        name: []const u8,
    ) void,
    commandListEndMarker: *const fn (command_list: *gpu.CommandList) void,
    commandListSetEnableAutomaticBarriers: *const fn (
        command_list: *gpu.CommandList,
        enable: bool,
    ) void,
    commandListSetEnableUAVBarriersForTexture: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        enable: bool,
    ) void,
    commandListSetEnableUAVBarriersForBuffer: *const fn (
        command_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
        enable: bool,
    ) void,
    commandListBeginTrackingTextureState: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        subresources: gpu.Texture.SubresourceSet,
        state: gpu.ResourceStates,
    ) void,
    commandListBeginTrackingBufferState: *const fn (
        command_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
        state: gpu.ResourceStates,
    ) void,
    commandListSetTextureState: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        subresources: gpu.Texture.SubresourceSet,
        state: gpu.ResourceStates,
    ) void,
    commandListSetBufferState: *const fn (
        command_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
        state: gpu.ResourceStates,
    ) void,
    commandListSetPermanentTextureState: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        state: gpu.ResourceStates,
    ) void,
    commandListSetPermanentBufferState: *const fn (
        command_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
        state: gpu.ResourceStates,
    ) void,
    commandListCommitBarriers: *const fn (command_list: *gpu.CommandList) void,
    commandListGetTextureSubresourceState: *const fn (
        command_list: *gpu.CommandList,
        texture: *gpu.Texture,
        array_slice: gpu.ArraySlice,
        mip_level: gpu.MipLevel,
    ) gpu.ResourceStates,
    commandListGetBufferState: *const fn (
        command_list: *gpu.CommandList,
        buffer: *gpu.Buffer,
    ) gpu.ResourceStates,
    commandListGetDescriptor: *const fn (
        command_list: *gpu.CommandList,
    ) *const gpu.CommandList.Descriptor,

    // Device
    deviceCreateSwapChain: *const fn (
        device: *gpu.Device,
        surface: ?*gpu.Surface,
        desc: *const gpu.SwapChain.Descriptor,
    ) gpu.SwapChain.Error!*gpu.SwapChain,
    deviceCreateHeap: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Heap.Descriptor,
    ) gpu.Heap.Error!*gpu.Heap,
    deviceCreateTexture: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Texture.Descriptor,
    ) gpu.Texture.Error!*gpu.Texture,
    deviceGetTextureMemoryRequirements: *const fn (
        device: *gpu.Device,
        texture: *gpu.Texture,
    ) gpu.MemoryRequirements,
    deviceBindTextureMemory: *const fn (
        device: *gpu.Device,
        texture: *gpu.Texture,
        heap: *gpu.Heap,
        offset: u64,
    ) gpu.Texture.Error!void,
    deviceCreateStagingTexture: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Texture.Descriptor,
    ) gpu.StagingTexture.Error!*gpu.StagingTexture,
    deviceMapStagingTexture: *const fn (
        device: *gpu.Device,
        slice: gpu.Texture.Slice,
        access: gpu.CpuAccessMode,
        out_row_pitch: *usize,
    ) gpu.StagingTexture.Error![]u8,
    deviceMapStagingTextureConst: *const fn (
        device: *gpu.Device,
        slice: gpu.Texture.Slice,
        access: gpu.CpuAccessMode,
        out_row_pitch: *usize,
    ) gpu.StagingTexture.Error![]const u8,
    deviceUnmapStagingTexture: *const fn (
        device: *gpu.Device,
        slice: gpu.Texture.Slice,
    ) gpu.StagingTexture.Error!void,
    deviceCreateBuffer: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Buffer.Descriptor,
    ) gpu.Buffer.Error!*gpu.Buffer,
    deviceMapBuffer: *const fn (
        device: *gpu.Device,
        buffer: *gpu.Buffer,
        access: gpu.CpuAccessMode,
    ) gpu.Buffer.Error![]u8,
    deviceMapBufferConst: *const fn (
        device: *gpu.Device,
        buffer: *gpu.Buffer,
        access: gpu.CpuAccessMode,
    ) gpu.Buffer.Error![]const u8,
    deviceUnmapBuffer: *const fn (
        device: *gpu.Device,
        buffer: *gpu.Buffer,
    ) void,
    deviceGetBufferMemoryRequirements: *const fn (
        self: *gpu.Device,
        buffer: *gpu.Buffer,
    ) gpu.MemoryRequirements,
    deviceBindBufferMemory: *const fn (
        device: *gpu.Device,
        buffer: *gpu.Buffer,
        heap: *gpu.Heap,
        offset: u64,
    ) gpu.Buffer.Error!void,
    deviceCreateShader: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Shader.Descriptor,
        binary: []const u8,
    ) gpu.Shader.Error!*gpu.Shader,
    deviceCreateShaderSpecialisation: *const fn (
        device: *gpu.Device,
        shader: *gpu.Shader,
        constants: []const gpu.Shader.Specialisation,
    ) gpu.Shader.Error!*gpu.Shader,
    deviceCreateSampler: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Sampler.Descriptor,
    ) gpu.Sampler.Error!*gpu.Sampler,
    deviceCreateInputLayout: *const fn (
        device: *gpu.Device,
        attributes: []const gpu.VertexAttributeDescriptor,
        vertex_shader: ?*gpu.Shader,
    ) gpu.InputLayout.Error!*gpu.InputLayout,
    deviceCreateEventQuery: *const fn (
        device: *gpu.Device,
    ) gpu.EventQuery.Error!*gpu.EventQuery,
    deviceSetEventQuery: *const fn (
        device: *gpu.Device,
        query: *gpu.EventQuery,
    ) void,
    devicePollEventQuery: *const fn (
        device: *gpu.Device,
        query: *gpu.EventQuery,
    ) bool,
    deviceWaitEventQuery: *const fn (
        device: *gpu.Device,
        query: *gpu.EventQuery,
    ) void,
    deviceResetEventQuery: *const fn (
        device: *gpu.Device,
        query: *gpu.EventQuery,
    ) void,
    deviceCreateTimerQuery: *const fn (
        device: *gpu.Device,
    ) gpu.TimerQuery.Error!*gpu.TimerQuery,
    devicePollTimerQuery: *const fn (
        device: *gpu.Device,
        query: *gpu.TimerQuery,
    ) bool,
    deviceGetTimerQueryTime: *const fn (
        device: *gpu.Device,
        query: *gpu.TimerQuery,
    ) f32,
    deviceResetTimerQuery: *const fn (
        device: *gpu.Device,
        query: *gpu.TimerQuery,
    ) void,
    deviceCreateFramebuffer: *const fn (
        device: *gpu.Device,
        desc: *const gpu.Framebuffer.Descriptor,
    ) gpu.Framebuffer.Error!*gpu.Framebuffer,
    deviceCreateGraphicsPipeline: *const fn (
        device: *gpu.Device,
        desc: *const gpu.GraphicsPipeline.Descriptor,
    ) gpu.GraphicsPipeline.Error!*gpu.GraphicsPipeline,
    deviceCreateComputePipeline: *const fn (
        device: *gpu.Device,
        desc: *const gpu.ComputePipeline.Descriptor,
    ) gpu.ComputePipeline.Error!*gpu.ComputePipeline,
    deviceCreateMeshletPipeline: *const fn (
        device: *gpu.Device,
        desc: *const gpu.MeshletPipeline.Descriptor,
    ) gpu.MeshletPipeline.Error!*gpu.MeshletPipeline,
    deviceCreateBindingLayout: *const fn (
        device: *gpu.Device,
        desc: *const gpu.BindingLayout.Descriptor,
    ) gpu.BindingLayout.Error!*gpu.BindingLayout,
    deviceCreateBindlessBindingLayout: *const fn (
        device: *gpu.Device,
        desc: *const gpu.BindingLayout.BindlessDescriptor,
    ) gpu.BindingLayout.Error!*gpu.BindingLayout,
    deviceCreateBindingSet: *const fn (
        device: *gpu.Device,
        desc: *const gpu.BindingSet.Descriptor,
        layout: *gpu.BindingLayout,
    ) gpu.BindingSet.Error!*gpu.BindingSet,
    deviceCreateDescriptorTable: *const fn (
        device: *gpu.Device,
        layout: *gpu.BindingLayout,
    ) gpu.DescriptorTable.Error!*gpu.DescriptorTable,
    deviceResizeDescriptorTable: *const fn (
        device: *gpu.Device,
        table: *gpu.DescriptorTable,
        new_size: u32,
        keep_contents: bool,
    ) void,
    deviceWriteDescriptorTable: *const fn (
        device: *gpu.Device,
        table: *gpu.DescriptorTable,
        item: *const gpu.BindingSet.Item,
    ) bool,
    deviceCreateCommandList: *const fn (
        device: *gpu.Device,
        desc: *const gpu.CommandList.Descriptor,
    ) gpu.CommandList.Error!*gpu.CommandList,
    deviceExecuteCommandLists: *const fn (
        device: *gpu.Device,
        command_lists: []const *gpu.CommandList,
        execution: gpu.CommandQueue,
    ) u64,
    deviceQueueWaitForCommandList: *const fn (
        device: *gpu.Device,
        wait: gpu.CommandQueue,
        execution: gpu.CommandQueue,
        instance: u64,
    ) void,
    deviceWaitForIdle: *const fn (device: *gpu.Device) void,
    deviceCleanGarbage: *const fn (device: *gpu.Device) void,
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
    // swapChainGetCurrentTexture: *const fn (swapchain: *gpu.SwapChain) ?*gpu.Texture,
    // swapChainGetCurrentTextureView: *const fn (swapchain: *gpu.SwapChain) ?*gpu.TextureView,
    swapChainPresent: *const fn (swapchain: *gpu.SwapChain) gpu.SwapChain.Error!void,
    swapChainResize: *const fn (swapchain: *gpu.SwapChain, size: [2]u32) gpu.SwapChain.Error!void,
    swapChainDestroy: *const fn (swapchain: *gpu.SwapChain) void,
};
