const std = @import("std");
const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const TRUE = win32.foundation.TRUE;

const d3dcommon = @import("../d3d/common.zig");

const common = @import("../../core/common.zig");

// Loading
pub const procs: gpu.impl.Procs = .{
    // BindGroup
    // BindGroupLayout
    // Buffer
    // CommandBuffer
    .commandBufferDestroy = commandBufferDestroy,
    // CommandEncoder
    .commandEncoderFinish = commandEncoderFinish,
    .commandEncoderDestroy = commandEncoderDestroy,
    // ComputePassEncoder
    // ComputePipeline
    // Device
    .deviceGetQueue = deviceGetQueue,
    .deviceDestroy = deviceDestroy,
    // Instance
    .createInstance = createInstance,
    .instanceCreateSurface = instanceCreateSurface,
    .instanceRequestPhysicalDevice = instanceRequestPhysicalDevice,
    .instanceDestroy = instanceDestroy,
    // PhysicalDevice
    .physicalDeviceCreateDevice = physicalDeviceCreateDevice,
    .physicalDeviceGetProperties = physicalDeviceGetProperties,
    .physicalDeviceDestroy = physicalDeviceDestroy,
    // PipelineLayout
    // QuerySet
    // Queue
    .queueSubmit = queueSubmit,
    // RenderBundle
    // RenderBundleEncoder
    // RenderPassEncoder
    // RenderPipeline
    // Sampler
    // ShaderModule
    // Surface
    .surfaceDestroy = surfaceDestroy,
    // Texture
    // TextureView
};

export fn getProcs() *const gpu.impl.Procs {
    return &procs;
}

// BindGroup
// BindGroupLayout
// Buffer
pub fn deviceCreateBuffer(
    device: *gpu.Device,
    desc: *const gpu.Buffer.Descriptor,
) gpu.Buffer.Error!*gpu.Buffer {
    std.debug.print("creating buffer...\n", .{});
    return @ptrCast(try D3D11Buffer.init(@ptrCast(@alignCast(device)), desc));
}

