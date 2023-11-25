const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");
const Handle = Renderer.Handle;

const Self = @This();

vtable: *const struct {
    begin: *const fn (self: *Self) void,
    end: *const fn (self: *Self) void,
    /// only accepts secondary command buffers
    execute: *const fn (self: *Self, handle: Handle(Self)) void,

    updateBuffer: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
        offset: u64,
        data: []const u8,
    ) void,
    copyBuffer: *const fn (
        self: *Self,
        src: Handle(Renderer.Buffer),
        src_offset: u64,
        dst: Handle(Renderer.Buffer),
        dst_offset: u64,
        size: u64,
    ) void,
    copyBufferFromTexture: *const fn (
        self: *Self,
        src: Handle(Renderer.Texture),
        src_region: Renderer.Texture.TextureRegion,
        dst: Handle(Renderer.Buffer),
        dst_offset: u64,
        row_stride: ?u32,
        layer_stride: ?u32,
    ) void,
    fillBuffer: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
        offset: u64,
        value: u32,
        fill_size: ?u64,
    ) void,
    copyTexture: *const fn (
        self: *Self,
        src: Handle(Renderer.Texture),
        src_location: Renderer.Texture.TextureLocation,
        dst: Handle(Renderer.Texture),
        dst_location: Renderer.Texture.TextureLocation,
        extent: [3]u32,
    ) void,
    copyTextureFromBuffer: *const fn (
        self: *Self,
        src: Handle(Renderer.Buffer),
        src_offset: u64,
        dst: Handle(Renderer.Texture),
        dst_region: Renderer.Texture.TextureRegion,
        row_stride: ?u32,
        layer_stride: ?u32,
    ) void,
    copyTextureFromFramebuffer: *const fn (
        self: *Self,
        src_offset: [2]u32,
        dst: Handle(Renderer.Texture),
        dst_region: Renderer.Texture.TextureRegion,
    ) void,
    generateMips: *const fn (
        self: *Self,
        texture: Handle(Renderer.Texture),
    ) void,
    generateMipsForSubresource: *const fn (
        self: *Self,
        texture: Handle(Renderer.Texture),
        subresource: Renderer.Texture.TextureSubresource,
    ) void,
    setViewport: *const fn (
        self: *Self,
        viewport: Renderer.Viewport,
    ) void,
    setViewports: *const fn (
        self: *Self,
        viewports: []const Renderer.Viewport,
    ) void,
    setScissor: *const fn (
        self: *Self,
        scissor: Renderer.Scissor,
    ) void,
    setScissors: *const fn (
        self: *Self,
        scissors: []const Renderer.Scissor,
    ) void,

    setVertexBuffer: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
    ) void,
    // setVertexBufferArray: *const fn (
    //  buffer: Handle(Renderer.BufferArray),
    // ) void,
    setIndexBuffer: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
    ) void,
    setIndexBufferWithFormat: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
        format: Renderer.format.Format,
        offset: ?u64,
    ) void,

    setResourceHeap: *const fn (
        self: *Self,
        heap: Handle(Renderer.ResourceHeap),
    ) void,
    setResource: *const fn (
        self: *Self,
        index: u32,
        resource: Handle(Renderer.Resource),
    ) void,
    resetResourceSlots: *const fn (
        self: *Self,
        resource_type: Renderer.Resource.ResourceType,
        first_slot: u32,
        count: u32,
        binding: Renderer.Resource.BindingInfo,
        stages: ?Renderer.Shader.ShaderStages,
    ) void,

    beginRenderPass: *const fn (
        self: *Self,
        render_target: Handle(Renderer.RenderTarget),
        render_pass: ?Handle(Renderer.RenderPass),
        clear_values: ?[]const ClearValue,
        swap_buffer_index: ?u32,
    ) void,
    endRenderPass: *const fn (self: *Self) void,
    clear: *const fn (
        self: *Self,
        info: ClearInfo,
        clear_values: ?[]const AttachmentClear,
    ) void,
    clearAttachments: *const fn (
        self: *Self,
        attachments: []const AttachmentClear,
    ) void,

    setPipelineState: *const fn (
        self: *Self,
        pipeline_state: Handle(Renderer.PipelineState),
    ) void,
    setBlendFactor: *const fn (
        self: *Self,
        blend_factor: [4]f32,
    ) void,
    setStencilReference: *const fn (
        self: *Self,
        reference: u32,
        face: ?StencilFace,
    ) void,
    setUniforms: *const fn (
        self: *Self,
        first: u32,
        uniforms: []const u8,
    ) void,

    beginQuery: *const fn (
        self: *Self,
        query_heap: Handle(Renderer.QueryHeap),
        query_index: ?u32,
    ) void,
    endQuery: *const fn (
        self: *Self,
        query_heap: Handle(Renderer.QueryHeap),
        query_index: ?u32,
    ) void,
    beginRenderCondition: *const fn (
        self: *Self,
        query_heap: Handle(Renderer.QueryHeap),
        query_index: ?u32,
        mode: ?RenderConditionMode,
    ) void,
    endRenderCondition: *const fn (self: *Self) void,

    beginStreamOutput: *const fn (
        self: *Self,
        buffers: []const Handle(Renderer.Buffer),
    ) void,
    endStreamOutput: *const fn (self: *Self) void,

    draw: *const fn (
        self: *Self,
        vertex_count: u32,
        first_vertex: u32,
    ) void,
    drawIndexed: *const fn (
        self: *Self,
        index_count: u32,
        first_index: u32,
        vertex_offset: ?i32,
    ) void,
    drawInstanced: *const fn (
        self: *Self,
        vertex_count: u32,
        first_vertex: u32,
        instance_count: u32,
        first_instance: ?u32,
    ) void,
    drawInstanceIndexed: *const fn (
        self: *Self,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        vertex_offset: ?i32,
        first_instance: ?u32,
    ) void,
    drawIndirect: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
        offset: u64,
        draw_count: u32,
        stride: u32,
    ) void,
    drawIndexedIndirect: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
        offset: u64,
        draw_count: u32,
        stride: u32,
    ) void,

    dispatch: *const fn (
        self: *Self,
        x: u32,
        y: u32,
        z: u32,
    ) void,
    dispatchIndirect: *const fn (
        self: *Self,
        buffer: Handle(Renderer.Buffer),
        offset: u64,
    ) void,

    pushDebugGroup: *const fn (
        self: *Self,
        name: []const u8,
    ) void,
    popDebugGroup: *const fn (self: *Self) void,
},

