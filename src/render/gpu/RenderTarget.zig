const std = @import("std");

const Renderer = @import("Renderer.zig");
const Handle = @import("pool.zig").Handle;

const Self = @This();

pub const max_num_colour_attachments = 8;

pub const AttachmentCreateInfo = struct {
    format: Renderer.format.Format = .undefined,
    //TODO: texture: ?Handle(Texture) = null,
    mip_level: u32 = 0,
    /// only valid when there is a bound texture,
    array_layer: u32 = 0,
};

pub const RenderTargetCreateInfo = struct {
    //TODO: render_pass: ?Handle(RenderPass) = null,
    resolution: [2]u32 = .{ 0, 0 },
    samples: u32 = 1,
    colour_attachments: [max_num_colour_attachments]AttachmentCreateInfo = .{.{}} ** max_num_colour_attachments,
    resolve_attachments: [max_num_colour_attachments]AttachmentCreateInfo = .{.{}} ** max_num_colour_attachments,
    depth_stencil_attachment: AttachmentCreateInfo = .{ .format = .undefined },
};

impl: struct {
    parent: *anyopaque,
    getResolution: fn (*const anyopaque) [2]u32,
    getSamples: fn (*const anyopaque) u32,
    getNumColourAttachments: fn (*const anyopaque) u32,
    hasDepthAttachment: fn (*const anyopaque) bool,
    hasStencilAttachment: fn (*const anyopaque) bool,
    // getRenderPass: fn(*const anyopaque) ?Handle(Renderer.RenderPass),
},

pub fn getResolution(self: *const Self) [2]u32 {
    return self.getResolution(self.parent);
}

pub fn getSamples(self: *const Self) u32 {
    return self.getSamples(self.parent);
}

pub fn getNumColourAttachments(self: *const Self) u32 {
    return self.getNumColourAttachments(self.parent);
}

pub fn hasDepthAttachment(self: *const Self) bool {
    return self.hasDepthAttachment(self.parent);
}

pub fn hasStencilAttachment(self: *const Self) bool {
    return self.hasStencilAttachment(self.parent);
}

// TODO: pub fn getRenderPass(self: *const Self) ?Handle(Renderer.RenderPass)

pub fn validateResolution(self: *Self, resolution: [2]u32) !void {
    if (resolution[0] == 0 or resolution[1] == 0) {
        return error.InvalidResolution;
    }

    const target = self.getResolution();
    if (resolution[0] != target[0] or resolution[1] != target[1]) {
        return error.InvalidResolution;
    }
}

// pub fn validateMipResolution(self: *Self, renderer: *Renderer, texture: Handle(Texture), mip_level: u32) !void {
//     const size = renderer.textureGetMipExtent(texture, mip_level);
//     try self.validateResolution(size);
// }