pub const D3D11Buffer = struct {
    device: *D3D11Device,

    size: u64,
    allocated_size: u64 = 0,
    usage: gpu.Buffer.UsageFlags,
    state: gpu.Buffer.MapState = .unmapped,

    buffer: ?*d3d11.ID3D11Buffer = null,
    constant_buffer: ?*d3d11.ID3D11Buffer = null,
    constant_buffer_updated: bool = true,

    mapped: ?[]u8 = null,

    pub fn init(device: *D3D11Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*D3D11Buffer {
        const self = allocator.create(D3D11Buffer) catch return gpu.Buffer.Error.BufferFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .device = device,
            .size = desc.size,
            .usage = desc.usage,
        };

        const size = @max(self.size, if (self.usage.indirect) 12 else 4);
        const alignment = getBufferSizeAlignment(self.usage);
        if (size > std.math.maxInt(u32) - alignment) {
            return gpu.Buffer.Error.BufferSizeTooLarge;
        }

        self.allocated_size = gpu.util.alignUp(size, alignment);

        const needs_constant_buffer = self.usage.uniform;
        const needs_only_constant_buffer = needs_constant_buffer and self.usage.only(.{
            .uniform = true,
            .copy_dst = true,
            .copy_src = true,
        });

        if (!needs_only_constant_buffer) {
            var non_uniform_usage = self.usage;
            non_uniform_usage.uniform = false;
            var buffer_desc: d3d11.D3D11_BUFFER_DESC = .{
                .ByteWidth = @intCast(self.allocated_size),
                .Usage = getBufferUsage(non_uniform_usage),
                .BindFlags = getBufferBindFlags(non_uniform_usage),
                .CPUAccessFlags = getCpuAccessFlags(non_uniform_usage),
                .MiscFlags = getBufferMiscFlags(non_uniform_usage),
                .StructureByteStride = 0,
            };
            const hr = device.device.?.ID3D11Device_CreateBuffer(
                &buffer_desc,
                null,
                &self.buffer,
            );
            if (!d3dcommon.checkHResult(hr)) return gpu.Buffer.Error.BufferFailedToCreate;
        }

        if (needs_constant_buffer) {
            var constant_buffer_desc: d3d11.D3D11_BUFFER_DESC = .{
                .ByteWidth = @intCast(self.allocated_size),
                .Usage = .DEFAULT,
                .BindFlags = @intFromEnum(d3d11.D3D11_BIND_CONSTANT_BUFFER),
                .CPUAccessFlags = 0,
                .MiscFlags = 0,
                .StructureByteStride = 0,
            };
            const hr = device.device.?.ID3D11Device_CreateBuffer(
                &constant_buffer_desc,
                null,
                &self.constant_buffer,
            );
            if (!d3dcommon.checkHResult(hr)) return gpu.Buffer.Error.BufferFailedToCreate;
        }

        return self;
    }

    pub fn deinit(self: *D3D11Buffer) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.buffer);
        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.constant_buffer);
        allocator.destroy(self);
    }

    pub inline fn isUsageFlagsMappable(usage: gpu.Buffer.UsageFlags) bool {
        return usage.uniform or usage.copy_dst or usage.copy_src;
    }

    pub inline fn getBufferUsage(usage: gpu.Buffer.UsageFlags) d3d11.D3D11_USAGE {
        return if (isUsageFlagsMappable(usage)) .STAGING else .DEFAULT;
    }

    pub inline fn getBufferBindFlags(usage: gpu.Buffer.UsageFlags) d3d11.D3D11_BIND_FLAG {
        return d3d11.D3D11_BIND_FLAG.initFlags(.{
            .VERTEX_BUFFER = if (usage.vertex) 1 else 0,
            .INDEX_BUFFER = if (usage.index) 1 else 0,
            .CONSTANT_BUFFER = if (usage.uniform) 1 else 0,
            .UNORDERED_ACCESS = if (usage.storage) 1 else 0,
            .SHADER_RESOURCE = if (usage.readonly_storage) 1 else 0,
        });
    }

    pub inline fn getCpuAccessFlags(usage: gpu.Buffer.UsageFlags) d3d11.D3D11_CPU_ACCESS_FLAG {
        const is_mappable = isUsageFlagsMappable(usage);
        return d3d11.D3D11_CPU_ACCESS_FLAG.initFlags(.{
            .WRITE = if (is_mappable) 1 else 0,
            .READ = if (is_mappable) 1 else 0,
        });
    }

    pub inline fn getBufferMiscFlags(usage: gpu.Buffer.UsageFlags) d3d11.D3D11_RESOURCE_MISC_FLAG {
        return d3d11.D3D11_RESOURCE_MISC_FLAG.initFlags(.{
            .BUFFER_ALLOW_RAW_VIEWS = if (usage.storage) 1 else 0,
            .DRAWINDIRECT_ARGS = if (usage.indirect) 1 else 0,
        });
    }

    pub inline fn getBufferSizeAlignment(usage: gpu.Buffer.UsageFlags) u64 {
        return if (usage.uniform) 256 else if (usage.storage) 4 else 1;
    }
};

// CommandBuffer
pub fn commandBufferDestroy(command_buffer: *gpu.CommandBuffer) void {
    std.debug.print("destroying command buffer...\n", .{});
    D3D11CommandBuffer.deinit(@alignCast(@ptrCast(command_buffer)));
}

pub const D3D11CommandBuffer = struct {
    command_list: ?*d3d11.ID3D11CommandList = null,

    pub fn init(
        command_list: *d3d11.ID3D11CommandList,
        desc: *const gpu.CommandBuffer.Descriptor,
    ) gpu.CommandBuffer.Error!*D3D11CommandBuffer {
        _ = desc;

        const self = allocator.create(
            D3D11CommandBuffer,
        ) catch return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .command_list = command_list,
        };
        return self;
    }

    pub fn deinit(self: *D3D11CommandBuffer) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11CommandList, &self.command_list);
        allocator.destroy(self);
    }
};

