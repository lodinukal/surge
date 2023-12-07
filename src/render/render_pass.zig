const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Descriptor = struct {
    label: ?[]const u8 = null,
    colour_attachments: ?[]const ColourAttachment = null,
    depth_stencil_attachment: ?DepthStencilAttachment = null,
    query_set: ?*gpu.QuerySet = null,
    timestamp_writes: ?[]const TimestampWrite = null,
};

pub const ColourAttachment = struct {
    view: ?*gpu.TextureView = null,
    resolve_target: ?*gpu.TextureView = null,
    load_op: gpu.LoadOp = .undefined,
    store_op: gpu.StoreOp = .undefined,
    clear_value: gpu.Colour = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
};

pub const DepthStencilAttachment = struct {
    view: *gpu.TextureView,
    depth_load_op: gpu.LoadOp = .undefined,
    depth_store_op: gpu.StoreOp = .undefined,
    depth_clear_value: f32 = 0,
    depth_read_only: bool = false,
    stencil_load_op: gpu.LoadOp = .undefined,
    stencil_store_op: gpu.StoreOp = .undefined,
    stencil_clear_value: u32 = 0,
    stencil_read_only: bool = false,
};

pub const TimestampWrite = extern struct {
    query_set: *gpu.QuerySet,
    query_index: u32,
    location: gpu.RenderPassTimestampLocation,
};

pub const Encoder = opaque {
    pub const Error = error{
        RenderPassEncoderFailedToCreate,
        RenderPassEncoderFailedToEnd,
    };

    pub inline fn draw(
        self: *Encoder,
        vertex_count: u32,
        instance_count: ?u32,
        first_vertex: ?u32,
        first_instance: ?u32,
    ) void {
        impl.renderPassEncoderDraw(
            self,
            vertex_count,
            instance_count orelse 1,
            first_vertex orelse 0,
            first_instance orelse 0,
        );
    }

    pub inline fn drawIndexed(
        self: *Encoder,
        index_count: u32,
        instance_count: ?u32,
        first_index: ?u32,
        base_vertex: ?i32,
        first_instance: ?u32,
    ) void {
        impl.renderPassEncoderDrawIndexed(
            self,
            index_count,
            instance_count orelse 1,
            first_index orelse 0,
            base_vertex orelse 0,
            first_instance orelse 0,
        );
    }

    pub inline fn drawIndexedIndirect(self: *Encoder, buffer: *gpu.Buffer, indirect_offset: u64) void {
        impl.renderPassEncoderDrawIndexedIndirect(
            self,
            buffer,
            indirect_offset,
        );
    }

    pub inline fn drawIndirect(self: *Encoder, buffer: *gpu.Buffer, indirect_offset: u64) void {
        impl.renderPassEncoderDrawIndirect(
            self,
            buffer,
            indirect_offset,
        );
    }

    pub inline fn end(
        self: *Encoder,
    ) !void {
        try impl.renderPassEncoderEnd(self);
    }

    pub inline fn executeBundles(
        self: *Encoder,
        bundles: []const *gpu.RenderBundle,
    ) void {
        impl.renderPassEncoderExecuteBundles(
            self,
            bundles,
        );
    }

    pub inline fn insertDebugMarker(
        self: *Encoder,
        label: []const u8,
    ) void {
        impl.renderPassEncoderInsertDebugMarker(
            self,
            label,
        );
    }

    pub inline fn popDebugGroup(
        self: *Encoder,
    ) void {
        impl.renderPassEncoderPopDebugGroup(self);
    }

    pub inline fn pushDebugGroup(
        self: *Encoder,
        label: []const u8,
    ) void {
        impl.renderPassEncoderPushDebugGroup(
            self,
            label,
        );
    }

    pub inline fn setBindGroup(
        self: *Encoder,
        index: u32,
        bind_group: *gpu.BindGroup,
        dynamic_offsets: ?[]const u32,
    ) void {
        impl.renderPassEncoderSetBindGroup(
            self,
            index,
            bind_group,
            dynamic_offsets,
        );
    }

    pub inline fn setBlendConstant(
        self: *Encoder,
        colour: gpu.Colour,
    ) void {
        impl.renderPassEncoderSetBlendConstant(
            self,
            colour,
        );
    }

    pub inline fn setIndexBuffer(
        self: *Encoder,
        buffer: *gpu.Buffer,
        format: gpu.IndexFormat,
        offset: u64,
        size: u64,
    ) void {
        impl.renderPassEncoderSetIndexBuffer(
            self,
            buffer,
            format,
            offset,
            size,
        );
    }

    pub inline fn setPipeline(
        self: *Encoder,
        pipeline: *gpu.RenderPipeline,
    ) void {
        impl.renderPassEncoderSetPipeline(
            self,
            pipeline,
        );
    }

    pub inline fn setScissorRect(
        self: *Encoder,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) void {
        impl.renderPassEncoderSetScissorRect(
            self,
            x,
            y,
            width,
            height,
        );
    }

    pub inline fn setStencilReference(
        self: *Encoder,
        reference: u32,
    ) void {
        impl.renderPassEncoderSetStencilReference(
            self,
            reference,
        );
    }

    pub inline fn setVertexBuffer(
        self: *Encoder,
        slot: u32,
        buffer: *gpu.Buffer,
        offset: u64,
        size: u64,
    ) void {
        impl.renderPassEncoderSetVertexBuffer(
            self,
            slot,
            buffer,
            offset,
            size,
        );
    }

    pub inline fn setViewport(
        self: *Encoder,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        min_depth: f32,
        max_depth: f32,
    ) void {
        impl.renderPassEncoderSetViewport(
            self,
            x,
            y,
            width,
            height,
            min_depth,
            max_depth,
        );
    }

    pub inline fn writeTimestamp(
        self: *Encoder,
        query_set: *gpu.QuerySet,
        query_index: u32,
    ) void {
        impl.renderPassEncoderWriteTimestamp(
            self,
            query_set,
            query_index,
        );
    }

    pub inline fn destroy(self: *Encoder) void {
        impl.renderPassEncoderDestroy(self);
    }
};