pub const RenderConditionMode = enum {
    wait,
    no_wait,
    by_region_wait,
    by_region_no_wait,
    wait_inverted,
    no_wait_inverted,
    by_region_wait_inverted,
    by_region_no_wait_inverted,
};

pub const StencilFace = enum {
    front,
    back,
    front_and_back,
};

pub const CommandBufferInfo = struct {
    immediate: bool = false,
    secondary: bool = false,
};

pub const ClearInfo = struct {
    colour: bool = false,
    depth: bool = false,
    stencil: bool = false,
};

pub const ClearValue = struct {
    colour: [4]f32 = .{ 0, 0, 0, 0 },
    depth: f32 = 1.0,
    stencil: u32 = 0,
};

pub const AttachmentClear = struct {
    info: ClearInfo = .{},
    attachment: u32 = 0,
    clear: ClearValue = .{},
};

pub const CommandBufferDescriptor = struct {
    info: CommandBufferInfo = .{},
    native_buffer_count: u32 = 2,
    min_staging_pool_size: u64 = 0xffff + 1,
};

pub inline fn begin(self: *Self) void {
    self.vtable.begin(self);
}

pub inline fn end(self: *Self) void {
    self.vtable.end(self);
}

pub inline fn execute(self: *Self, handle: Handle(Self)) void {
    self.vtable.execute(self, handle);
}

pub inline fn updateBuffer(
    self: *Self,
    buffer: Handle(Renderer.Buffer),
    offset: u64,
    data: []const u8,
) void {
    self.vtable.updateBuffer(self, buffer, offset, data);
}

pub inline fn copyBuffer(
    self: *Self,
    src: Handle(Renderer.Buffer),
    src_offset: u64,
    dst: Handle(Renderer.Buffer),
    dst_offset: u64,
    size: u64,
) void {
    self.vtable.copyBuffer(self, src, src_offset, dst, dst_offset, size);
}

pub inline fn copyBufferFromTexture(
    self: *Self,
    src: Handle(Renderer.Texture),
    src_region: Renderer.Texture.TextureRegion,
    dst: Handle(Renderer.Buffer),
    dst_offset: u64,
    row_stride: ?u32,
    layer_stride: ?u32,
) void {
    self.vtable.copyBufferFromTexture(
        self,
        src,
        src_region,
        dst,
        dst_offset,
        row_stride,
        layer_stride,
    );
}