// CommandEncoder
pub fn commandEncoderFinish(
    command_encoder: *gpu.CommandEncoder,
    desc: *const gpu.CommandBuffer.Descriptor,
) gpu.CommandBuffer.Error!*gpu.CommandBuffer {
    std.debug.print("finishing command encoder...\n", .{});
    return @ptrCast(try D3D11CommandEncoder.finish(@ptrCast(@alignCast(command_encoder)), desc));
}

pub fn commandEncoderDestroy(command_encoder: *gpu.CommandEncoder) void {
    std.debug.print("destroying command encoder...\n", .{});
    D3D11CommandEncoder.deinit(@alignCast(@ptrCast(command_encoder)));
}

pub const D3D11CommandEncoder = struct {
    device: *D3D11Device,
    deferred_context: ?*d3d11.ID3D11DeviceContext = null,

    pub fn init(device: *D3D11Device) gpu.CommandEncoder.Error!*D3D11CommandEncoder {
        const self = allocator.create(
            D3D11CommandEncoder,
        ) catch return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .device = device,
        };

        const hr = device.device.?.ID3D11Device_CreateDeferredContext(
            0,
            d3d11.IID_ID3D11DeviceContext1,
            @ptrCast(&self.deferred_context),
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D11CommandEncoder) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11DeviceContext, &self.deferred_context);
        allocator.destroy(self);
    }

    pub fn finish(self: *D3D11CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) gpu.CommandBuffer.Error!*D3D11CommandBuffer {
        var command_list: ?*d3d11.ID3D11CommandList = null;
        const hr = self.deferred_context.?.ID3D11DeviceContext_FinishCommandList(
            TRUE,
            &command_list,
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        return try D3D11CommandBuffer.init(command_list orelse
            return gpu.CommandBuffer.Error.CommandBufferFailedToCreate, desc);
    }
};

// ComputePassEncoder
// ComputePipeline
// Device
pub fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
    std.debug.print("getting queue...\n", .{});
    return D3D11Device.getQueue(@ptrCast(@alignCast(device)));
}

pub fn deviceDestroy(device: *gpu.Device) void {
    std.debug.print("destroying device...\n", .{});
    D3D11Device.deinit(@alignCast(@ptrCast(device)));
}

