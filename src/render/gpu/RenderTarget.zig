const std = @import("std");

const Renderer = @import("Renderer.zig");
const Handle = @import("pool.zig").Handle;

const Self = @This();

pub const AttachmentDescriptor = struct {
    format: Renderer.format.Format = .undefined,
    texture: ?Handle(Renderer.Texture) = null,
    mip_level: u32 = 0,
    /// only valid when there is a bound texture,
    array_layer: u32 = 0,

    pub fn isAttachmentEnabled(self: AttachmentDescriptor) bool {
        return self.format != .undefined or self.texture != null;
    }

    pub fn getAttachmentFormat(self: AttachmentDescriptor) Renderer.format.Format {
        if (self.format != .undefined) return self.format;
        // Renderer.getTextureFormat(self.texture);
        // if (self.texture) |t|
        return .undefined;
    }
};

pub const RenderTargetDescriptor = struct {
    render_pass: ?Handle(Renderer.RenderPass) = null,
    resolution: [2]u32 = .{ 0, 0 },
    samples: u32 = 1,
    colour_attachments: [Renderer.max_num_colour_attachments]AttachmentDescriptor = .{.{}} ** Renderer.max_num_colour_attachments,
    resolve_attachments: [Renderer.max_num_colour_attachments]AttachmentDescriptor = .{.{}} ** Renderer.max_num_colour_attachments,
    depth_stencil_attachment: AttachmentDescriptor = .{ .format = .undefined },
};

vtable: *const struct {
    getResolution: *const fn (*const Self) [2]u32 = undefined,
    getSamples: *const fn (*const Self) u32 = undefined,
    getNumColourAttachments: *const fn (*const Self) u32 = undefined,
    hasDepthAttachment: *const fn (*const Self) bool = undefined,
    hasStencilAttachment: *const fn (*const Self) bool = undefined,
    getRenderPass: fn (*const Self) ?Handle(Renderer.RenderPass) = undefined,
},

pub fn getResolution(self: *const Self) [2]u32 {
    return self.vtable.getResolution(self);
}

pub fn getSamples(self: *const Self) u32 {
    return self.vtable.getSamples(self);
}

pub fn getNumColourAttachments(self: *const Self) u32 {
    return self.vtable.getNumColourAttachments(self);
}

pub fn hasDepthAttachment(self: *const Self) bool {
    return self.vtable.hasDepthAttachment(self);
}

pub fn hasStencilAttachment(self: *const Self) bool {
    return self.vtable.hasStencilAttachment(self);
}

pub fn getRenderPass(self: *const Self) ?Handle(Renderer.RenderPass) {
    return self.vtable.getRenderPass(self);
}

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
