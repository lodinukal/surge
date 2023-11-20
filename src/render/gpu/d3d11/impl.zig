const std = @import("std");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;

const app = @import("../../../app/app.zig");
const winappimpl = @import("../../../app/platform/windows.zig");

const d3dcommon = @import("../d3d/common.zig");
const Renderer = @import("../Renderer.zig");
const Handle = @import("../pool.zig").Handle;
const Pool = @import("../pool.zig").Pool;

const symbols = Renderer.SymbolTable{
    .init = &init,
    .deinit = &deinit,
    .createSwapChain = &createSwapChain,
    .destroySwapChain = &destroySwapChain,
};

pub export fn getSymbols() *const Renderer.SymbolTable {
    return &symbols;
}

pub const RendererState = struct {
    factory: ?*dxgi.IDXGIFactory = null,
    adapter_info: ?Renderer.AdapterInfo = null,
    device: ?*d3d11.ID3D11Device = null,
    device_context: ?*d3d11.ID3D11DeviceContext1 = null,
    feature_level: d3d.D3D_FEATURE_LEVEL = .@"9_1",
    debug_layer: ?*d3d11.ID3D11Debug = null,

    // objects
    swapchains: Pool(D3D11SwapChain, 2), // i think 2 is more than enough for now (2 game views)
};
pub var state: RendererState = undefined;

fn init(r: *Renderer, create_info: Renderer.RendererCreateInfo) Renderer.Error!void {
    state = .{
        .swapchains = Pool(D3D11SwapChain, 2).init(),
    };
    errdefer deinit(r);

    try createFactory(r);

    var preferred_adapter: ?*dxgi.IDXGIAdapter = null;
    defer _ = if (preferred_adapter) |a| a.IUnknown_Release();
    querySuitableAdapter(r, create_info, &preferred_adapter);

    try createDeviceAndContext(r, preferred_adapter);

    loadRendererInfo(r) catch return Renderer.Error.InitialisationFailed;
    loadRenderingCapabilities(r) catch return Renderer.Error.InitialisationFailed;
}

fn deinit(r: *Renderer) void {
    cleanupRenderingCapabilities(r);
    cleanupRendererInfo(r);

    if (state.adapter_info) |*ai| ai.deinit();
    cleanupDeviceAndContext();
    cleanupFactory();
}

fn createFactory(r: *Renderer) !void {
    var hr: win32.foundation.HRESULT = 0;
    hr = dxgi.CreateDXGIFactory(dxgi.IID_IDXGIFactory, @ptrCast(&state.factory));
    if (winapi.zig.FAILED(hr)) {
        winappimpl.messageBox(
            r.allocator,
            "Failed to create IDXGIFactory",
            "Error: {}",
            .{hr},
            .OK,
        );
        return Renderer.Error.InitialisationFailed;
    }
}

fn cleanupFactory() void {
    if (state.factory) |f| _ = f.IUnknown_Release();
}

// custom one because the one in d3d11 has a weird signature for Software (it is non nullable)
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
    ppImmediateContext: ?*?*d3d11.ID3D11DeviceContext,
) callconv(@import("std").os.windows.WINAPI) win32.foundation.HRESULT;

fn createDeviceAndContext(r: *Renderer, adapter: ?*dxgi.IDXGIAdapter) !void {
    const feature_levels = [_]d3d.D3D_FEATURE_LEVEL{
        .@"11_0",
    };

    var base_device: ?*d3d11.ID3D11Device = null;
    defer _ = if (base_device) |d| d.IUnknown_Release();
    var base_device_context: ?*d3d11.ID3D11DeviceContext = null;
    defer _ = if (base_device_context) |dc| dc.IUnknown_Release();

    var hr: win32.foundation.HRESULT = 0;

    const creation_flags = d3d11.D3D11_CREATE_DEVICE_FLAG.initFlags(.{
        .BGRA_SUPPORT = 1,
        .DEBUG = if (r.debug) 1 else 0,
    });
    hr = D3D11CreateDevice(
        adapter,
        .HARDWARE,
        null,
        creation_flags,
        &feature_levels,
        feature_levels.len,
        d3d11.D3D11_SDK_VERSION,
        &base_device,
        &state.feature_level,
        &base_device_context,
    );

    if (winapi.zig.FAILED(hr)) {
        winappimpl.messageBox(
            r.allocator,
            "Failed to initialise D3D11",
            "Error: {}",
            .{hr},
            .OK,
        );
        return Renderer.Error.InitialisationFailed;
    }

    _ = base_device.?.IUnknown_QueryInterface(
        d3d11.IID_ID3D11Device1,
        @ptrCast(&state.device),
    );

    _ = base_device_context.?.IUnknown_QueryInterface(
        d3d11.IID_ID3D11DeviceContext1,
        @ptrCast(&state.device_context),
    );

    if (r.debug) {
        var debug: ?*d3d11.ID3D11Debug = null;
        defer _ = if (debug) |d| d.IUnknown_Release();

        _ = state.device.?.IUnknown_QueryInterface(d3d11.IID_ID3D11Debug, @ptrCast(&debug));
        if (debug != null) {
            var info_queue: ?*d3d11.ID3D11InfoQueue = null;
            if (winapi.zig.SUCCEEDED(debug.?.IUnknown_QueryInterface(d3d11.IID_ID3D11InfoQueue, @ptrCast(&info_queue)))) {
                _ = info_queue.?.ID3D11InfoQueue_SetBreakOnSeverity(.CORRUPTION, winappimpl.TRUE);
                _ = info_queue.?.ID3D11InfoQueue_SetBreakOnSeverity(.ERROR, winappimpl.TRUE);
                _ = info_queue.?.ID3D11InfoQueue_SetBreakOnSeverity(.WARNING, winappimpl.TRUE);
                _ = info_queue.?.IUnknown_Release();
            }
        }
    }
}