pub const D3D11Device = struct {
    extern "d3d11" fn D3D11CreateDevice(
        pPhysicalDevice: ?*dxgi.IDXGIAdapter,
        DriverType: d3d.D3D_DRIVER_TYPE,
        Software: ?win32.foundation.HMODULE,
        Flags: d3d11.D3D11_CREATE_DEVICE_FLAG,
        pFeatureLevels: ?[*]const d3d.D3D_FEATURE_LEVEL,
        FeatureLevels: u32,
        SDKVersion: u32,
        ppDevice: ?*?*d3d11.ID3D11Device,
        pFeatureLevel: ?*d3d.D3D_FEATURE_LEVEL,
        ppImmediateContext: ?*?*d3d11.ID3D11DeviceContext1,
    ) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

    physical_device: *D3D11PhysicalDevice,
    queue: *D3D11Queue,

    device: ?*d3d11.ID3D11Device = null, // PhysicalDevice
    debug_layer: ?*d3d11.ID3D11Debug = null,
    lost_cb: ?gpu.Device.LostCallback = null,

    pub fn init(physical_device: *D3D11PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*D3D11Device {
        const queue = allocator.create(D3D11Queue) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(queue);

        const self = allocator.create(D3D11Device) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .physical_device = physical_device,
            .queue = queue,
            .lost_cb = desc.lost_callback,
        };

        const feature_levels = [_]d3d.D3D_FEATURE_LEVEL{
            .@"11_0",
        };
        const hr = D3D11CreateDevice(
            self.physical_device.adapter,
            .UNKNOWN,
            null,
            d3d11.D3D11_CREATE_DEVICE_DEBUG,
            &feature_levels,
            feature_levels.len,
            d3d11.D3D11_SDK_VERSION,
            @ptrCast(&self.device),
            null,
            null,
        );
        errdefer d3dcommon.releaseIUnknown(d3d11.ID3D11Device, &self.device);
        if (!d3dcommon.checkHResult(hr)) return gpu.Device.Error.DeviceFailedToCreate;

        self.queue.* = D3D11Queue.init(self) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer D3D11Queue.deinit(queue);

        if (self.physical_device.instance.debug) {
            const hr_debug = self.device.?.IUnknown_QueryInterface(
                d3d11.IID_ID3D11Debug,
                @ptrCast(&self.debug_layer),
            );
            errdefer d3dcommon.releaseIUnknown(d3d11.ID3D11Debug, &self.debug_layer);
            if (!d3dcommon.checkHResult(hr_debug)) return gpu.Device.Error.DeviceFailedToCreate;

            // set severity to warning
            var info_queue: ?*d3d11.ID3D11InfoQueue = null;
            if (winapi.zig.SUCCEEDED(
                self.debug_layer.?.IUnknown_QueryInterface(
                    d3d11.IID_ID3D11InfoQueue,
                    @ptrCast(&info_queue),
                ),
            )) {
                if (info_queue) |iq| {
                    _ = iq.ID3D11InfoQueue_SetBreakOnSeverity(.CORRUPTION, TRUE);
                    _ = iq.ID3D11InfoQueue_SetBreakOnSeverity(.ERROR, TRUE);
                    _ = iq.ID3D11InfoQueue_SetBreakOnSeverity(.WARNING, TRUE);
                }
                d3dcommon.releaseIUnknown(d3d11.ID3D11InfoQueue, &info_queue);
            }
        }

        return self;
    }

    pub fn deinit(self: *D3D11Device) void {
        if (self.lost_cb) |cb| {
            cb(.destroyed, "device destroyed");
        }
        self.queue.deinit();

        d3dcommon.releaseIUnknown(d3d11.ID3D11Debug, &self.debug_layer);
        d3dcommon.releaseIUnknown(d3d11.ID3D11Device, &self.device);

        allocator.destroy(self.queue);
        allocator.destroy(self);
    }

    pub fn getQueue(self: *D3D11Device) *gpu.Queue {
        return @ptrCast(@alignCast(self.queue));
    }
};

pub const D3D11Resource = struct {
    resource: ?*d3d11.ID3D11Resource = null,

    pub fn deinit(self: *D3D11Resource) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11Resource, &self.resource);
    }
};

// Instance
pub fn createInstance(alloc: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance {
    std.debug.print("creating instance...\n", .{});
    return @ptrCast(D3D11Instance.init(alloc, desc) catch
        return gpu.Instance.Error.InstanceFailedToCreate);
}

pub fn instanceCreateSurface(
    instance: *gpu.Instance,
    desc: *const gpu.Surface.Descriptor,
) gpu.Surface.Error!*gpu.Surface {
    std.debug.print("creating surface...\n", .{});
    return @ptrCast(try D3D11Surface.init(@ptrCast(@alignCast(instance)), desc));
}

pub fn instanceRequestPhysicalDevice(
    instance: *gpu.Instance,
    options: *const gpu.PhysicalDevice.Options,
) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
    std.debug.print("requesting physical_device...\n", .{});
    return @ptrCast(try D3D11PhysicalDevice.init(@ptrCast(@alignCast(instance)), options));
}

pub fn instanceDestroy(instance: *gpu.Instance) void {
    std.debug.print("destroying instance...\n", .{});
    D3D11Instance.deinit(@alignCast(@ptrCast(instance)));
}

