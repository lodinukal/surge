const std = @import("std");
const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const d3dcommon = @import("../d3d/common.zig");

// Loading
pub const procs: gpu.impl.Procs = .{
    // Adapter
    // BindGroup
    // BindGroupLayout
    // Buffer
    // CommandBuffer
    // CommandEncoder
    // ComputePassEncoder
    // ComputePipeline
    // Device
    // Instance
    .createInstance = createInstance,
    .instanceCreateSurface = instanceCreateSurface,
    .destroyInstance = destroyInstance,
    // PipelineLayout
    // QuerySet
    // Queue
    // RenderBundle
    // RenderBundleEncoder
    // RenderPassEncoder
    // RenderPipeline
    // Sampler
    // ShaderModule
    // Surface
    .destroySurface = destroySurface,
    // Texture
    // TextureView
};

export fn getProcs() *const gpu.impl.Procs {
    return &procs;
}

// Adapter
// BindGroup
// BindGroupLayout
// Buffer
// CommandBuffer
// CommandEncoder
// ComputePassEncoder
// ComputePipeline
// Device
// Instance
pub fn createInstance(alloc: std.mem.Allocator) gpu.Instance.Error!*gpu.Instance {
    std.debug.print("creating instance...\n", .{});
    return @ptrCast(D3D11Instance.init(alloc) catch
        return gpu.Instance.Error.InstanceFailedToCreate);
}

pub fn instanceCreateSurface(
    instance: *gpu.Instance,
    desc: *const gpu.Surface.Descriptor,
) gpu.Surface.Error!*gpu.Surface {
    std.debug.print("creating surface...\n", .{});
    return try D3D11Surface.init(instance, desc);
}

pub fn destroyInstance(instance: *gpu.Instance) void {
    std.debug.print("destroying instance...\n", .{});
    D3D11Instance.deinit(@alignCast(@ptrCast(instance)));
}

var allocator: std.mem.Allocator = undefined;
pub const D3D11Instance = struct {
    factory: ?*dxgi.IDXGIFactory1 = null,

    pub fn init(alloc: std.mem.Allocator) !*D3D11Instance {
        allocator = alloc;
        const self = allocator.create(D3D11Instance) catch return gpu.Instance.Error.InstanceFailedToCreate;
        errdefer self.deinit();
        self.* = .{};

        const hr = dxgi.CreateDXGIFactory(dxgi.IID_IDXGIFactory, @ptrCast(&self.factory));
        if (d3dcommon.checkHResult(hr)) return gpu.Instance.Error.InstanceFailedToCreate;

        return @ptrCast(self);
    }

    pub fn deinit(self: *D3D11Instance) void {
        d3dcommon.releaseIUnknown(dxgi.IDXGIFactory1, &self.factory);
        allocator.destroy(self);
    }
};
// PipelineLayout
// QuerySet
// Queue
// RenderBundle
// RenderBundleEncoder
// RenderPassEncoder
// RenderPipeline
// Sampler
// ShaderModule
// Surface
pub fn destroySurface(surface: *gpu.Surface) void {
    std.debug.print("destroying surface...\n", .{});
    D3D11Surface.deinit(@alignCast(@ptrCast(surface)));
}

pub const D3D11Surface = struct {
    hwnd: ?win32.foundation.HWND = null,

    pub fn init(instance: *gpu.Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface {
        _ = instance;
        const self = allocator.create(D3D11Surface) catch return gpu.Surface.Error.SurfaceFailedToCreate;
        self.* = .{
            .hwnd = desc.native_handle,
        };
        return @ptrCast(self);
    }

    pub fn deinit(self: *D3D11Surface) void {
        allocator.destroy(self);
    }
};
// Texture
// TextureView
