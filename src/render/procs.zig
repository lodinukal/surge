const std = @import("std");
const gpu = @import("gpu.zig");

pub const ProcFn = *const fn () callconv(.C) ?*const Procs;
pub const Procs = struct {
    pub var loaded_procs: ?*const Procs = null;

    // BindGroup
    // BindGroupLayout
    // Buffer
    bufferGetSize: *const fn (buffer: *gpu.Buffer) u64,
    bufferGetUsage: *const fn (buffer: *gpu.Buffer) gpu.Buffer.UsageFlags,
    bufferMap: *const fn (buffer: *gpu.Buffer) gpu.Buffer.Error!void,
    bufferUnmap: *const fn (buffer: *gpu.Buffer) void,
    bufferGetMappedRange: *const fn (buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]u8,
    bufferGetMappedRangeConst: *const fn (buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]const u8,
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
    deviceCreateBuffer: *const fn (device: *gpu.Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*gpu.Buffer,
    deviceGetQueue: *const fn (device: *gpu.Device) *gpu.Queue,
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