fn cleanupDeviceAndContext() void {
    if (state.device_context) |dc| _ = dc.IUnknown_Release();
    if (state.device) |d| _ = d.IUnknown_Release();
}

fn querySuitableAdapter(r: *Renderer, create_info: Renderer.RendererCreateInfo, adapter: *?*dxgi.IDXGIAdapter) void {
    state.adapter_info = d3dcommon.getSuitableAdapterInfo(
        r.allocator,
        state.factory.?,
        create_info.preference,
        adapter,
    );
}

fn loadRendererInfo(r: *Renderer) !void {
    var info: Renderer.RendererInfo = undefined;
    info.name = std.fmt.allocPrint(r.allocator, "Direct3D {s}", .{
        d3dcommon.featureLevelToVersionString(state.feature_level),
    }) catch null;
    info.shading_language = d3dcommon.featureLevelToShaderModel(state.feature_level);
    info.device = if (state.adapter_info.?.name) |name| (try r.allocator.dupe(u8, name)) else null;
    info.vendor = state.adapter_info.?.vendor.getName();
    r.renderer_info = info;
}

fn cleanupRendererInfo(r: *Renderer) void {
    if (r.renderer_info.name) |n| r.allocator.free(n);
    if (r.renderer_info.device) |d| r.allocator.free(d);
}

fn loadRenderingCapabilities(r: *Renderer) !void {
    var caps = try d3dcommon.getRenderingCapabilitiesFromFeatureLevel(
        r.allocator,
        state.feature_level,
    );
    caps.features.conservative_rasterisation = false; // 11.3

    caps.limits.max_viewports = d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE;
    caps.limits.max_viewport_dimensions = .{
        d3d11.D3D11_VIEWPORT_BOUNDS_MAX,
        d3d11.D3D11_VIEWPORT_BOUNDS_MAX,
    };
    caps.limits.max_buffer_size = std.math.maxInt(std.os.windows.UINT);
    caps.limits.max_constant_buffer_size = d3d11.D3D11_REQ_CONSTANT_BUFFER_ELEMENT_COUNT * 16;

    caps.limits.max_colour_buffer_samples = findSuitableSampleDesc(state.device.?, .R8G8B8A8_UNORM, null).Count;
    caps.limits.max_depth_buffer_samples = findSuitableSampleDesc(state.device.?, .D32_FLOAT, null).Count;
    caps.limits.max_stencil_buffer_samples = findSuitableSampleDesc(state.device.?, .D32_FLOAT_S8X24_UINT, null).Count;
    caps.limits.max_no_attachments_samples = d3d11.D3D11_MAX_MULTISAMPLE_SAMPLE_COUNT;

    r.rendering_capabilities = caps;
}

fn findSuitableSampleDesc(
    device: *d3d11.ID3D11Device,
    format: dxgi.common.DXGI_FORMAT,
    max_sample_count: ?u32,
) dxgi.common.DXGI_SAMPLE_DESC {
    var count = max_sample_count orelse d3d11.D3D11_MAX_MULTISAMPLE_SAMPLE_COUNT;
    while (count > 1) : (count -= 1) {
        var num_quality_levels: u32 = 0;
        if (device.ID3D11Device_CheckMultisampleQualityLevels(
            format,
            count,
            &num_quality_levels,
        ) == win32.foundation.S_OK) {
            if (num_quality_levels > 0) {
                return .{
                    .Count = count,
                    .Quality = num_quality_levels - 1,
                };
            }
        }
    }
    return .{
        .Count = 1,
        .Quality = 0,
    };
}

