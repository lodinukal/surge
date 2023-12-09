const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const CommandEncoder = opaque {
    pub const Error = error{
        CommandEncoderFailedToCreate,
        CommandEncoderFailedToFinish,
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
    };

    pub inline fn beginRenderPass(self: *CommandEncoder, desc: *const gpu.RenderPass.Descriptor) !*gpu.RenderPass.Encoder {
        return impl.commandEncoderBeginRenderPass(self, desc);
    }

    pub inline fn finish(
        self: *CommandEncoder,
        desc: ?*const gpu.CommandBuffer.Descriptor,
    ) !*gpu.CommandBuffer {
        return impl.commandEncoderFinish(self, desc);
    }

    pub inline fn destroy(self: *CommandEncoder) void {
        impl.commandEncoderDestroy(self);
    }
};
