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

pub inline fn textureGetView(texture: *gpu.Texture, desc: *const gpu.TextureView.Descriptor) !*gpu.TextureView {
    return procs.Procs.loaded_procs.?.textureGetView(texture, desc);
}

pub inline fn textureDestroy(texture: *gpu.Texture) void {
    return procs.Procs.loaded_procs.?.textureDestroy(texture);
}

// TextureView
pub inline fn textureViewDestroy(textureView: *gpu.TextureView) void {
    return procs.Procs.loaded_procs.?.textureViewDestroy(textureView);
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

pub inline fn shaderGetBytecode(shader: *const gpu.Shader) []const u8 {
    return procs.Procs.loaded_procs.?.shaderGetBytecode(shader);
}

pub inline fn shaderDestroy(shader: *gpu.Shader) void {
    return procs.Procs.loaded_procs.?.shaderDestroy(shader);
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

// ComputePipeline
pub inline fn computePipelineGetDescriptor(computePipeline: *const gpu.ComputePipeline) *const gpu.ComputePipeline.Descriptor {
    return procs.Procs.loaded_procs.?.computePipelineGetDescriptor(computePipeline);
}

pub inline fn computePipelineDestroy(computePipeline: *gpu.ComputePipeline) void {
    return procs.Procs.loaded_procs.?.computePipelineDestroy(computePipeline);
}

// EventQuery
pub inline fn eventQueryDestroy(eventQuery: *gpu.EventQuery) void {
    return procs.Procs.loaded_procs.?.eventQueryDestroy(eventQuery);
}

// TimerQuery
pub inline fn timerQueryDestroy(timerQuery: *gpu.TimerQuery) void {
    return procs.Procs.loaded_procs.?.timerQueryDestroy(timerQuery);
}

// CommandList

pub inline fn commandListOpen(command_list: *gpu.CommandList) void {
    return procs.Procs.loaded_procs.?.commandListOpen(command_list);
}

pub inline fn commandListClose(command_list: *gpu.CommandList) void {
    return procs.Procs.loaded_procs.?.commandListClose(command_list);
}

pub inline fn commandListClearState(
    command_list: *gpu.CommandList,
) void {
    return procs.Procs.loaded_procs.?.commandListClearState(command_list);
}

pub inline fn commandListClearTextureFloat(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    subresources: gpu.Texture.SubresourceSet,
    clear_value: [4]f32,
) void {
    return procs.Procs.loaded_procs.?.commandListClearTextureFloat(
        command_list,
        texture,
        subresources,
        clear_value,
    );
}

pub inline fn commandListClearDepthStencilTexture(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    subresources: gpu.Texture.SubresourceSet,
    clear_depth: bool,
    depth: f32,
    clear_stencil: bool,
    stencil: u8,
) void {
    return procs.Procs.loaded_procs.?.commandListClearDepthStencilTexture(
        command_list,
        texture,
        subresources,
        clear_depth,
        depth,
        clear_stencil,
        stencil,
    );
}

pub inline fn commandListClearTextureUint(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    subresources: gpu.Texture.SubresourceSet,
    clear_value: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListClearTextureUint(
        command_list,
        texture,
        subresources,
        clear_value,
    );
}

pub inline fn commandListCopyTextureToTexture(
    command_list: *gpu.CommandList,
    dst: *gpu.Texture,
    dst_slice: gpu.Texture.Slice,
    src: *gpu.Texture,
    src_slice: gpu.Texture.Slice,
) void {
    return procs.Procs.loaded_procs.?.commandListCopyTextureToTexture(
        command_list,
        dst,
        dst_slice,
        src,
        src_slice,
    );
}

pub inline fn commandListCopyToStagingTexture(
    command_list: *gpu.CommandList,
    dst: *gpu.StagingTexture,
    dst_slice: gpu.Texture.Slice,
    src: *gpu.Texture,
    src_slice: gpu.Texture.Slice,
) void {
    return procs.Procs.loaded_procs.?.commandListCopyToStagingTexture(
        command_list,
        dst,
        dst_slice,
        src,
        src_slice,
    );
}

pub inline fn commandListCopyStagingTextureToTexture(
    command_list: *gpu.CommandList,
    dst: *gpu.Texture,
    dst_slice: gpu.Texture.Slice,
    src: *gpu.StagingTexture,
    src_slice: gpu.Texture.Slice,
) void {
    return procs.Procs.loaded_procs.?.commandListCopyStagingTextureToTexture(
        command_list,
        dst,
        dst_slice,
        src,
        src_slice,
    );
}

pub inline fn commandListWriteTexture(
    command_list: *gpu.CommandList,
    dst: *gpu.Texture,
    array_slice: u32,
    mip_level: u32,
    data: []const u8,
    row_pitch: usize,
    depth_pitch: usize,
) void {
    return procs.Procs.loaded_procs.?.commandListWriteTexture(
        command_list,
        dst,
        array_slice,
        mip_level,
        data,
        row_pitch,
        depth_pitch,
    );
}

pub inline fn commandListResolveTexture(
    command_list: *gpu.CommandList,
    dst: *gpu.Texture,
    dst_subresources: gpu.Texture.SubresourceSet,
    src: *gpu.Texture,
    src_subresources: gpu.Texture.SubresourceSet,
) void {
    return procs.Procs.loaded_procs.?.commandListResolveTexture(
        command_list,
        dst,
        dst_subresources,
        src,
        src_subresources,
    );
}

pub inline fn commandListWriteBuffer(
    command_list: *gpu.CommandList,
    dst: *gpu.Buffer,
    data: []const u8,
    offset: u64,
) void {
    return procs.Procs.loaded_procs.?.commandListWriteBuffer(
        command_list,
        dst,
        data,
        offset,
    );
}

pub inline fn commandListClearBufferUint(
    command_list: *gpu.CommandList,
    buffer: *gpu.Buffer,
    value: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListClearBufferUint(
        command_list,
        buffer,
        value,
    );
}

pub inline fn commandListCopyBufferToBuffer(
    command_list: *gpu.CommandList,
    dst: *gpu.Buffer,
    dst_offset: u64,
    src: *gpu.Buffer,
    src_offset: u64,
    byte_size: u64,
) void {
    return procs.Procs.loaded_procs.?.commandListCopyBufferToBuffer(
        command_list,
        dst,
        dst_offset,
        src,
        src_offset,
        byte_size,
    );
}

pub inline fn commandListSetPushConstants(
    command_list: *gpu.CommandList,
    data: []const u8,
) void {
    return procs.Procs.loaded_procs.?.commandListSetPushConstants(
        command_list,
        data,
    );
}

pub inline fn commandListSetGraphicsState(
    command_list: *gpu.CommandList,
    state: *const gpu.GraphicsPipeline,
) void {
    return procs.Procs.loaded_procs.?.commandListSetGraphicsState(
        command_list,
        state,
    );
}

pub inline fn commandListDraw(
    command_list: *gpu.CommandList,
    args: gpu.DrawArguments,
) void {
    return procs.Procs.loaded_procs.?.commandListDraw(
        command_list,
        args,
    );
}

pub inline fn commandListDrawIndexed(
    command_list: *gpu.CommandList,
    args: gpu.DrawArguments,
) void {
    return procs.Procs.loaded_procs.?.commandListDrawIndexed(
        command_list,
        args,
    );
}

pub inline fn commandListDrawIndirect(
    command_list: *gpu.CommandList,
    offset_bytes: u32,
    draw_count: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListDrawIndirect(
        command_list,
        offset_bytes,
        draw_count,
    );
}

pub inline fn commandListDrawIndexedIndirect(
    command_list: *gpu.CommandList,
    offset_bytes: u32,
    draw_count: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListDrawIndexedIndirect(
        command_list,
        offset_bytes,
        draw_count,
    );
}

pub inline fn commandListSetComputeState(
    command_list: *gpu.CommandList,
    state: *const gpu.ComputePipeline,
) void {
    return procs.Procs.loaded_procs.?.commandListSetComputeState(
        command_list,
        state,
    );
}

pub inline fn commandListDispatch(
    command_list: *gpu.CommandList,
    x: u32,
    y: u32,
    z: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListDispatch(
        command_list,
        x,
        y,
        z,
    );
}

pub inline fn commandListDispatchIndirect(
    command_list: *gpu.CommandList,
    offset_bytes: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListDispatchIndirect(
        command_list,
        offset_bytes,
    );
}

pub inline fn commandListSetMeshletState(
    command_list: *gpu.CommandList,
    state: *const gpu.MeshletPipeline,
) void {
    return procs.Procs.loaded_procs.?.commandListSetMeshletState(
        command_list,
        state,
    );
}

pub inline fn commandListDispatchMesh(
    command_list: *gpu.CommandList,
    x: u32,
    y: u32,
    z: u32,
) void {
    return procs.Procs.loaded_procs.?.commandListDispatchMesh(
        command_list,
        x,
        y,
        z,
    );
}

pub inline fn commandListBeginTimerQuery(
    command_list: *gpu.CommandList,
    query: *gpu.TimerQuery,
) void {
    return procs.Procs.loaded_procs.?.commandListBeginTimerQuery(
        command_list,
        query,
    );
}

pub inline fn commandListEndTimerQuery(
    command_list: *gpu.CommandList,
    query: *gpu.TimerQuery,
) void {
    return procs.Procs.loaded_procs.?.commandListEndTimerQuery(
        command_list,
        query,
    );
}

pub inline fn commandListBeginMarker(
    command_list: *gpu.CommandList,
    name: []const u8,
) void {
    return procs.Procs.loaded_procs.?.commandListBeginMarker(
        command_list,
        name,
    );
}

pub inline fn commandListEndMarker(command_list: *gpu.CommandList) void {
    return procs.Procs.loaded_procs.?.commandListEndMarker(command_list);
}

pub inline fn commandListSetEnableAutomaticBarriers(
    command_list: *gpu.CommandList,
    enable: bool,
) void {
    return procs.Procs.loaded_procs.?.commandListSetEnableAutomaticBarriers(
        command_list,
        enable,
    );
}

pub inline fn commandListSetEnableUAVBarriersForTexture(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    enable: bool,
) void {
    return procs.Procs.loaded_procs.?.commandListSetEnableUAVBarriersForTexture(
        command_list,
        texture,
        enable,
    );
}

pub inline fn commandListSetEnableUAVBarriersForBuffer(
    command_list: *gpu.CommandList,
    buffer: *gpu.Buffer,
    enable: bool,
) void {
    return procs.Procs.loaded_procs.?.commandListSetEnableUAVBarriersForBuffer(
        command_list,
        buffer,
        enable,
    );
}

pub inline fn commandListBeginTrackingTextureState(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    subresources: gpu.Texture.SubresourceSet,
    state: gpu.ResourceStates,
) void {
    return procs.Procs.loaded_procs.?.commandListBeginTrackingTextureState(
        command_list,
        texture,
        subresources,
        state,
    );
}

pub inline fn commandListBeginTrackingBufferState(
    command_list: *gpu.CommandList,
    buffer: *gpu.Buffer,
    state: gpu.ResourceStates,
) void {
    return procs.Procs.loaded_procs.?.commandListBeginTrackingBufferState(
        command_list,
        buffer,
        state,
    );
}

pub inline fn commandListSetTextureState(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    subresources: gpu.Texture.SubresourceSet,
    state: gpu.ResourceStates,
) void {
    return procs.Procs.loaded_procs.?.commandListSetTextureState(
        command_list,
        texture,
        subresources,
        state,
    );
}

pub inline fn commandListSetBufferState(
    command_list: *gpu.CommandList,
    buffer: *gpu.Buffer,
    state: gpu.ResourceStates,
) void {
    return procs.Procs.loaded_procs.?.commandListSetBufferState(
        command_list,
        buffer,
        state,
    );
}

pub inline fn commandListSetPermanentTextureState(
    command_list: *gpu.CommandList,
    texture: *gpu.Texture,
    state: gpu.ResourceStates,
) void {
    return procs.Procs.loaded_procs.?.commandListSetPermanentTextureState(
        command_list,
        texture,
        state,
    );
}

pub inline fn commandListSetPermanentBufferState(
    command_list: *gpu.CommandList,
    buffer: *gpu.Buffer,
    state: gpu.ResourceStates,
) void {
    return procs.Procs.loaded_procs.?.commandListSetPermanentBufferState(
        command_list,
        buffer,
        state,
    );
}

pub inline fn commandListCommitBarriers(command_list: *gpu.CommandList) void {
    return procs.Procs.loaded_procs.?.commandListCommitBarriers(command_list);
}

pub inline fn commandListGetTextureSubresourceState() gpu.ResourceStates {
    return procs.Procs.loaded_procs.?.commandListGetTextureSubresourceState();
}

pub inline fn commandListGetBufferState() gpu.ResourceStates {
    return procs.Procs.loaded_procs.?.commandListGetBufferState();
}

pub inline fn commandListGetDescriptor() *const gpu.CommandList.Descriptor {
    return procs.Procs.loaded_procs.?.commandListGetDescriptor();
}

// Device
pub inline fn deviceCreateSwapChain(
    device: *gpu.Device,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    return procs.Procs.loaded_procs.?.deviceCreateSwapChain(device, surface, desc);
}

pub inline fn deviceCreateHeap(
    device: *gpu.Device,
    desc: *const gpu.Heap.Descriptor,
) gpu.Heap.Error!*gpu.Heap {
    return procs.Procs.loaded_procs.?.deviceCreateHeap(device, desc);
}

pub inline fn deviceCreateTexture(
    device: *gpu.Device,
    desc: *const gpu.Texture.Descriptor,
) gpu.Texture.Error!*gpu.Texture {
    return procs.Procs.loaded_procs.?.deviceCreateTexture(device, desc);
}

pub inline fn deviceGetTextureMemoryRequirements(
    device: *gpu.Device,
    texture: *gpu.Texture,
) gpu.MemoryRequirements {
    return procs.Procs.loaded_procs.?.deviceGetTextureMemoryRequirements(device, texture);
}

pub inline fn deviceBindTextureMemory(
    device: *gpu.Device,
    texture: *gpu.Texture,
    heap: *gpu.Heap,
    offset: u64,
) gpu.Texture.Error!void {
    return procs.Procs.loaded_procs.?.deviceBindTextureMemory(device, texture, heap, offset);
}

pub inline fn deviceCreateStagingTexture(
    device: *gpu.Device,
    desc: *const gpu.Texture.Descriptor,
) gpu.StagingTexture.Error!*gpu.StagingTexture {
    return procs.Procs.loaded_procs.?.deviceCreateStagingTexture(device, desc);
}

pub inline fn deviceMapStagingTexture(
    device: *gpu.Device,
    slice: gpu.Texture.Slice,
    access: gpu.CpuAccessMode,
    out_row_pitch: *usize,
) gpu.StagingTexture.Error![]u8 {
    return procs.Procs.loaded_procs.?.deviceMapStagingTexture(device, slice, access, out_row_pitch);
}

pub inline fn deviceMapStagingTextureConst(
    device: *gpu.Device,
    slice: gpu.Texture.Slice,
    access: gpu.CpuAccessMode,
    out_row_pitch: *usize,
) gpu.StagingTexture.Error![]const u8 {
    return procs.Procs.loaded_procs.?.deviceMapStagingTextureConst(device, slice, access, out_row_pitch);
}

pub inline fn deviceUnmapStagingTexture(
    device: *gpu.Device,
    slice: gpu.Texture.Slice,
) gpu.StagingTexture.Error!void {
    return procs.Procs.loaded_procs.?.deviceUnmapStagingTexture(device, slice);
}

pub inline fn deviceCreateBuffer(
    device: *gpu.Device,
    desc: *const gpu.Buffer.Descriptor,
) gpu.Buffer.Error!*gpu.Buffer {
    return procs.Procs.loaded_procs.?.deviceCreateBuffer(device, desc);
}

pub inline fn deviceMapBuffer(
    device: *gpu.Device,
    buffer: *gpu.Buffer,
    access: gpu.CpuAccessMode,
) gpu.Buffer.Error![]u8 {
    return procs.Procs.loaded_procs.?.deviceMapBuffer(device, buffer, access);
}

pub inline fn deviceMapBufferConst(
    device: *gpu.Device,
    buffer: *gpu.Buffer,
    access: gpu.CpuAccessMode,
) gpu.Buffer.Error![]const u8 {
    return procs.Procs.loaded_procs.?.deviceMapBufferConst(device, buffer, access);
}

pub inline fn deviceUnmapBuffer(
    device: *gpu.Device,
    buffer: *gpu.Buffer,
) void {
    return procs.Procs.loaded_procs.?.deviceUnmapBuffer(device, buffer);
}

pub inline fn deviceGetBufferMemoryRequirements(
    self: *gpu.Device,
    buffer: *gpu.Buffer,
) gpu.MemoryRequirements {
    return procs.Procs.loaded_procs.?.deviceGetBufferMemoryRequirements(self, buffer);
}

pub inline fn deviceBindBufferMemory(
    device: *gpu.Device,
    buffer: *gpu.Buffer,
    heap: *gpu.Heap,
    offset: u64,
) gpu.Buffer.Error!void {
    return procs.Procs.loaded_procs.?.deviceBindBufferMemory(device, buffer, heap, offset);
}

pub inline fn deviceCreateShader(
    device: *gpu.Device,
    desc: *const gpu.Shader.Descriptor,
    binary: []const u8,
) gpu.Shader.Error!*gpu.Shader {
    return procs.Procs.loaded_procs.?.deviceCreateShader(device, desc, binary);
}

pub inline fn deviceCreateShaderSpecialisation(
    device: *gpu.Device,
    shader: *gpu.Shader,
    constants: []const gpu.Shader.Specialisation,
) gpu.Shader.Error!*gpu.Shader {
    return procs.Procs.loaded_procs.?.deviceCreateShaderSpecialisation(device, shader, constants);
}

pub inline fn deviceCreateSampler(
    device: *gpu.Device,
    desc: *const gpu.Sampler.Descriptor,
) gpu.Sampler.Error!*gpu.Sampler {
    return procs.Procs.loaded_procs.?.deviceCreateSampler(device, desc);
}

pub inline fn deviceCreateInputLayout(
    device: *gpu.Device,
    attributes: []const gpu.VertexAttributeDescriptor,
    vertex_shader: ?*gpu.Shader,
) gpu.InputLayout.Error!*gpu.InputLayout {
    return procs.Procs.loaded_procs.?.deviceCreateInputLayout(device, attributes, vertex_shader);
}

pub inline fn deviceCreateEventQuery(
    device: *gpu.Device,
) gpu.EventQuery.Error!*gpu.EventQuery {
    return procs.Procs.loaded_procs.?.deviceCreateEventQuery(device);
}

pub inline fn deviceSetEventQuery(
    device: *gpu.Device,
    query: *gpu.EventQuery,
) void {
    return procs.Procs.loaded_procs.?.deviceSetEventQuery(device, query);
}

pub inline fn devicePollEventQuery(
    device: *gpu.Device,
    query: *gpu.EventQuery,
) bool {
    return procs.Procs.loaded_procs.?.devicePollEventQuery(device, query);
}

pub inline fn deviceWaitEventQuery(
    device: *gpu.Device,
    query: *gpu.EventQuery,
) void {
    return procs.Procs.loaded_procs.?.deviceWaitEventQuery(device, query);
}

pub inline fn deviceResetEventQuery(
    device: *gpu.Device,
    query: *gpu.EventQuery,
) void {
    return procs.Procs.loaded_procs.?.deviceResetEventQuery(device, query);
}

pub inline fn deviceCreateTimerQuery(
    device: *gpu.Device,
) gpu.TimerQuery.Error!*gpu.TimerQuery {
    return procs.Procs.loaded_procs.?.deviceCreateTimerQuery(device);
}

pub inline fn devicePollTimerQuery(
    device: *gpu.Device,
    query: *gpu.TimerQuery,
) bool {
    return procs.Procs.loaded_procs.?.devicePollTimerQuery(device, query);
}

pub inline fn deviceGetTimerQueryTime(
    device: *gpu.Device,
    query: *gpu.TimerQuery,
) f32 {
    return procs.Procs.loaded_procs.?.deviceGetTimerQueryTime(device, query);
}

pub inline fn deviceResetTimerQuery(
    device: *gpu.Device,
    query: *gpu.TimerQuery,
) void {
    return procs.Procs.loaded_procs.?.deviceResetTimerQuery(device, query);
}

pub inline fn deviceCreateFramebuffer(
    device: *gpu.Device,
    desc: *const gpu.Framebuffer.Descriptor,
) gpu.Framebuffer.Error!*gpu.Framebuffer {
    return procs.Procs.loaded_procs.?.deviceCreateFramebuffer(device, desc);
}

pub inline fn deviceCreateGraphicsPipeline(
    device: *gpu.Device,
    desc: *const gpu.GraphicsPipeline.Descriptor,
) gpu.GraphicsPipeline.Error!*gpu.GraphicsPipeline {
    return procs.Procs.loaded_procs.?.deviceCreateGraphicsPipeline(device, desc);
}

pub inline fn deviceCreateComputePipeline(
    device: *gpu.Device,
    desc: *const gpu.ComputePipeline.Descriptor,
) gpu.ComputePipeline.Error!*gpu.ComputePipeline {
    return procs.Procs.loaded_procs.?.deviceCreateComputePipeline(device, desc);
}

pub inline fn deviceCreateMeshletPipeline(
    device: *gpu.Device,
    desc: *const gpu.MeshletPipeline.Descriptor,
) gpu.MeshletPipeline.Error!*gpu.MeshletPipeline {
    return procs.Procs.loaded_procs.?.deviceCreateMeshletPipeline(device, desc);
}

pub inline fn deviceCreateBindingLayout(
    device: *gpu.Device,
    desc: *const gpu.BindingLayout.Descriptor,
) gpu.BindingLayout.Error!*gpu.BindingLayout {
    return procs.Procs.loaded_procs.?.deviceCreateBindingLayout(device, desc);
}

pub inline fn deviceCreateBindlessBindingLayout(
    device: *gpu.Device,
    desc: *const gpu.BindingLayout.BindlessDescriptor,
) gpu.BindingLayout.Error!*gpu.BindingLayout {
    return procs.Procs.loaded_procs.?.deviceCreateBindlessBindingLayout(device, desc);
}

pub inline fn deviceCreateBindingSet(
    device: *gpu.Device,
    desc: *const gpu.BindingSet.Descriptor,
    layout: *gpu.BindingLayout,
) gpu.BindingSet.Error!*gpu.BindingSet {
    return procs.Procs.loaded_procs.?.deviceCreateBindingSet(device, desc, layout);
}

pub inline fn deviceCreateDescriptorTable(
    device: *gpu.Device,
    layout: *gpu.BindingLayout,
) gpu.DescriptorTable.Error!*gpu.DescriptorTable {
    return procs.Procs.loaded_procs.?.deviceCreateDescriptorTable(device, layout);
}

pub inline fn deviceResizeDescriptorTable(
    device: *gpu.Device,
    table: *gpu.DescriptorTable,
    new_size: u32,
    keep_contents: bool,
) void {
    return procs.Procs.loaded_procs.?.deviceResizeDescriptorTable(device, table, new_size, keep_contents);
}

pub inline fn deviceWriteDescriptorTable(
    device: *gpu.Device,
    table: *gpu.DescriptorTable,
    item: *const gpu.BindingSet.Item,
) bool {
    return procs.Procs.loaded_procs.?.deviceWriteDescriptorTable(device, table, item);
}

pub inline fn deviceCreateCommandList(
    device: *gpu.Device,
    desc: *const gpu.CommandList.Descriptor,
) gpu.CommandList.Error!*gpu.CommandList {
    return procs.Procs.loaded_procs.?.deviceCreateCommandList(device, desc);
}

pub inline fn deviceExecuteCommandLists(
    device: *gpu.Device,
    command_lists: []const *gpu.CommandList,
    execution: gpu.CommandQueue,
) u64 {
    return procs.Procs.loaded_procs.?.deviceExecuteCommandLists(device, command_lists, execution);
}

pub inline fn deviceQueueWaitForCommandList(
    device: *gpu.Device,
    wait: gpu.CommandQueue,
    execution: gpu.CommandQueue,
    instance: u64,
) void {
    return procs.Procs.loaded_procs.?.deviceQueueWaitForCommandList(device, wait, execution, instance);
}

pub inline fn deviceWaitForIdle(
    device: *gpu.Device,
) void {
    return procs.Procs.loaded_procs.?.deviceWaitForIdle(device);
}

pub inline fn deviceCleanGarbage(
    device: *gpu.Device,
) void {
    return procs.Procs.loaded_procs.?.deviceCleanGarbage(device);
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
