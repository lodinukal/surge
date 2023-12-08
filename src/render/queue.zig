const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Queue = opaque {
    pub const Error = error{
        QueueFailedToCreate,
        QueueFailedToSubmit,
        QueueFailure,
    };

    pub const Descriptor = struct {
        label: []const u8,
    };

    pub inline fn submit(
        self: *Queue,
        command_buffers: []const *gpu.CommandBuffer,
    ) !void {
        try impl.queueSubmit(self, command_buffers);
    }

    pub inline fn writeBuffer(
        self: *Queue,
        buffer: *gpu.Buffer,
        buffer_offset_bytes: u64,
        comptime T: type,
        data: []const T,
    ) !void {
        try impl.queueWriteBuffer(
            self,
            buffer,
            buffer_offset_bytes,
            T,
            data,
        );
    }

    pub inline fn writeTexture(
        self: *gpu.Queue,
        destination: *gpu.ImageCopyTexture,
        comptime T: type,
        data: []const T,
        data_layout: *const gpu.Texture.DataLayout,
        size: *const gpu.Extent3D,
    ) !void {
        try impl.queueWriteTexture(
            self,
            destination,
            T,
            data,
            data_layout,
            size,
        );
    }
};
