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
    .destroyAdapter = destroyAdapter,
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
pub fn destroyAdapter(adapter: *gpu.Adapter) void {
    std.debug.print("destroying adapter...\n", .{});
    D3D11Adapter.deinit(@alignCast(@ptrCast(adapter)));
}

pub const D3D11Adapter = struct {
    pub extern "d3d11" fn D3D11CreateDevice(
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

    instance: *D3D11Instance,
    adapter: ?*dxgi.IDXGIAdapter = null,
    device: ?*d3d11.ID3D11Device = null, // PhysicalDevice

    pub fn init(instance: *D3D11Instance, options: *const gpu.Adapter.Options) gpu.Adapter.Error!*D3D11Adapter {
        const self = allocator.create(D3D11Adapter) catch return gpu.Adapter.Error.AdapterFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .instance = instance,
        };

        // we attempt to get IDXGIFactory6 as it has the power preference enumeration
        // if we fail, we fall back to IDXGIFactory1
        var factory6: ?*dxgi.IDXGIFactory6 = null;
        var adapter: ?*dxgi.IDXGIAdapter = null;
        const hr_query = self.instance.factory.?.IUnknown_QueryInterface(
            dxgi.IID_IDXGIFactory6,
            @ptrCast(factory6),
        );
        if (winapi.zig.SUCCEEDED(hr_query)) {
            const pref = d3dcommon.mapPowerPreference(options.power_preference);
            // we have factory6, so we can get the first by power preference
            const hr_enum = factory6.?.IDXGIFactory6_EnumAdapterByGpuPreference(
                0,
                pref,
                dxgi.IID_IDXGIAdapter,
                @ptrCast(&adapter),
            );

            // get a description of the adapter
            var desc: dxgi.DXGI_ADAPTER_DESC = undefined;
            _ = adapter.?.IDXGIAdapter_GetDesc(&desc);

            var buffer: [256]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const temp_allocator = fba.allocator();

            const converted_description = std.unicode.utf16leToUtf8Alloc(
                temp_allocator,
                &desc.Description,
            ) catch "<unknown>";
            std.debug.print("adapter: {s}\n", .{converted_description});

            if (!d3dcommon.checkHResult(hr_enum)) return gpu.Adapter.Error.AdapterFailedToCreate;
        } else {
            // we don't have factory6, so we can get the first by index
            const hr_enum = instance.factory.?.IDXGIFactory_EnumAdapters(
                0,
                @ptrCast(&adapter),
            );
            if (!d3dcommon.checkHResult(hr_enum)) return gpu.Adapter.Error.AdapterFailedToCreate;
        }
        self.adapter = adapter;

        const feature_levels = [_]d3d.D3D_FEATURE_LEVEL{
            .@"11_0",
        };
        const hr = D3D11CreateDevice(
            adapter,
            .HARDWARE,
            null,
            d3d11.D3D11_CREATE_DEVICE_DEBUG,
            &feature_levels,
            feature_levels.len,
            d3d11.D3D11_SDK_VERSION,
            @ptrCast(&self.device),
            null,
            null,
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.Adapter.Error.AdapterFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D11Adapter) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11Device, &self.device);
        d3dcommon.releaseIUnknown(dxgi.IDXGIAdapter, &self.adapter);
        allocator.destroy(self);
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
    factory: ?*dxgi.IDXGIFactory = null,

    pub fn init(alloc: std.mem.Allocator) !*D3D11Instance {
        allocator = alloc;
        const self = allocator.create(D3D11Instance) catch return gpu.Instance.Error.InstanceFailedToCreate;
        errdefer self.deinit();
        self.* = .{};

        const hr = dxgi.CreateDXGIFactory(dxgi.IID_IDXGIFactory, @ptrCast(&self.factory));
        if (!d3dcommon.checkHResult(hr)) return gpu.Instance.Error.InstanceFailedToCreate;

        return @ptrCast(self);
    }

    pub fn deinit(self: *D3D11Instance) void {
        d3dcommon.releaseIUnknown(dxgi.IDXGIFactory, &self.factory);
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
