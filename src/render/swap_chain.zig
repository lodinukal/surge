const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const SwapChain = opaque {
    pub const Error = error{
        SwapChainFailedToCreate,
        SwapChainFailedToPresent,
        SwapChainFailedToResize,
    };

    pub const PresentMode = enum(u32) {
        immediate = 0x00000000,
        mailbox = 0x00000001,
        fifo = 0x00000002,
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        usage: gpu.Texture.UsageFlags,
        format: gpu.Texture.Format,
        width: u32,
        height: u32,
        present_mode: PresentMode,
    };

    pub inline fn getIndex(self: *SwapChain) u32 {
        return impl.swapChainGetIndex(self);
    }

    pub inline fn getCurrentTexture(self: *SwapChain) ?*gpu.Texture {
        return try impl.swapChainGetCurrentTexture(self);
    }

    pub inline fn getCurrentTextureView(self: *SwapChain) ?*const gpu.TextureView {
        return impl.swapChainGetCurrentTextureView(self);
    }

    pub inline fn getTextureViews(self: *SwapChain, views: *[3]?*const gpu.TextureView) !u32 {
        return try impl.swapChainGetTextureViews(self, views);
    }

    pub inline fn present(self: *SwapChain) !void {
        return try impl.swapChainPresent(self);
    }

    pub inline fn resize(self: *SwapChain, size: [2]u32) !bool {
        return try impl.swapChainResize(self, size);
    }

    pub inline fn destroy(self: *SwapChain) void {
        return impl.swapChainDestroy(self);
    }
};
