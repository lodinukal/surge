const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");
const Handle = Renderer.Handle;
const RenderTarget = Renderer.RenderTarget;

const Self = @This();

render_target: RenderTarget,

vtable: *const struct {
    present: *const fn (*Self) Renderer.Error!void = undefined,
    getCurrentSwapIndex: *const fn (*const Self) u32 = undefined,
    getNumSwapBuffers: *const fn (*const Self) u32 = undefined,
    getColourFormat: *const fn (*const Self) Renderer.format.Format = undefined,
    getDepthStencilFormat: *const fn (*const Self) Renderer.format.Format = undefined,
    resizeBuffers: *const fn (*Self, [2]u32) Renderer.Error!void = undefined,
},

surface: ?*app.window.Window = null,
resolution: [2]u32 = .{ 0, 0 },

pub const SwapChainDescriptor = struct {
    resolution: [2]u32 = .{ 0, 0 },
    colour_bits: u32 = 32,
    depth_bits: u32 = 24,
    stencil_bits: u32 = 8,
    samples: u32 = 1,
    buffers: u32 = 2,
    fullscreen: bool = false,
};

pub const SwapChainResizeInfo = struct {
    modify_surface: bool = false,
    fullscreen: bool = false,
};

pub fn init(self: *Self, descriptor: *const SwapChainDescriptor) !void {
    _ = descriptor;

    self.* = .{
        .render_target = .{ .vtable = &.{
            .getResolution = &_getResolution,
            .getNumColourAttachments = &_getNumColourAttachments,
            .hasDepthAttachment = &_hasDepthAttachment,
            .hasStencilAttachment = &_hasStencilAttachment,
        } },
    };
}

pub inline fn fromBaseMut(rt: *RenderTarget) *Self {
    return @fieldParentPtr(Self, "render_target", rt);
}

pub inline fn fromBase(rt: *const RenderTarget) *const Self {
    return @fieldParentPtr(Self, "render_target", @constCast(rt));
}

// RenderTarget
fn _getResolution(rt: *const RenderTarget) [2]u32 {
    return fromBase(rt).getResolution();
}
pub inline fn getResolution(self: *const Self) [2]u32 {
    return self.resolution;
}

fn _getNumColourAttachments(rt: *const RenderTarget) u32 {
    return fromBase(rt).getNumColourAttachments();
}
pub inline fn getNumColourAttachments(self: *const Self) u32 {
    _ = self;
    return 1;
}

fn _hasDepthAttachment(rt: *const RenderTarget) bool {
    return fromBase(rt).hasDepthAttachment();
}
pub inline fn hasDepthAttachment(self: *const Self) bool {
    return Renderer.format.isDepthFormat(self.getDepthStencilFormat());
}

fn _hasStencilAttachment(rt: *const RenderTarget) bool {
    return fromBase(rt).hasStencilAttachment();
}
pub inline fn hasStencilAttachment(self: *const Self) bool {
    return Renderer.format.isStencilFormat(self.getDepthStencilFormat());
}

// SwapChain
pub fn present(self: *Self) void {
    self.vtable.present(self) catch {};
}

pub fn getCurrentSwapIndex(self: *const Self) u32 {
    return self.vtable.getCurrentSwapIndex(self);
}

pub fn getNumSwapBuffers(self: *const Self) u32 {
    return self.vtable.getNumSwapBuffers(self);
}

pub fn getColourFormat(self: *const Self) Renderer.format.Format {
    return self.vtable.getColourFormat(self);
}

pub fn getDepthStencilFormat(self: *const Self) Renderer.format.Format {
    return self.vtable.getDepthStencilFormat(self);
}

pub fn resizeBuffers(self: *Self, resolution: [2]u32, resize_info: SwapChainResizeInfo) Renderer.Error!void {
    if (resize_info.modify_surface) {
        if (self.surface) |s| {
            s.setFullscreenMode(if (resize_info.fullscreen) .fullscreen else .windowed);
            s.setSize(resolution, true);
            s.update();
            try self.vtable.resizeBuffers(self, resolution);
            {
                self.resolution = resolution;
            }
        }
    } else {
        try self.vtable.resizeBuffers(self, resolution);
        {
            self.resolution = resolution;
        }
    }
}

pub fn setSurface(self: *Self, surface: *app.window.Window) void {
    self.surface = surface;
    self.resolution = surface.getContentSize();
}

test {
    std.testing.refAllDecls(Self);
}
