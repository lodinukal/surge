const std = @import("std");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const app = @import("../../../app/app.zig");
const winappimpl = @import("../../../app/platform/windows.zig");

const d3dcommon = @import("../d3d/common.zig");
const Renderer = @import("../Renderer.zig");
const Handle = @import("../pool.zig").Handle;
const DynamicPool = @import("../pool.zig").DynamicPool;
const Pool = @import("../pool.zig").Pool;

const symbols = Renderer.SymbolTable{
    .init = &init,
    .deinit = &deinit,

    .createSwapChain = &createSwapChain,
    .useSwapChain = &useSwapChain,
    .useSwapChainMutable = &useSwapChainMutable,
    .destroySwapChain = &destroySwapChain,

    .createShader = &createShader,
    .destroyShader = &destroyShader,
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
    shaders: DynamicPool(D3D11Shader),
};
pub var state: RendererState = undefined;

fn init(r: *Renderer, create_info: Renderer.RendererCreateInfo) Renderer.Error!void {
    state = .{
        .swapchains = Pool(D3D11SwapChain, 2).init(),
        .shaders = DynamicPool(D3D11Shader).init(r.allocator),
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
    if (winappimpl.reportHResultError(
        r.allocator,
        hr,
        "Failed to create DXGIFactory",
    )) return Renderer.Error.InitialisationFailed;
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

    if (winappimpl.reportHResultError(
        r.allocator,
        hr,
        "Failed to initialise D3D11",
    )) return Renderer.Error.InitialisationFailed;

    _ = base_device.?.IUnknown_QueryInterface(
        d3d11.IID_ID3D11Device1,
        @ptrCast(&state.device),
    );

    _ = base_device_context.?.IUnknown_QueryInterface(
        d3d11.IID_ID3D11DeviceContext1,
        @ptrCast(&state.device_context),
    );

    if (r.debug) {
        _ = state.device.?.IUnknown_QueryInterface(d3d11.IID_ID3D11Debug, @ptrCast(&state.debug_layer));
        if (state.debug_layer != null) {
            var info_queue: ?*d3d11.ID3D11InfoQueue = null;
            if (winapi.zig.SUCCEEDED(state.debug_layer.?.IUnknown_QueryInterface(d3d11.IID_ID3D11InfoQueue, @ptrCast(&info_queue)))) {
                // _ = info_queue.?.ID3D11InfoQueue_SetBreakOnSeverity(.CORRUPTION, winappimpl.TRUE);
                // _ = info_queue.?.ID3D11InfoQueue_SetBreakOnSeverity(.ERROR, winappimpl.TRUE);
                // _ = info_queue.?.ID3D11InfoQueue_SetBreakOnSeverity(.WARNING, winappimpl.TRUE);
                _ = info_queue.?.IUnknown_Release();
            }
        }
    }
}

fn cleanupDeviceAndContext() void {
    if (state.debug_layer) |d| _ = d.IUnknown_Release();
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

// SwapChain

pub const D3D11SwapChain = struct {
    pub const Hot = ?*dxgi.IDXGISwapChain;
    pub const Cold = D3D11SwapChain;

    base: Renderer.SwapChain = undefined,

    swapchain: ?*dxgi.IDXGISwapChain = null,
    sample_desc: dxgi.common.DXGI_SAMPLE_DESC = .{
        .Count = 1,
        .Quality = 0,
    },

    colour_format: dxgi.common.DXGI_FORMAT = .UNKNOWN,
    depth_stencil_format: dxgi.common.DXGI_FORMAT = .UNKNOWN,

    // buffers
    // should probably allow for more than one buffer
    colour_buffer: ?*d3d11.ID3D11Texture2D = null,
    render_target_view: ?*d3d11.ID3D11RenderTargetView = null,
    depth_buffer: ?*d3d11.ID3D11Texture2D = null,
    depth_stencil_view: ?*d3d11.ID3D11DepthStencilView = null,

    // current command buffer
    // binding_command_buffer: ?Handle(CommandBuffer) = null,

    pub inline fn fromBaseMut(rt: *Renderer.SwapChain) *D3D11SwapChain {
        return @fieldParentPtr(D3D11SwapChain, "base", rt);
    }

    pub inline fn fromBase(rt: *const Renderer.SwapChain) *const D3D11SwapChain {
        return @fieldParentPtr(D3D11SwapChain, "base", @constCast(rt));
    }

    pub fn init(
        self: *D3D11SwapChain,
        factory: *dxgi.IDXGIFactory,
        create_info: *const Renderer.SwapChain.SwapChainCreateInfo,
        window: *app.window.Window,
    ) Renderer.Error!void {
        self.* = .{};
        try self.base.init(create_info);

        self.base.fn_present = &_present;
        self.base.fn_getCurrentSwapIndex = &_getCurrentSwapIndex;
        self.base.fn_getNumSwapBuffers = &_getNumSwapBuffers;
        self.base.fn_getColourFormat = &_getColourFormat;
        self.base.fn_getDepthStencilFormat = &_getDepthStencilFormat;
        self.base.fn_resizeBuffers = &_resizeBuffers;

        self.base.render_target.fn_getSamples = &_getSamples;

        self.depth_stencil_format = d3dcommon.pickDepthStencilFormat(
            create_info.depth_bits,
            create_info.stencil_bits,
        );

        self.base.setSurface(window);
        try self.createSwapChain(
            factory,
            create_info.resolution,
            create_info.samples,
            create_info.buffers,
        );
        try self.recreateBuffers();
    }

    pub fn deinit(
        self: *D3D11SwapChain,
    ) Renderer.Error!void {
        // try self.base.deinit();
        if (self.swapchain) |sc| _ = sc.IUnknown_Release();
    }

    // SwapChain implementations
    fn _present(self: *Renderer.SwapChain) Renderer.Error!void {
        return fromBaseMut(self).present();
    }

    pub fn present(self: *D3D11SwapChain) Renderer.Error!void {
        const hr = self.swapchain.?.IDXGISwapChain_Present(1, 0);
        _ = hr;
        // if (winappimpl.reportHResultError(
        //     .allocator,
        //     hr,
        //     "Failed to present swapchain",
        // )) return Renderer.Error.SwapChainPresentFailed;
    }

    fn _getCurrentSwapIndex(self: *const Renderer.SwapChain) u32 {
        return fromBase(self).getCurrentSwapIndex();
    }

    pub fn getCurrentSwapIndex(self: *const D3D11SwapChain) u32 {
        _ = self;
        return 0;
    }

    fn _getNumSwapBuffers(self: *const Renderer.SwapChain) u32 {
        return fromBase(self).getNumSwapBuffers();
    }

    pub fn getNumSwapBuffers(self: *const D3D11SwapChain) u32 {
        _ = self;
        return 1;
    }

    fn _getColourFormat(self: *const Renderer.SwapChain) Renderer.format.Format {
        return fromBase(self).getColourFormat();
    }

    pub fn getColourFormat(self: *const D3D11SwapChain) Renderer.format.Format {
        return d3dcommon.unmapFormat(self.colour_format);
    }

    fn _getDepthStencilFormat(self: *const Renderer.SwapChain) Renderer.format.Format {
        return fromBase(self).getDepthStencilFormat();
    }

    pub fn getDepthStencilFormat(self: *const D3D11SwapChain) Renderer.format.Format {
        return d3dcommon.unmapFormat(self.depth_stencil_format);
    }

    // RenderTarget implementations
    fn _getSamples(self: *const Renderer.RenderTarget) u32 {
        return fromBase(Renderer.SwapChain.fromBase(self)).getSamples();
    }

    pub fn getSamples(self: *const D3D11SwapChain) u32 {
        return self.sample_desc.Count;
    }

    // D3D11SwapChain methods
    pub fn createSwapChain(
        self: *D3D11SwapChain,
        factory: *dxgi.IDXGIFactory,
        resolution: [2]u32,
        samples: u32,
        buffers: u32,
    ) Renderer.Error!void {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

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

        var native_handle = self.base.surface.?.getNativeHandle();
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
            .BufferCount = buffers - 1,
            .OutputWindow = native_handle.wnd,
            .Windowed = winappimpl.TRUE,
            .SwapEffect = if ((buffers - 1) > 2) .FLIP_DISCARD else .DISCARD,
            .Flags = 0,
        };
        if (self.swapchain) |sc| _ = sc.IUnknown_Release();
        const hr = factory.IDXGIFactory_CreateSwapChain(
            @ptrCast(state.device.?),
            &desc,
            &self.swapchain,
        );

        if (winapi.zig.FAILED(hr)) {
            winappimpl.messageBox(
                allocator,
                "Failed to create swapchain",
                "Error: {}",
                .{hr},
                .OK,
            );
            return Renderer.Error.SwapChainCreationFailed;
        }

        if (winappimpl.reportHResultError(
            allocator,
            hr,
            "Failed to create SwapChain",
        )) return Renderer.Error.SwapChainCreationFailed;
    }

    fn _resizeBuffers(self: *Renderer.SwapChain, resolution: [2]u32) Renderer.Error!void {
        try fromBaseMut(self).resizeBuffers(resolution);
    }

    pub fn resizeBuffers(self: *D3D11SwapChain, resolution: [2]u32) Renderer.Error!void {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        // TODO: implement this
        // if (state.command_buffers.getColdMutable(self.binding_command_buffer)) |cb| {
        //    cb.bindFrameBufferView(0, null, null);
        //  }

        d3dcommon.releaseIUnknown(d3d11.ID3D11Texture2D, &self.colour_buffer);
        d3dcommon.releaseIUnknown(d3d11.ID3D11RenderTargetView, &self.render_target_view);
        d3dcommon.releaseIUnknown(d3d11.ID3D11Texture2D, &self.depth_buffer);
        d3dcommon.releaseIUnknown(d3d11.ID3D11DepthStencilView, &self.depth_stencil_view);

        // TODO: implement this
        // if (state.command_buffers.getColdMutable(self.binding_command_buffer)) |cb| {
        //    cb.resetDeferredCommandList();
        //  }

        const hr: win32.foundation.HRESULT = self.swapchain.?.IDXGISwapChain_ResizeBuffers(
            0,
            resolution[0],
            resolution[1],
            .UNKNOWN,
            0,
        );
        if (winappimpl.reportHResultError(
            allocator,
            hr,
            "Failed to resize swapchain buffers",
        )) return Renderer.Error.SwapChainBufferCreationFailed;

        try self.recreateBuffers();
    }

    pub fn recreateBuffers(self: *D3D11SwapChain) Renderer.Error!void {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        var hr: win32.foundation.HRESULT = 0;

        d3dcommon.releaseIUnknown(d3d11.ID3D11Texture2D, &self.colour_buffer);
        hr = self.swapchain.?.IDXGISwapChain_GetBuffer(
            0,
            d3d11.IID_ID3D11Texture2D,
            @ptrCast(&self.colour_buffer),
        );
        if (winappimpl.reportHResultError(
            allocator,
            hr,
            "Failed to get swapchain buffer",
        )) return Renderer.Error.SwapChainBufferCreationFailed;

        d3dcommon.releaseIUnknown(d3d11.ID3D11RenderTargetView, &self.render_target_view);
        hr = state.device.?.ID3D11Device_CreateRenderTargetView(
            @ptrCast(self.colour_buffer.?),
            null,
            &self.render_target_view,
        );
        if (winappimpl.reportHResultError(
            allocator,
            hr,
            "Failed to create render target view",
        )) return Renderer.Error.SwapChainBufferCreationFailed;

        var colour_buffer_desc: d3d11.D3D11_TEXTURE2D_DESC = undefined;
        self.colour_buffer.?.ID3D11Texture2D_GetDesc(&colour_buffer_desc);

        if (self.depth_stencil_format != .UNKNOWN) {
            const texture_desc: d3d11.D3D11_TEXTURE2D_DESC = .{
                .Width = colour_buffer_desc.Width,
                .Height = colour_buffer_desc.Height,
                .MipLevels = 1,
                .ArraySize = 1,
                .Format = self.depth_stencil_format,
                .SampleDesc = self.sample_desc,
                .Usage = .DEFAULT,
                .BindFlags = @intFromEnum(d3d11.D3D11_BIND_FLAG.DEPTH_STENCIL),
                .CPUAccessFlags = 0,
                .MiscFlags = 0,
            };
            d3dcommon.releaseIUnknown(d3d11.ID3D11Texture2D, &self.depth_buffer);
            hr = state.device.?.ID3D11Device_CreateTexture2D(
                &texture_desc,
                null,
                &self.depth_buffer,
            );
            if (winappimpl.reportHResultError(
                allocator,
                hr,
                "Failed to create depth buffer",
            )) return Renderer.Error.SwapChainBufferCreationFailed;

            d3dcommon.releaseIUnknown(d3d11.ID3D11DepthStencilView, &self.depth_stencil_view);
            hr = state.device.?.ID3D11Device_CreateDepthStencilView(
                @ptrCast(self.depth_buffer.?),
                null,
                &self.depth_stencil_view,
            );
            if (winappimpl.reportHResultError(
                allocator,
                hr,
                "Failed to create depth stencil view",
            )) return Renderer.Error.SwapChainBufferCreationFailed;
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

pub fn useSwapChain(
    r: *const Renderer,
    handle: Handle(Renderer.SwapChain),
) Renderer.Error!*const Renderer.SwapChain {
    _ = r;
    const as_handle = handle.as(D3D11SwapChain);
    const sc = state.swapchains.getCold(as_handle) orelse return Renderer.Error.InvalidHandle;
    return &sc.base;
}

pub fn useSwapChainMutable(
    r: *Renderer,
    handle: Handle(Renderer.SwapChain),
) Renderer.Error!*Renderer.SwapChain {
    _ = r;
    const as_handle = handle.as(D3D11SwapChain);
    const sc = state.swapchains.getColdMutable(as_handle) orelse return Renderer.Error.InvalidHandle;
    return &sc.base;
}

pub fn destroySwapChain(r: *Renderer, handle: Handle(Renderer.SwapChain)) void {
    _ = r;
    const as_handle = handle.as(D3D11SwapChain);
    const sc = state.swapchains.getColdMutable(as_handle) orelse return;
    sc.deinit() catch {};
    state.swapchains.remove(as_handle) catch {};
}

// Shader

pub const D3D11ShaderHolder = union(Renderer.Shader.ShaderType) {
    undefined: void,
    vertex: ?*d3d11.ID3D11VertexShader,
    tesselation_control: ?*d3d11.ID3D11HullShader, // aka. hull
    tesselation_evaluation: ?*d3d11.ID3D11DomainShader, // aka. domain
    geometry: ?*d3d11.ID3D11GeometryShader,
    fragment: ?*d3d11.ID3D11PixelShader,
    compute: ?*d3d11.ID3D11ComputeShader,

    pub fn deinit(self: *D3D11ShaderHolder) void {
        switch (self.*) {
            .vertex => |*v| d3dcommon.releaseIUnknown(d3d11.ID3D11VertexShader, v),
            .tesselation_control => |*tc| d3dcommon.releaseIUnknown(d3d11.ID3D11HullShader, tc),
            .tesselation_evaluation => |*te| d3dcommon.releaseIUnknown(d3d11.ID3D11DomainShader, te),
            .geometry => |*g| d3dcommon.releaseIUnknown(d3d11.ID3D11GeometryShader, g),
            .fragment => |*f| d3dcommon.releaseIUnknown(d3d11.ID3D11PixelShader, f),
            .compute => |*c| d3dcommon.releaseIUnknown(d3d11.ID3D11ComputeShader, c),
            else => {},
        }
    }
};

pub const D3D11Shader = struct {
    pub const Hot = D3D11ShaderHolder;
    pub const Cold = D3D11Shader;

    base: Renderer.Shader = undefined,

    holder: ?D3D11ShaderHolder = null,
    bytecode: ?*d3d.ID3DBlob = null,
    // report
    input_layout: ?*d3d11.ID3D11InputLayout = null,
    // cbuffer reflections

    pub fn init(
        self: *D3D11Shader,
        create_info: *const Renderer.Shader.ShaderCreateInfo,
    ) !void {
        if (self.buildShader(create_info)) {
            try self.buildInputLayout(create_info.vertex.input orelse &.{});
        } else return Renderer.Error.ShaderCompilationFailed;
    }

    pub fn deinit(
        self: *D3D11Shader,
    ) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11InputLayout, &self.input_layout);
        if (self.holder) |*h| h.deinit();
        d3dcommon.releaseIUnknown(d3d.ID3DBlob, &self.bytecode);
    }

    pub fn buildShader(self: *D3D11Shader, create_info: *const Renderer.Shader.ShaderCreateInfo) bool {
        if (create_info.source_type == .code_string) {
            return self.compileSource(create_info);
        } else {
            return self.loadBinary(create_info);
        }
    }

    pub extern "d3dcompiler_47" fn D3DCompile(
        // TODO: what to do with BytesParamIndex 1?
        pSrcData: ?*const anyopaque,
        SrcDataSize: usize,
        pSourceName: ?[*:0]align(1) const u8,
        pDefines: ?*const d3d.D3D_SHADER_MACRO,
        pInclude: ?*align(1) d3d.ID3DInclude,
        pEntrypoint: ?[*:0]align(1) const u8,
        pTarget: ?[*:0]align(1) const u8,
        Flags1: u32,
        Flags2: u32,
        ppCode: ?*?*d3d.ID3DBlob,
        ppErrorMsgs: ?*?*d3d.ID3DBlob,
    ) callconv(@import("std").os.windows.WINAPI) win32.foundation.HRESULT;

    fn compileSource(self: *D3D11Shader, create_info: *const Renderer.Shader.ShaderCreateInfo) bool {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        var null_terminated_source_name = allocator.dupeZ(
            u8,
            create_info.name orelse "shader_",
        ) catch return false;

        var defines = std.ArrayList(d3d.D3D_SHADER_MACRO).initCapacity(
            allocator,
            create_info.macros.len,
        ) catch return false;
        for (create_info.macros) |m| {
            var macro: d3d.D3D_SHADER_MACRO = .{
                .Name = @ptrCast(allocator.dupeZ(u8, m.name) catch return false),
                .Definition = @ptrCast(allocator.dupeZ(u8, m.value orelse "") catch return false),
            };
            defines.appendAssumeCapacity(macro);
        }

        var profile_null_terminated = allocator.dupeZ(
            u8,
            create_info.profile orelse "",
        ) catch return false;

        var entry_point_null_terminated = allocator.dupeZ(
            u8,
            create_info.entry_point,
        ) catch return false;

        var errors: ?*d3d.ID3DBlob = null;
        d3dcommon.releaseIUnknown(d3d.ID3DBlob, &self.bytecode);
        const hr = D3DCompile(
            @ptrCast(create_info.source),
            create_info.source.len,
            null_terminated_source_name,
            if (defines.items.len < 1) null else @ptrCast(defines.items),
            @ptrFromInt(1),
            @ptrCast(entry_point_null_terminated),
            @ptrCast(profile_null_terminated),
            d3dcommon.getFxcFlags(create_info.compile_info),
            0,
            &self.bytecode,
            &errors,
        );

        if (self.bytecode) |bc| {
            _ = bc;
            self.createHolderShader(
                create_info.vertex.output orelse &.{},
                null,
            );
        }

        const has_errors = winapi.zig.FAILED(hr);
        if (winappimpl.reportHResultError(
            allocator,
            hr,
            "Failed to compile shader",
        )) return false;
        // TODO: make a report
        return !has_errors;
    }

    fn createHolderShader(
        self: *D3D11Shader,
        stream_output_attributes: []const Renderer.VertexAttribute,
        linkage: ?*d3d11.ID3D11ClassLinkage,
    ) void {
        self.holder = self.createHolderShaderFromBlob(
            self.base.type,
            self.bytecode,
            stream_output_attributes,
            linkage,
        );
    }

    fn loadBinary(self: *D3D11Shader, create_info: *const Renderer.Shader.ShaderCreateInfo) bool {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();
        _ = allocator;

        self.bytecode = d3dcommon.createBlob(create_info.source);
        if (self.bytecode != null and self.bytecode.?.ID3DBlob_GetBufferSize() > 0) {
            self.createHolderShader(create_info.vertex.output orelse &.{}, null);
            return true;
        } else {
            return false;
        }
    }

    fn createHolderShaderFromBlob(
        self: *D3D11Shader,
        shader_type: Renderer.Shader.ShaderType,
        blob: ?*d3d.ID3DBlob,
        stream_output_attributes: []const Renderer.VertexAttribute,
        linkage: ?*d3d11.ID3D11ClassLinkage,
    ) ?D3D11ShaderHolder {
        _ = self;
        if (blob == null) return null;

        var shader: ?D3D11ShaderHolder = null;
        var hr: win32.foundation.HRESULT = win32.foundation.S_OK;

        switch (shader_type) {
            .vertex => {
                shader = .{ .vertex = null };
                hr = state.device.?.ID3D11Device_CreateVertexShader(
                    @ptrCast(blob.?.ID3DBlob_GetBufferPointer().?),
                    blob.?.ID3DBlob_GetBufferSize(),
                    linkage,
                    &shader.?.vertex,
                );
            },
            .tesselation_control => {
                shader = .{ .tesselation_control = null };
                hr = state.device.?.ID3D11Device_CreateHullShader(
                    @ptrCast(blob.?.ID3DBlob_GetBufferPointer().?),
                    blob.?.ID3DBlob_GetBufferSize(),
                    linkage,
                    &shader.?.tesselation_control,
                );
            },
            .tesselation_evaluation => {
                shader = .{ .tesselation_evaluation = null };
                hr = state.device.?.ID3D11Device_CreateDomainShader(
                    @ptrCast(blob.?.ID3DBlob_GetBufferPointer().?),
                    blob.?.ID3DBlob_GetBufferSize(),
                    linkage,
                    &shader.?.tesselation_evaluation,
                );
            },
            .geometry => {
                shader = .{ .geometry = null };
                if (stream_output_attributes.len > 0) {
                    // TODO: Stream outputs for geometry shaders
                } else {
                    hr = state.device.?.ID3D11Device_CreateGeometryShader(
                        @ptrCast(blob.?.ID3DBlob_GetBufferPointer().?),
                        blob.?.ID3DBlob_GetBufferSize(),
                        linkage,
                        &shader.?.geometry,
                    );
                }
            },
            .fragment => {
                shader = .{ .fragment = null };
                hr = state.device.?.ID3D11Device_CreatePixelShader(
                    @ptrCast(blob.?.ID3DBlob_GetBufferPointer().?),
                    blob.?.ID3DBlob_GetBufferSize(),
                    linkage,
                    &shader.?.fragment,
                );
            },
            .compute => {
                shader = .{ .compute = null };
                hr = state.device.?.ID3D11Device_CreateComputeShader(
                    @ptrCast(blob.?.ID3DBlob_GetBufferPointer().?),
                    blob.?.ID3DBlob_GetBufferSize(),
                    linkage,
                    &shader.?.compute,
                );
            },
            else => {},
        }

        return shader;
    }

    fn buildInputLayout(self: *D3D11Shader, vertex_attributes: []const Renderer.VertexAttribute) !void {
        if (vertex_attributes.len == 0) return;
        if (self.base.type != .vertex) return;

        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        var input_elements = std.ArrayList(d3d11.D3D11_INPUT_ELEMENT_DESC).initCapacity(
            allocator,
            vertex_attributes.len,
        ) catch return Renderer.Error.ShaderInputLayoutCreationFailed;

        for (0..vertex_attributes.len) |i| {
            var dst = input_elements.addOneAssumeCapacity();
            var src = vertex_attributes[i];
            dst.SemanticName = @ptrCast(allocator.dupeZ(
                u8,
                src.name,
            ) catch return Renderer.Error.ShaderInputLayoutCreationFailed);
            dst.SemanticIndex = src.semantic_index;
            dst.Format = d3dcommon.mapFormat(src.format);
            dst.InputSlot = src.slot;
            dst.AlignedByteOffset = src.offset;
            dst.InputSlotClass = if (src.instance_divisor > 0) .INSTANCE_DATA else .VERTEX_DATA;
            dst.InstanceDataStepRate = src.instance_divisor;
        }

        const hr = state.device.?.ID3D11Device_CreateInputLayout(
            @ptrCast(input_elements.items),
            @intCast(input_elements.items.len),
            @ptrCast(self.bytecode.?.ID3DBlob_GetBufferPointer()),
            self.bytecode.?.ID3DBlob_GetBufferSize(),
            &self.input_layout,
        );
        if (winappimpl.reportHResultError(
            allocator,
            hr,
            "Failed to create input layout",
        )) return Renderer.Error.ShaderInputLayoutCreationFailed;
    }
};

fn createShader(
    r: *Renderer,
    create_info: *const Renderer.Shader.ShaderCreateInfo,
) Renderer.Error!Handle(Renderer.Shader) {
    _ = r;
    const handle = state.shaders.put(
        .undefined,
        undefined,
    ) catch return Renderer.Error.ShaderCompilationFailed;
    const shader = state.shaders.getColdMutable(handle).?;
    try shader.init(create_info);
    return handle.as(Renderer.Shader);
}

fn destroyShader(r: *Renderer, handle: Handle(Renderer.Shader)) void {
    _ = r;
    const as_handle = handle.as(D3D11Shader);
    const shader = state.shaders.getColdMutable(as_handle) orelse return;
    shader.deinit();
    state.shaders.remove(as_handle) catch {};
}

test {
    std.testing.refAllDecls(@This());
}
