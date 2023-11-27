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
    // Adapter
    .adapterCreateDevice = adapterCreateDevice,
    .adapterGetProperties = adapterGetProperties,
    .destroyAdapter = destroyAdapter,
    // BindGroup
    // BindGroupLayout
    // Buffer
    // CommandBuffer
    // CommandEncoder
    // ComputePassEncoder
    // ComputePipeline
    // Device
    .destroyDevice = destroyDevice,
    // Instance
    .createInstance = createInstance,
    .instanceCreateSurface = instanceCreateSurface,
    .instanceRequestAdapter = instanceRequestAdapter,
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
pub fn adapterCreateDevice(
    adapter: *gpu.Adapter,
    desc: *const gpu.Device.Descriptor,
) gpu.Device.Error!*gpu.Device {
    std.debug.print("creating device...\n", .{});
    return @ptrCast(try D3D11Device.init(@ptrCast(@alignCast(adapter)), desc));
}

pub fn adapterGetProperties(adapter: *gpu.Adapter, out_props: *gpu.Adapter.Properties) bool {
    return D3D11Adapter.getProperties(@ptrCast(@alignCast(adapter)), out_props);
}

pub fn destroyAdapter(adapter: *gpu.Adapter) void {
    std.debug.print("destroying adapter...\n", .{});
    D3D11Adapter.deinit(@alignCast(@ptrCast(adapter)));
}

pub const D3D11Adapter = struct {
    instance: *D3D11Instance,
    adapter: ?*dxgi.IDXGIAdapter = null,
    adapter_desc: dxgi.DXGI_ADAPTER_DESC = undefined,
    properties: gpu.Adapter.Properties = undefined,

    pub fn init(instance: *D3D11Instance, options: *const gpu.Adapter.Options) gpu.Adapter.Error!*D3D11Adapter {
        const self = allocator.create(D3D11Adapter) catch return gpu.Adapter.Error.AdapterFailedToCreate;
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
        var desc: dxgi.DXGI_ADAPTER_DESC = undefined;
        _ = self.adapter.?.IDXGIAdapter_GetDesc(&desc);

        var scratch = common.ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();

        const converted_description = std.unicode.utf16leToUtf8Alloc(
            temp_allocator,
            &desc.Description,
        ) catch "<unknown>";

        self.properties.name = allocator.dupe(u8, converted_description) catch
            return gpu.Adapter.Error.AdapterFailedToCreate;
        errdefer allocator.free(converted_description);
        self.properties.vendor = @enumFromInt(desc.VendorId);
        if (!d3dcommon.checkHResult(hr_enum)) return gpu.Adapter.Error.AdapterFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D11Adapter) void {
        allocator.free(self.properties.name);
        d3dcommon.releaseIUnknown(dxgi.IDXGIAdapter, &self.adapter);
        allocator.destroy(self);
    }

    pub fn getProperties(self: *D3D11Adapter, out_props: *gpu.Adapter.Properties) bool {
        out_props.* = self.properties;
        return true;
    }
};
// BindGroup
// BindGroupLayout
// Buffer
// CommandBuffer
// CommandEncoder
// ComputePassEncoder
// ComputePipeline
// Device
pub fn destroyDevice(device: *gpu.Device) void {
    std.debug.print("destroying device...\n", .{});
    D3D11Device.deinit(@alignCast(@ptrCast(device)));
}

pub const D3D11Device = struct {
    extern "d3d11" fn D3D11CreateDevice(
        pAdapter: ?*dxgi.IDXGIAdapter,
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

    adapter: *D3D11Adapter,

    device: ?*d3d11.ID3D11Device = null, // PhysicalDevice
    debug_layer: ?*d3d11.ID3D11Debug = null,
    lost_cb: ?gpu.Device.LostCallback = null,

    pub fn init(adapter: *D3D11Adapter, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*D3D11Device {
        const self = allocator.create(D3D11Device) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .adapter = adapter,
            .lost_cb = desc.lost_callback,
        };

        const feature_levels = [_]d3d.D3D_FEATURE_LEVEL{
            .@"11_0",
        };
        const hr = D3D11CreateDevice(
            self.adapter.adapter,
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
        if (!d3dcommon.checkHResult(hr)) return gpu.Device.Error.DeviceFailedToCreate;

        if (self.adapter.instance.debug) {
            const hr_debug = self.device.?.IUnknown_QueryInterface(
                d3d11.IID_ID3D11Debug,
                @ptrCast(&self.debug_layer),
            );
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
        d3dcommon.releaseIUnknown(d3d11.ID3D11Debug, &self.debug_layer);
        d3dcommon.releaseIUnknown(d3d11.ID3D11Device, &self.device);
        allocator.destroy(self);
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

pub fn instanceRequestAdapter(
    instance: *gpu.Instance,
    options: *const gpu.Adapter.Options,
) gpu.Adapter.Error!*gpu.Adapter {
    std.debug.print("requesting adapter...\n", .{});
    return @ptrCast(try D3D11Adapter.init(@ptrCast(@alignCast(instance)), options));
}

pub fn destroyInstance(instance: *gpu.Instance) void {
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
