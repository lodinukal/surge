const std = @import("std");

const Self = @This();

const Window = @import("app").Window;
const RenderContext = @import("renderer.zig").RenderContext;
allocator: std.mem.Allocator = undefined,
base_ren: RenderContext = undefined,

ready: bool = false,

pub fn init(self: *Self, allocator: std.mem.Allocator, window: *Window) !void {
    try self.base_ren.init(allocator, window, .d3d12);
    self.ready = true;
}

pub fn deinit(self: *Self) void {
    self.base_ren.deinit();
}

pub fn resize(self: *Self, size: [2]u32) !void {
    try self.base_ren.resize(size);
}

pub fn frame(self: *Self) !void {
    try self.base_ren.beginFrame();
    try self.geometry();
    try self.base_ren.endFrame();
}

fn geometry(self: *Self) !void {
    const rpe = try self.base_ren.beginRenderPass("geometry");

    try self.base_ren.endRenderPass(rpe);
}

pub fn present(self: *Self) !void {
    try self.base_ren.present();
}