pub inline fn fillBuffer(
    self: *Self,
    buffer: Handle(Renderer.Buffer),
    offset: u64,
    value: u32,
    fill_size: ?u64,
) void {
    self.vtable.fillBuffer(self, buffer, offset, value, fill_size);
}

pub inline fn copyTexture(
    self: *Self,
    src: Handle(Renderer.Texture),
    src_location: Renderer.Texture.TextureLocation,
    dst: Handle(Renderer.Texture),
    dst_location: Renderer.Texture.TextureLocation,
    extent: [3]u32,
) void {
    self.vtable.copyTexture(self, src, src_location, dst, dst_location, extent);
}

pub inline fn copyTextureFromBuffer(
    self: *Self,
    src: Handle(Renderer.Buffer),
    src_offset: u64,
    dst: Handle(Renderer.Texture),
    dst_region: Renderer.Texture.TextureRegion,
    row_stride: ?u32,
    layer_stride: ?u32,
) void {
    self.vtable.copyTextureFromBuffer(
        self,
        src,
        src_offset,
        dst,
        dst_region,
        row_stride,
        layer_stride,
    );
}

pub inline fn copyTextureFromFramebuffer(
    self: *Self,
    src_offset: [2]u32,
    dst: Handle(Renderer.Texture),
    dst_region: Renderer.Texture.TextureRegion,
) void {
    self.vtable.copyTextureFromFramebuffer(
        self,
        src_offset,
        dst,
        dst_region,
    );
}

pub inline fn generateMips(self: *Self, texture: Handle(Renderer.Texture)) void {
    self.vtable.generateMips(self, texture);
}

pub inline fn generateMipsForSubresource(
    self: *Self,
    texture: Handle(Renderer.Texture),
    subresource: Renderer.Texture.TextureSubresource,
) void {
    self.vtable.generateMipsForSubresource(self, texture, subresource);
}

pub inline fn setViewport(self: *Self, viewport: Renderer.Viewport) void {
    self.vtable.setViewport(self, viewport);
}

pub inline fn setViewports(self: *Self, viewports: []const Renderer.Viewport) void {
    self.vtable.setViewports(self, viewports);
}

pub inline fn setScissor(self: *Self, scissor: Renderer.Scissor) void {
    self.vtable.setScissor(self, scissor);
}

pub inline fn setScissors(self: *Self, scissors: []const Renderer.Scissor) void {
    self.vtable.setScissors(self, scissors);
}

pub inline fn setVertexBuffer(self: *Self, buffer: Handle(Renderer.Buffer)) void {
    self.vtable.setVertexBuffer(self, buffer);
}

// pub inline fn setVertexBufferArray(self: *Self, buffer: Handle(Renderer.BufferArray)) void {
//  self.vtable.setVertexBufferArray(self, buffer);
// }

pub inline fn setIndexBuffer(self: *Self, buffer: Handle(Renderer.Buffer)) void {
    self.vtable.setIndexBuffer(self, buffer);
}

pub inline fn setIndexBufferWithFormat(
    self: *Self,
    buffer: Handle(Renderer.Buffer),
    format: Renderer.format.Format,
    offset: ?u64,
) void {
    self.vtable.setIndexBufferWithFormat(self, buffer, format, offset);
}

pub inline fn setResourceHeap(self: *Self, heap: Handle(Renderer.ResourceHeap)) void {
    self.vtable.setResourceHeap(self, heap);
}

pub inline fn setResource(
    self: *Self,
    index: u32,
    resource: Handle(Renderer.Resource),
) void {
    self.vtable.setResource(self, index, resource);
}

pub inline fn resetResourceSlots(
    self: *Self,
    resource_type: Renderer.Resource.ResourceType,
    first_slot: u32,
    count: u32,
    binding: Renderer.Resource.BindingInfo,
    stages: ?Renderer.Shader.ShaderStages,
) void {
    self.vtable.resetResourceSlots(
        self,
        resource_type,
        first_slot,
        count,
        binding,
        stages,
    );
}

pub inline fn beginRenderPass(
    self: *Self,
    render_target: Handle(Renderer.RenderTarget),
    render_pass: ?Handle(Renderer.RenderPass),
    clear_values: ?[]const ClearValue,
    swap_buffer_index: ?u32,
) void {
    self.vtable.beginRenderPass(
        self,
        render_target,
        render_pass,
        clear_values,
        swap_buffer_index,
    );
}

