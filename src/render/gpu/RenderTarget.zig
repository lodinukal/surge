const std = @import("std");

const Renderer = @import("Renderer.zig");
const Handle = @import("pool.zig").Handle;

const Self = @This();

pub const max_num_colour_attachments = 8;

pub const AttachmentDescriptor = struct {
    format: Renderer.format.Format = .undefined,
    //TODO: texture: ?Handle(Texture) = null,
    mip_level: u32 = 0,
    /// only valid when there is a bound texture,
    array_layer: u32 = 0,
};

pub const RenderTargetDescriptor = struct {
    //TODO: render_pass: ?Handle(RenderPass) = null,
    resolution: [2]u32 = .{ 0, 0 },
    samples: u32 = 1,
    colour_attachments: [max_num_colour_attachments]AttachmentDescriptor = .{.{}} ** max_num_colour_attachments,
    resolve_attachments: [max_num_colour_attachments]AttachmentDescriptor = .{.{}} ** max_num_colour_attachments,
    depth_stencil_attachment: AttachmentDescriptor = .{ .format = .undefined },
};

fn_getResolution: ?*const fn (*const Self) [2]u32 = null,
fn_getSamples: ?*const fn (*const Self) u32 = null,
fn_getNumColourAttachments: ?*const fn (*const Self) u32 = null,
fn_hasDepthAttachment: ?*const fn (*const Self) bool = null,
fn_hasStencilAttachment: ?*const fn (*const Self) bool = null,
// getRenderPass: fn(*const Self) ?Handle(Renderer.RenderPass),

pub fn getResolution(self: *const Self) [2]u32 {
    return self.fn_getResolution.?(self);
}

pub fn getSamples(self: *const Self) u32 {
    return self.fn_getSamples.?(self);
}

pub fn getNumColourAttachments(self: *const Self) u32 {
    return self.fn_getNumColourAttachments.?(self);
}

pub fn hasDepthAttachment(self: *const Self) bool {
    return self.fn_hasDepthAttachment.?(self);
}

pub fn hasStencilAttachment(self: *const Self) bool {
    return self.fn_hasStencilAttachment.?(self);
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

test {
    std.testing.refAllDecls(Self);
}
