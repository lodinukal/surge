const std = @import("std");

const Renderer = @import("Renderer.zig");

const Self = @This();

fn_getResourceType: ?*const fn (*const Self) ResourceType = null,

pub const ResourceType = enum {
    undefined,
    buffer,
    texture,
    sampler,
};

pub const BindingInfo = struct {
    vertex_buffer: bool = false,
    index_buffer: bool = false,
    constant_buffer: bool = false,
    stream_output_buffer: bool = false,
    indirect_command_buffer: bool = false,

    sampled: bool = false,
    storage: bool = false,

    colour_attachment: bool = false,
    depth_stencil_attachment: bool = false,

    combined_sampler: bool = false,

    copy_source: bool = false,
    copy_destination: bool = false,
};

pub const CPUAccess = struct {
    read: bool = false,
    write: bool = false,

    discard: bool = false,
};

pub const ResourceInfo = struct {
    dynamic: bool = false,
    fixed_samples: bool = false,
    generate_mips: bool = false,
    no_initial_data: bool = false,
    /// d3d11 and 12, append/consume structured buffer
    append: bool = false,
    /// d3d11 and 12, a hidden counter
    counter: bool = false,
};

pub fn getResouceType(self: *const Self) ResourceType {
    return self.fn_getResourceType.?(self);
}
