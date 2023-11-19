const std = @import("std");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;

const winappimpl = @import("../../../app/platform/windows.zig");

const Renderer = @import("../Renderer.zig");

const symbols = Renderer.SymbolTable{
    .init = &init,
    .deinit = &deinit,
    .get_renderer_info = &getRendererInfo,
    .get_rendering_capabilities = &getRenderingCapabilities,
};

pub export fn getSymbols() *const Renderer.SymbolTable {
    return &symbols;
}

pub const RendererState = struct {
    device: ?*d3d11.ID3D11Device1 = null,
    device_context: ?*d3d11.ID3D11DeviceContext1 = null,
    debug_layer: ?*d3d11.ID3D11Debug = null,
};
pub var state: RendererState = undefined;

fn init(r: *Renderer) Renderer.Error!void {
    state = .{};
    errdefer deinit(r);

    try createDeviceAndContext(r);
}

fn deinit(r: *Renderer) void {
    _ = r;
    cleanupDeviceAndContext();
}

// custom one because the one in d3d11 has a weird signature for Software (it is non nullable)
pub extern "d3d11" fn D3D11CreateDevice(
    pAdapter: ?*win32.graphics.dxgi.IDXGIAdapter,
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

fn createDeviceAndContext(r: *Renderer) !void {
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
        null,
        .HARDWARE,
        null,
        creation_flags,
        &feature_levels,
        feature_levels.len,
        d3d11.D3D11_SDK_VERSION,
        &base_device,
        null,
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

fn getRendererInfo(r: *Renderer) Renderer.Error!*const Renderer.RendererInfo {
    return &.{
        .name = "d3d11 null renderer",
        .vendor = "none",
        .device = "software",
        .shading_language = .hlsl_5_0,
        .extensions = std.ArrayList([]const u8).init(r.allocator),
        .pipeline_cache_id = std.ArrayList(u8).init(r.allocator),
    };
}

fn getRenderingCapabilities(r: *Renderer) Renderer.Error!*const Renderer.RenderingCapabilities {
    return &.{
        .origin = .upper_left,
        .depth_range = .zero_to_one,
        .shading_languages = std.ArrayList(Renderer.ShadingLanguage).init(r.allocator),
        .formats = std.ArrayList(Renderer.format.Format).init(r.allocator),
        .features = .{},
        .limits = .{},
    };
}