var allocator: std.mem.Allocator = undefined;
pub const D3D11Instance = struct {
    factory: ?*dxgi.IDXGIFactory6 = null,
    debug: bool,

    pub fn init(alloc: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*D3D11Instance {
        allocator = alloc;
        const self = allocator.create(D3D11Instance) catch return gpu.Instance.Error.InstanceFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .debug = desc.debug,
        };

        const hr_factory = dxgi.CreateDXGIFactory2(
            if (desc.debug) dxgi.DXGI_CREATE_FACTORY_DEBUG else 0,
            dxgi.IID_IDXGIFactory6,
            @ptrCast(&self.factory),
        );
        if (!d3dcommon.checkHResult(hr_factory)) return gpu.Instance.Error.InstanceFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D11Instance) void {
        d3dcommon.releaseIUnknown(dxgi.IDXGIFactory6, &self.factory);
        allocator.destroy(self);
    }
};

// PhysicalDevice
pub fn physicalDeviceCreateDevice(
    physical_device: *gpu.PhysicalDevice,
    desc: *const gpu.Device.Descriptor,
) gpu.Device.Error!*gpu.Device {
    std.debug.print("creating device...\n", .{});
    return @ptrCast(try D3D11Device.init(@ptrCast(@alignCast(physical_device)), desc));
}

pub fn physicalDeviceGetProperties(physical_device: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
    return D3D11PhysicalDevice.getProperties(@ptrCast(@alignCast(physical_device)), out_props);
}

pub fn physicalDeviceDestroy(physical_device: *gpu.PhysicalDevice) void {
    std.debug.print("destroying physical_device...\n", .{});
    D3D11PhysicalDevice.deinit(@alignCast(@ptrCast(physical_device)));
}

pub const D3D11PhysicalDevice = struct {
    instance: *D3D11Instance,
    adapter: ?*dxgi.IDXGIAdapter = null,
    adapter_desc: dxgi.DXGI_ADAPTER_DESC = undefined,
    properties: gpu.PhysicalDevice.Properties = undefined,

    pub fn init(instance: *D3D11Instance, options: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*D3D11PhysicalDevice {
        const self = allocator.create(D3D11PhysicalDevice) catch return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .instance = instance,
        };

        const pref = d3dcommon.mapPowerPreference(options.power_preference);
        const hr_enum = self.instance.factory.?.IDXGIFactory6_EnumAdapterByGpuPreference(
            0,
            pref,
            dxgi.IID_IDXGIAdapter,
            @ptrCast(&self.adapter),
        );

        // get a description of the adapter
        _ = self.adapter.?.IDXGIAdapter_GetDesc(&self.adapter_desc);

        var scratch = common.ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();

        const converted_description = std.unicode.utf16leToUtf8Alloc(
            temp_allocator,
            &self.adapter_desc.Description,
        ) catch "<unknown>";

        self.properties.name = allocator.dupe(u8, converted_description) catch
            return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;
        errdefer allocator.free(converted_description);
        self.properties.vendor = @enumFromInt(self.adapter_desc.VendorId);
        if (!d3dcommon.checkHResult(hr_enum)) return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D11PhysicalDevice) void {
        allocator.free(self.properties.name);
        d3dcommon.releaseIUnknown(dxgi.IDXGIAdapter, &self.adapter);
        allocator.destroy(self);
    }

    pub fn getProperties(self: *D3D11PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
        out_props.* = self.properties;
        return true;
    }
};

// PipelineLayout
// QuerySet
// Queue
pub fn queueSubmit(queue: *gpu.Queue, command_buffers: []const *gpu.CommandBuffer) gpu.Queue.Error!void {
    std.debug.print("submitting queue...\n", .{});
    try D3D11Queue.submit(@ptrCast(@alignCast(queue)), command_buffers);
}

