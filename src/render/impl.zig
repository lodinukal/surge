const std = @import("std");
const gpu = @import("gpu.zig");

const ProcFn = *const fn () callconv(.C) ?*const Procs;
pub const Procs = struct {
    pub var loaded_procs: ?*const Procs = null;

    // BindGroup
    // BindGroupLayout
    // Buffer
    bufferDestroy: *const fn (buffer: *gpu.Buffer) void,
    // CommandBuffer
    commandBufferDestroy: *const fn (command_buffer: *gpu.CommandBuffer) void,
    // CommandEncoder
    commandEncoderFinish: *const fn (
        command_encoder: *gpu.CommandEncoder,
        desc: *const gpu.CommandBuffer.Descriptor,
    ) gpu.CommandBuffer.Error!*gpu.CommandBuffer,
    commandEncoderDestroy: *const fn (command_encoder: *gpu.CommandEncoder) void,
    // ComputePassEncoder
    // ComputePipeline
    // Device
    deviceGetQueue: *const fn (device: *gpu.Device) *gpu.Queue,
    deviceCreateBuffer: *const fn (device: *gpu.Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer,
    deviceDestroy: *const fn (device: *gpu.Device) void,
    // Instance
    createInstance: *const fn (allocator: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance,
    instanceCreateSurface: *const fn (instance: *gpu.Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface,
    instanceRequestPhysicalDevice: *const fn (instance: *gpu.Instance, options: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice,
    instanceDestroy: *const fn (instance: *gpu.Instance) void,
    // PhysicalDevice
    physicalDeviceCreateDevice: *const fn (physicalDevice: *gpu.PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device,
    physicalDeviceGetProperties: *const fn (physicalDevice: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool,
    physicalDeviceDestroy: *const fn (physicalDevice: *gpu.PhysicalDevice) void,
    // PipelineLayout
    // QuerySet
    // Queue
    queueSubmit: *const fn (
        queue: *gpu.Queue,
        command_buffers: []const *gpu.CommandBuffer,
    ) gpu.Queue.Error!void,
    // RenderBundle
    // RenderBundleEncoder
    // RenderPassEncoder
    // RenderPipeline
    // Sampler
    // ShaderModule
    // Surface
    surfaceDestroy: *const fn (surface: *gpu.Surface) void,
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

// Buffer
pub inline fn bufferDestroy(buffer: *gpu.Buffer) void {
    return Procs.loaded_procs.?.bufferDestroy(buffer);
}

// CommandBuffer
pub inline fn commandBufferDestroy(command_buffer: *gpu.CommandBuffer) void {
    return Procs.loaded_procs.?.commandBufferDestroy(command_buffer);
}

// CommandEncoder
pub inline fn commandEncoderDestroy(command_encoder: *gpu.CommandEncoder) void {
    return Procs.loaded_procs.?.commandEncoderDestroy(command_encoder);
}

// Device
pub inline fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
    return Procs.loaded_procs.?.deviceGetQueue(device);
}

pub inline fn deviceCreateBuffer(device: *gpu.Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer {
    return Procs.loaded_procs.?.deviceCreateBuffer(device, desc);
}

pub inline fn deviceDestroy(device: *gpu.Device) void {
    return Procs.loaded_procs.?.deviceDestroy(device);
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

pub inline fn instanceRequestPhysicalDevice(
    instance: *gpu.Instance,
    options: *const gpu.PhysicalDevice.Options,
) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
    return Procs.loaded_procs.?.instanceRequestPhysicalDevice(instance, options);
}

pub inline fn instanceDestroy(instance: *gpu.Instance) void {
    return Procs.loaded_procs.?.instanceDestroy(instance);
}

// PhysicalDevice
pub inline fn physicalDeviceCreateDevice(physicalDevice: *gpu.PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device {
    return Procs.loaded_procs.?.physicalDeviceCreateDevice(physicalDevice, desc);
}

pub inline fn physicalDeviceGetProperties(physicalDevice: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
    return Procs.loaded_procs.?.physicalDeviceGetProperties(physicalDevice, out_props);
}

pub inline fn physicalDeviceDestroy(physicalDevice: *gpu.PhysicalDevice) void {
    return Procs.loaded_procs.?.physicalDeviceDestroy(physicalDevice);
}

// Queue
pub inline fn queueSubmit(
    queue: *gpu.Queue,
    command_buffers: []const *gpu.CommandBuffer,
) gpu.Queue.Error!void {
    return Procs.loaded_procs.?.queueSubmit(queue, command_buffers);
}

// Surface
pub inline fn surfaceDestroy(surface: *gpu.Surface) void {
    return Procs.loaded_procs.?.surfaceDestroy(surface);
}
