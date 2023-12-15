const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const RenderPipeline = opaque {
    pub const Error = error{
        RenderPipelineFailedToCreate,
    } || gpu.ShaderModule.Error;

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        layout: ?*gpu.PipelineLayout = null,
        vertex: gpu.VertexState,
        primitive: gpu.PrimitiveState = .{},
        depth_stencil: ?*const gpu.DepthStencilState = null,
        multisample: gpu.MultisampleState = .{},
        fragment: ?*const gpu.FragmentState = null,
    };

    pub inline fn destroy(self: *RenderPipeline) void {
        impl.renderPipelineDestroy(self);
    }
};
