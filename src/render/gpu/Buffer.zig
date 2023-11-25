const std = @import("std");

const Renderer = @import("Renderer.zig");
const Resource = Renderer.Resource;

const Self = @This();

resource: Resource = undefined,

fn_getBufferDescriptor: ?*const fn (*const Self) BufferDescriptor = null,

binding: Resource.BindingInfo = .{},

pub const BufferDescriptor = struct {
    size: u64 = 0,
    /// only supported in d3d11/12, will ignore format if stride is non zero
    stride: u32 = 0,
    format: Renderer.format.Format = .undefined,
    binding: Resource.BindingInfo = .{},
    cpu_access: Resource.CPUAccess = .{},
    info: Resource.ResourceInfo = .{},
    vertex_attributes: ?[]const Renderer.VertexAttribute = null,

    pub fn isTypedBuffer(self: BufferDescriptor) bool {
        return self.stride == 0 and self.format != .undefined and
            self.binding.sampled and self.binding.storage;
    }

    pub fn isStructuredBuffer(self: BufferDescriptor) bool {
        return self.stride > 0 and
            self.binding.sampled and self.binding.storage;
    }

    pub fn isByteAddressBuffer(self: BufferDescriptor) bool {
        return self.stride == 0 and self.format == .undefined and
            self.binding.sampled and self.binding.storage;
    }

    pub fn getStride(self: BufferDescriptor) u32 {
        if (self.stride > 0) return self.stride;
        if (self.format != .undefined) return @divExact(Renderer.format.getFormatAttributes(self.format).?.bit_size, 8);
        return 1;
    }
};

pub const BufferViewDescriptor = struct {
    format: Renderer.format.Format = .undefined,
    offset: u64 = 0,
    size: ?u64 = null, // if null then uses whole buffer size
};

pub fn init(self: *Self, binding: Resource.BindingInfo) Renderer.Error!void {
    self.* = .{
        .resource = .{
            .fn_getResourceType = _getResourceType,
        },
        .binding = binding,
    };
}

fn _getResourceType(self: *const Resource) Resource.ResourceType {
    _ = self;
    return .buffer;
}

pub fn getBindingInfo(self: Self) Resource.BindingInfo {
    return self.binding;
}

pub fn getCombinedBindings(buffers: []*const Self) Resource.BindingInfo {
    var binding: Resource.BindingInfo = .{};
    for (buffers) |buffer| {
        const this_binding = buffer.getBindingInfo();
        binding.vertex_buffer = binding.vertex_buffer or this_binding.vertex_buffer;
        binding.index_buffer = binding.index_buffer or this_binding.index_buffer;
        binding.constant_buffer = binding.constant_buffer or this_binding.constant_buffer;
        binding.stream_output_buffer = binding.stream_output_buffer or this_binding.stream_output_buffer;
        binding.indirect_command_buffer = binding.indirect_command_buffer or this_binding.indirect_command_buffer;

        binding.sampled = binding.sampled or this_binding.sampled;
        binding.storage = binding.storage or this_binding.storage;

        binding.colour_attachment = binding.colour_attachment or this_binding.colour_attachment;
        binding.depth_stencil_attachment = binding.depth_stencil_attachment or this_binding.depth_stencil_attachment;

        binding.combined_sampler = binding.combined_sampler or this_binding.combined_sampler;

        binding.copy_source = binding.copy_source or this_binding.copy_source;
        binding.copy_destination = binding.copy_destination or this_binding.copy_destination;
    }
    return binding;
}

pub fn getBufferDescriptor(self: *const Self) BufferDescriptor {
    if (self.fn_getBufferDescriptor) |f| return f(self);
    unreachable;
}