pub const D3D11Queue = struct {
    device: *D3D11Device,
    context: ?*d3d11.ID3D11DeviceContext = null,

    fence: D3D11Fence,
    current_command_encoder: ?*D3D11CommandEncoder = null,

    // Assigned to a pointer, so it doesn't need to allocate
    pub fn init(device: *D3D11Device) gpu.Queue.Error!D3D11Queue {
        var self = D3D11Queue{
            .device = device,
            .context = null,
            .fence = D3D11Fence.init(device) catch return gpu.Queue.Error.QueueFailedToCreate,
        };
        device.device.?.ID3D11Device_GetImmediateContext(@ptrCast(&self.context));
        return self;
    }

    pub fn deinit(self: *D3D11Queue) void {
        if (self.current_command_encoder) |ce| ce.deinit();
        self.fence.deinit();
        d3dcommon.releaseIUnknown(d3d11.ID3D11DeviceContext, &self.context);
    }

    pub fn submit(self: *D3D11Queue, command_buffers: []const *gpu.CommandBuffer) gpu.Queue.Error!void {
        // immediate command encoder
        if (self.current_command_encoder) |ce| {
            const command_buffer = ce.finish(&.{}) catch return gpu.Queue.Error.QueueFailedToSubmit;
            self.context.?.ID3D11DeviceContext_ExecuteCommandList(
                command_buffer.command_list,
                TRUE,
            );
            // on d3d11 we can finish the command encoder and it will reset the context
            // this means we can reuse the command encoder next time
            // ce.deinit();
            // self.current_command_encoder = null;
        }

        for (command_buffers) |cb| {
            const command_buffer: *D3D11CommandBuffer = @ptrCast(@alignCast(cb));
            self.context.?.ID3D11DeviceContext_ExecuteCommandList(
                command_buffer.command_list,
                TRUE,
            );
        }
    }

    // internal
    fn waitIdle(self: *D3D11Queue) void {
        self.fence.wait(self);
    }
};

pub const D3D11Fence = struct {
    pub const Error = error{
        FenceFailedToCreate,
    };
    query: ?*d3d11.ID3D11Query = null,

    pub fn init(device: *D3D11Device) Error!D3D11Fence {
        var self = D3D11Fence{};
        const desc: d3d11.D3D11_QUERY_DESC = .{
            .Query = .EVENT,
            .MiscFlags = 0,
        };
        const hr_fence = device.device.?.ID3D11Device_CreateQuery(&desc, @ptrCast(&self.query));
        errdefer d3dcommon.releaseIUnknown(d3d11.ID3D11Query, &self.query);
        if (!d3dcommon.checkHResult(hr_fence)) return Error.FenceFailedToCreate;
        return self;
    }

    pub fn deinit(self: *D3D11Fence) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11Query, &self.query);
    }

    pub fn submit(self: *D3D11Fence, queue: *D3D11Queue) void {
        queue.context.?.ID3D11DeviceContext_End(@ptrCast(self.query));
    }

    pub fn wait(self: *D3D11Fence, queue: *D3D11Queue) void {
        while (queue.context.?.ID3D11DeviceContext_GetData(
            @ptrCast(self.query),
            null,
            0,
            0,
        ) == win32.foundation.S_FALSE) {
            // std.atomic.spinLoopHint();
        }
    }
};
// RenderBundle
// RenderBundleEncoder
// RenderPassEncoder
// RenderPipeline
// Sampler
// ShaderModule
// Surface
pub fn surfaceDestroy(surface: *gpu.Surface) void {
    std.debug.print("destroying surface...\n", .{});
    D3D11Surface.deinit(@alignCast(@ptrCast(surface)));
}

pub const D3D11Surface = struct {
    hwnd: ?win32.foundation.HWND = null,

    pub fn init(instance: *D3D11Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*D3D11Surface {
        _ = instance;
        const self = allocator.create(D3D11Surface) catch return gpu.Surface.Error.SurfaceFailedToCreate;
        self.* = .{
            .hwnd = desc.native_handle,
        };
        return self;
    }

    pub fn deinit(self: *D3D11Surface) void {
        allocator.destroy(self);
    }
};
// Texture
// TextureView
