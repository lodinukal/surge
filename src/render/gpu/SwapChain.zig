const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");
const Handle = @import("pool.zig").Handle;

const RenderTarget = @import("RenderTarget.zig");

const Self = @This();

render_target: RenderTarget,

fn_present: ?*const fn (*Self) Renderer.Error!void = null,
fn_getCurrentSwapIndex: ?*const fn (*const Self) u32 = null,
fn_getNumSwapBuffers: ?*const fn (*const Self) u32 = null,
fn_getColourFormat: ?*const fn (*const Self) Renderer.format.Format = null,
fn_getDepthStencilFormat: ?*const fn (*const Self) Renderer.format.Format = null,
fn_resizeBuffers: ?*const fn (*Self, [2]u32) Renderer.Error!void = null,

surface: ?*app.window.Window = null,
resolution: [2]u32 = .{ 0, 0 },

pub const SwapChainCreateInfo = struct {
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

pub fn init(self: *Self, create_info: *const SwapChainCreateInfo) !void {
    _ = create_info;

    self.* = .{
        .render_target = .{
            .fn_getResolution = &_getResolution,
            .fn_getNumColourAttachments = &_getNumColourAttachments,
            .fn_hasDepthAttachment = &_hasDepthAttachment,
            .fn_hasStencilAttachment = &_hasStencilAttachment,
        },
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
    if (self.fn_present) |f| f(self) catch {};
}

pub fn getCurrentSwapIndex(self: *const Self) u32 {
    if (self.fn_getCurrentSwapIndex) |f| return f(self);
    unreachable;
}

pub fn getNumSwapBuffers(self: *const Self) u32 {
    if (self.fn_getNumSwapBuffers) |f| return f(self);
    unreachable;
}

pub fn getColourFormat(self: *const Self) Renderer.format.Format {
    if (self.fn_getColourFormat) |f| return f(self);
    unreachable;
}

pub fn getDepthStencilFormat(self: *const Self) Renderer.format.Format {
    if (self.fn_getDepthStencilFormat) |f| return f(self);
    unreachable;
}

pub fn resizeBuffers(self: *Self, resolution: [2]u32, resize_info: SwapChainResizeInfo) Renderer.Error!void {
    if (resize_info.modify_surface) {
        if (self.surface) |s| {
            s.setFullscreenMode(if (resize_info.fullscreen) .fullscreen else .windowed);
            s.setSize(resolution, true);
            s.update();
            try self.fn_resizeBuffers.?(self, resolution);
            {
                self.resolution = resolution;
            }
        }
    } else {
        try self.fn_resizeBuffers.?(self, resolution);
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