pub inline fn endRenderPass(self: *Self) void {
    self.vtable.endRenderPass(self);
}

pub inline fn clear(
    self: *Self,
    info: ClearInfo,
    clear_values: ?[]const AttachmentClear,
) void {
    self.vtable.clear(self, info, clear_values);
}

pub inline fn clearAttachments(
    self: *Self,
    attachments: []const AttachmentClear,
) void {
    self.vtable.clearAttachments(self, attachments);
}

pub inline fn setPipelineState(
    self: *Self,
    pipeline_state: Handle(Renderer.PipelineState),
) void {
    self.vtable.setPipelineState(self, pipeline_state);
}

pub inline fn setBlendFactor(self: *Self, blend_factor: [4]f32) void {
    self.vtable.setBlendFactor(self, blend_factor);
}

pub inline fn setStencilReference(
    self: *Self,
    reference: u32,
    face: ?StencilFace,
) void {
    self.vtable.setStencilReference(self, reference, face);
}

pub inline fn setUniforms(self: *Self, first: u32, uniforms: []const u8) void {
    self.vtable.setUniforms(self, first, uniforms);
}

pub inline fn beginQuery(
    self: *Self,
    query_heap: Handle(Renderer.QueryHeap),
    query_index: ?u32,
) void {
    self.vtable.beginQuery(self, query_heap, query_index);
}

pub inline fn endQuery(
    self: *Self,
    query_heap: Handle(Renderer.QueryHeap),
    query_index: ?u32,
) void {
    self.vtable.endQuery(self, query_heap, query_index);
}

pub inline fn beginRenderCondition(
    self: *Self,
    query_heap: Handle(Renderer.QueryHeap),
    query_index: ?u32,
    mode: ?RenderConditionMode,
) void {
    self.vtable.beginRenderCondition(self, query_heap, query_index, mode);
}

pub inline fn endRenderCondition(self: *Self) void {
    self.vtable.endRenderCondition(self);
}

pub inline fn beginStreamOutput(
    self: *Self,
    buffers: []const Handle(Renderer.Buffer),
) void {
    self.vtable.beginStreamOutput(self, buffers);
}

pub inline fn endStreamOutput(self: *Self) void {
    self.vtable.endStreamOutput(self);
}

pub inline fn draw(
    self: *Self,
    vertex_count: u32,
    first_vertex: u32,
) void {
    self.vtable.draw(self, vertex_count, first_vertex);
}

pub inline fn drawIndexed(
    self: *Self,
    index_count: u32,
    first_index: u32,
    vertex_offset: ?i32,
) void {
    self.vtable.drawIndexed(self, index_count, first_index, vertex_offset);
}

pub inline fn drawInstanced(
    self: *Self,
    vertex_count: u32,
    first_vertex: u32,
    instance_count: u32,
    first_instance: ?u32,
) void {
    self.vtable.drawInstanced(
        self,
        vertex_count,
        first_vertex,
        instance_count,
        first_instance,
    );
}

pub inline fn drawInstanceIndexed(
    self: *Self,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: ?i32,
    first_instance: ?u32,
) void {
    self.vtable.drawInstanceIndexed(
        self,
        index_count,
        instance_count,
        first_index,
        vertex_offset,
        first_instance,
    );
}

pub inline fn drawIndirect(
    self: *Self,
    buffer: Handle(Renderer.Buffer),
    offset: u64,
    draw_count: u32,
    stride: u32,
) void {
    self.vtable.drawIndirect(self, buffer, offset, draw_count, stride);
}

pub inline fn drawIndexedIndirect(
    self: *Self,
    buffer: Handle(Renderer.Buffer),
    offset: u64,
    draw_count: u32,
    stride: u32,
) void {
    self.vtable.drawIndexedIndirect(
        self,
        buffer,
        offset,
        draw_count,
        stride,
    );
}

pub inline fn dispatch(
    self: *Self,
    x: u32,
    y: u32,
    z: u32,
) void {
    self.vtable.dispatch(self, x, y, z);
}

pub inline fn dispatchIndirect(
    self: *Self,
    buffer: Handle(Renderer.Buffer),
    offset: u64,
) void {
    self.vtable.dispatchIndirect(self, buffer, offset);
}

pub inline fn pushDebugGroup(self: *Self, name: []const u8) void {
    self.vtable.pushDebugGroup(self, name);
}

pub inline fn popDebugGroup(self: *Self) void {
    self.vtable.popDebugGroup(self);
}
