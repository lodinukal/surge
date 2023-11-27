const std = @import("std");
const gpu = @import("gpu.zig");

const ProcFn = *const fn () callconv(.C) ?*const Procs;
pub const Procs = struct {
    pub var loaded_procs: ?*const Procs = null;

    // Adapter
    adapterCreateDevice: *const fn (adapter: *gpu.Adapter, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device,
    adapterGetProperties: *const fn (adapter: *gpu.Adapter, out_props: *gpu.Adapter.Properties) bool,
    destroyAdapter: *const fn (adapter: *gpu.Adapter) void,
    // BindGroup
    // BindGroupLayout
    // Buffer
    // CommandBuffer
    // CommandEncoder
    // ComputePassEncoder
    // ComputePipeline
    // Device
    destroyDevice: *const fn (device: *gpu.Device) void,
    // Instance
    createInstance: *const fn (allocator: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance,
    instanceCreateSurface: *const fn (instance: *gpu.Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface,
    instanceRequestAdapter: *const fn (instance: *gpu.Instance, options: *const gpu.Adapter.Options) gpu.Adapter.Error!*gpu.Adapter,
    destroyInstance: *const fn (instance: *gpu.Instance) void,
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
    destroySurface: *const fn (surface: *gpu.Surface) void,
    // Texture
    // TextureView
};

var dynamic_lib: ?std.DynLib = null;
pub fn loadBackend(backend: gpu.BackendType) bool {
    switch (backend) {
        .undefined => return false,
        .null => return false,
        .webgpu => return false,
        .d3d11 => {
            dynamic_lib = std.DynLib.open("render_d3d11") catch return false;
            if (dynamic_lib == null) return false;
            const getter = dynamic_lib.?.lookup(ProcFn, "getProcs") orelse return false;
            Procs.loaded_procs = getter() orelse return false;
            return true;
        },
        .d3d12 => return false,
        .metal => return false,
        .vulkan => return false,
        .opengl => return false,
        .opengles => return false,
    }
}

pub fn closeBackend() void {
    if (dynamic_lib) |dl| {
        dl.close();
        dynamic_lib = null;
    }
}

// Adapter
pub inline fn adapterCreateDevice(adapter: *gpu.Adapter, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device {
    return Procs.loaded_procs.?.adapterCreateDevice(adapter, desc);
}

pub inline fn adapterGetProperties(adapter: *gpu.Adapter, out_props: *gpu.Adapter.Properties) bool {
    return Procs.loaded_procs.?.adapterGetProperties(adapter, out_props);
}

pub inline fn destroyAdapter(adapter: *gpu.Adapter) void {
    return Procs.loaded_procs.?.destroyAdapter(adapter);
}

// Device
pub inline fn destroyDevice(device: *gpu.Device) void {
    return Procs.loaded_procs.?.destroyDevice(device);
}

// Instance
pub inline fn createInstance(
    allocator: std.mem.Allocator,
    desc: *const gpu.Instance.Descriptor,
) gpu.Instance.Error!*gpu.Instance {
    return Procs.loaded_procs.?.createInstance(allocator, desc);
}

pub inline fn instanceCreateSurface(
    instance: *gpu.Instance,
    desc: *const gpu.Surface.Descriptor,
) gpu.Surface.Error!*gpu.Surface {
    return Procs.loaded_procs.?.instanceCreateSurface(instance, desc);
}

pub inline fn instanceRequestAdapter(
    instance: *gpu.Instance,
    options: *const gpu.Adapter.Options,
) gpu.Adapter.Error!*gpu.Adapter {
    return Procs.loaded_procs.?.instanceRequestAdapter(instance, options);
}

pub inline fn destroyInstance(instance: *gpu.Instance) void {
    return Procs.loaded_procs.?.destroyInstance(instance);
}

// Surface
pub inline fn destroySurface(surface: *gpu.Surface) void {
    return Procs.loaded_procs.?.destroySurface(surface);
}