fn findSuitableSampleDescFromMany(
    device: *d3d11.ID3D11Device,
    formats: []const dxgi.common.DXGI_FORMAT,
    max_sample_count: ?u32,
) dxgi.common.DXGI_SAMPLE_DESC {
    var result: dxgi.common.DXGI_SAMPLE_DESC = .{
        .Count = max_sample_count orelse d3d11.D3D11_MAX_MULTISAMPLE_SAMPLE_COUNT,
        .Quality = 0,
    };

    for (formats) |f| {
        if (f != .UNKNOWN) {
            result = findSuitableSampleDesc(device, f, result.Count);
        }
    }

    return result;
}

fn cleanupRenderingCapabilities(r: *Renderer) void {
    r.rendering_capabilities.formats.deinit();
    r.rendering_capabilities.shading_languages.deinit();
}

pub const D3D11SwapChain = struct {
    pub const Hot = ?*dxgi.IDXGISwapChain;
    pub const Cold = D3D11SwapChain;

    internal: Renderer.SwapChain = undefined,

    swapchain: ?*dxgi.IDXGISwapChain = null,
    sample_desc: dxgi.common.DXGI_SAMPLE_DESC = .{
        .Count = 1,
        .Quality = 0,
    },

    colour_format: dxgi.common.DXGI_FORMAT = .UNKNOWN,
    depth_stencil_format: dxgi.common.DXGI_FORMAT = .UNKNOWN,

    pub fn init(
        self: *D3D11SwapChain,
        factory: *dxgi.IDXGIFactory,
        create_info: *const Renderer.SwapChain.SwapChainCreateInfo,
        window: *app.window.Window,
    ) Renderer.Error!void {
        self.* = .{};
        try self.internal.init(create_info);
        self.depth_stencil_format = d3dcommon.pickDepthStencilFormat(
            create_info.depth_bits,
            create_info.stencil_bits,
        );

        self.internal.setSurface(window);
        try self.createSwapChain(
            factory,
            create_info.resolution,
            create_info.samples,
            create_info.buffers,
        );
    }

    pub fn deinit(
        self: *D3D11SwapChain,
    ) Renderer.Error!void {
        // try self.internal.deinit();
        if (self.swapchain) |sc| _ = sc.IUnknown_Release();
    }

    fn createSwapChain(
        self: *D3D11SwapChain,
        factory: *dxgi.IDXGIFactory,
        resolution: [2]u32,
        samples: u32,
        buffers: u32,
    ) Renderer.Error!void {
        const refresh_rate: dxgi.common.DXGI_RATIONAL = .{
            .Numerator = 75,
            .Denominator = 1,
        }; // TODO: change this later based on surface
        self.colour_format = .R8G8B8A8_UNORM;
        self.sample_desc = findSuitableSampleDesc(
            state.device.?,
            self.colour_format,
            samples,
        );

        var native_handle = self.internal.surface.?.getNativeHandle();
        var desc: dxgi.DXGI_SWAP_CHAIN_DESC = .{
            .BufferDesc = .{
                .Width = resolution[0],
                .Height = resolution[1],
                .Format = self.colour_format,
                .RefreshRate = refresh_rate,
                .Scaling = .UNSPECIFIED,
                .ScanlineOrdering = .UNSPECIFIED,
            },
            .SampleDesc = self.sample_desc,
            .BufferUsage = .RENDER_TARGET_OUTPUT,
            .BufferCount = if (buffers >= 3) 2 else 1,
            .OutputWindow = native_handle.wnd,
            .Windowed = winappimpl.TRUE,
            .SwapEffect = .DISCARD,
            .Flags = 0,
        };
        if (self.swapchain) |sc| _ = sc.IUnknown_Release();
        const hr = factory.IDXGIFactory_CreateSwapChain(
            @ptrCast(state.device.?),
            &desc,
            &self.swapchain,
        );

        std.debug.print("swapchain made sucessfully!!\n", .{});

        if (winapi.zig.FAILED(hr)) {
            winappimpl.messageBox(
                state.adapter_info.?.allocator,
                "Failed to create swapchain",
                "Error: {}",
                .{hr},
                .OK,
            );
            return Renderer.Error.SwapChainCreationFailed;
        }
    }
};

pub fn createSwapChain(
    r: *Renderer,
    create_info: *const Renderer.SwapChain.SwapChainCreateInfo,
    window: *app.window.Window,
) Renderer.Error!Handle(Renderer.SwapChain) {
    _ = r;

    const handle = state.swapchains.put(
        null,
        undefined,
    ) catch return Renderer.Error.SwapChainCreationFailed;
    const sc = state.swapchains.getColdMutable(handle).?;
    try sc.init(state.factory.?, create_info, window);
    return handle.as(Renderer.SwapChain);
}

pub fn destroySwapChain(r: *Renderer, handle: Handle(Renderer.SwapChain)) void {
    _ = r;
    const as_handle = handle.as(D3D11SwapChain);
    const sc = state.swapchains.getColdMutable(as_handle) orelse return;
    sc.deinit() catch {};
    state.swapchains.remove(as_handle) catch {};
}

test {
    std.testing.refAllDecls(@This());
}
