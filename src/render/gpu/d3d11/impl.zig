const std = @import("std");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const common = @import("../../../core/common.zig");
const util = @import("../../../util.zig");

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

    .createBuffer = &createBuffer,
    .destroyBuffer = &destroyBuffer,
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

    state_cache: D3D11StateCache = undefined,
    // command_queue: ?*d3d11.ID3D11CommandQueue = null,

    // objects
    swapchains: Pool(D3D11SwapChain, 2), // i think 2 is more than enough for now (2 game views)
    shaders: DynamicPool(D3D11Shader),
    buffers: DynamicPool(D3D11Buffer),
};
pub var state: RendererState = undefined;

fn init(r: *Renderer, descriptor: Renderer.RendererDescriptor) Renderer.Error!void {
    state = .{
        .swapchains = Pool(D3D11SwapChain, 2).init(),
        .shaders = DynamicPool(D3D11Shader).init(r.allocator),
        .buffers = DynamicPool(D3D11Buffer).init(r.allocator),
    };
    errdefer deinit(r);

    try createFactory(r);

    var preferred_adapter: ?*dxgi.IDXGIAdapter = null;
    defer d3dcommon.releaseIUnknown(dxgi.IDXGIAdapter, &preferred_adapter);
    querySuitableAdapter(r, descriptor, &preferred_adapter);

    try createDeviceAndContext(r, preferred_adapter);

    loadRendererInfo(r) catch return Renderer.Error.InitialisationFailed;
    loadRenderingCapabilities(r) catch return Renderer.Error.InitialisationFailed;
}

fn deinit(r: *Renderer) void {
    var sh_it = state.shaders.iterator();
    while (sh_it.next()) |h| {
        if (state.shaders.getColdMutable(h)) |sh| {
            sh.deinit();
        }
    }
    state.shaders.deinit();

    var b_it = state.buffers.iterator();
    while (b_it.next()) |h| {
        if (state.buffers.getColdMutable(h)) |b| {
            b.deinit();
        }
    }
    state.buffers.deinit();

    var sc_it = state.swapchains.iterator();
    while (sc_it.next()) |h| {
        if (state.swapchains.getColdMutable(h)) |sc| {
            sc.deinit() catch {};
        }
    }

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
    d3dcommon
        .d3dcommon.releaseIUnknown(dxgi.IDXGIFactory, &state.factory);
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
    ppImmediateContext: ?*?*d3d11.ID3D11DeviceContext1,
) callconv(@import("std").os.windows.WINAPI) win32.foundation.HRESULT;

fn createDeviceAndContext(r: *Renderer, adapter: ?*dxgi.IDXGIAdapter) !void {
    const feature_levels = [_]d3d.D3D_FEATURE_LEVEL{
        .@"11_0",
    };

    var base_device: ?*d3d11.ID3D11Device = null;
    defer d3dcommon.releaseIUnknown(d3d11.ID3D11Device, &base_device);
    var base_device_context: ?*d3d11.ID3D11DeviceContext1 = null;
    defer d3dcommon.releaseIUnknown(d3d11.ID3D11DeviceContext1, &base_device_context);

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
                d3dcommon.releaseIUnknown(d3d11.ID3D11InfoQueue, &info_queue);
            }
        }
    }
}

fn cleanupDeviceAndContext() void {
    d3dcommon.releaseIUnknown(d3d11.ID3D11Debug, &state.debug_layer);
    d3dcommon.releaseIUnknown(d3d11.ID3D11DeviceContext1, &state.device_context);
    d3dcommon.releaseIUnknown(d3d11.ID3D11Device, &state.device);
}

fn querySuitableAdapter(r: *Renderer, descriptor: Renderer.RendererDescriptor, adapter: *?*dxgi.IDXGIAdapter) void {
    state.adapter_info = d3dcommon.getSuitableAdapterInfo(
        r.allocator,
        state.factory.?,
        descriptor.preference,
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

fn createStateCacheAndCommandQueue(r: *Renderer) void {
    state.state_cache.init(r.allocator, state.device_context);
}

// StateCache
const D3D11StateCache = struct {
    pub const ChangedBitField = packed struct {
        viewports: bool,
        scissors: bool,

        primitive_topology: bool = false,
        input_layout: bool = false,

        vertex_shader: bool = false,
        hull_shader: bool = false,
        domain_shader: bool = false,
        geometry_shader: bool = false,
        fragment_shader: bool = false,
        compute_shader: bool = false,

        rasteriser_state: bool = false,
        depth_stencil_ref_state: bool = false,
        blend_state_factor_sample: bool = false,
    };
    pub const Changed = struct {
        viewports: [d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]Renderer.Viewport,
        used_viewports: u32 = 0,
        scissors: [d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]Renderer.Scissor,
        used_scissors: u32 = 0,

        primitive_topology: d3d.D3D_PRIMITIVE_TOPOLOGY = ._PRIMITIVE_TOPOLOGY_UNDEFINED,
        input_layout: ?*d3d11.ID3D11InputLayout = null,

        vertex_shader: ?*d3d11.ID3D11VertexShader = null,
        hull_shader: ?*d3d11.ID3D11HullShader = null,
        domain_shader: ?*d3d11.ID3D11DomainShader = null,
        geometry_shader: ?*d3d11.ID3D11GeometryShader = null,
        fragment_shader: ?*d3d11.ID3D11PixelShader = null,
        compute_shader: ?*d3d11.ID3D11ComputeShader = null,

        rasteriser_state: ?*d3d11.ID3D11RasterizerState = null,
        depth_stencil_state: ?*d3d11.ID3D11DepthStencilState = null, // linked with the one below
        stencil_ref: u32 = 0,
        blend_state: ?*d3d11.ID3D11BlendState = null, // linked with the two below
        blend_factor: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
        sample_mask: u32 = 0,
    };

    context: ?*d3d11.ID3D11DeviceContext1 = null,
    constant_staging_pool: D3D11StagingBufferPool = undefined,
    changed_fields: ChangedBitField = .{},
    changed: Changed = .{},

    const constant_buffer_chunk_size: u32 = 4096;

    pub fn init(self: *D3D11StateCache, allocator: std.mem.Allocator, context: *d3d11.ID3D11DeviceContext1) void {
        self.context = context;
        d3dcommon.refIUnknown(d3d11.ID3D11DeviceContext1, &self.context);
        self.constant_staging_pool = D3D11StagingBufferPool.init(
            allocator,
            context,
            constant_buffer_chunk_size,
            .DYNAMIC,
            .WRITE,
            .CONSTANT_BUFFER,
        );
    }

    pub fn deinit(self: *D3D11StateCache) void {
        self.constant_staging_pool.deinit();
        d3dcommon.releaseIUnknown(d3d11.ID3D11DeviceContext1, &self.context);
    }

    pub fn setViewports(
        self: *D3D11StateCache,
        viewports: []const Renderer.Viewport,
    ) void {
        self.changed_fields.viewports = true;
        self.changed.used_viewports = 0;
        for (
            viewports,
            0..@min(viewports.len, d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE),
        ) |v, i| {
            self.changed.viewports[i] = v;
            self.changed.used_viewports += 1;
        }
    }

    pub fn setScissors(
        self: *D3D11StateCache,
        scissors: []const Renderer.Scissor,
    ) void {
        self.changed_fields.scissors = true;
        self.changed.used_scissors = 0;
        for (
            scissors,
            0..@min(scissors.len, d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE),
        ) |s, i| {
            self.changed.scissors[i] = s;
            self.changed.used_scissors += 1;
        }
    }

    pub fn setPrimitiveTopology(
        self: *D3D11StateCache,
        topology: Renderer.PrimitiveTopology,
    ) void {
        self.changed_fields.primitive_topology = true;
        self.changed.primitive_topology = d3dcommon.mapPrimitiveTopology(topology);
    }

    pub fn setInputLayout(
        self: *D3D11StateCache,
        layout: ?*d3d11.ID3D11InputLayout,
    ) void {
        self.changed_fields.input_layout = true;
        self.changed.input_layout = layout;
    }

    pub fn setVertexShader(
        self: *D3D11StateCache,
        shader: ?*d3d11.ID3D11VertexShader,
    ) void {
        self.changed_fields.vertex_shader = true;
        self.changed.vertex_shader = shader;
    }

    pub fn setHullShader(
        self: *D3D11StateCache,
        shader: ?*d3d11.ID3D11HullShader,
    ) void {
        self.changed_fields.hull_shader = true;
        self.changed.hull_shader = shader;
    }

    pub fn setDomainShader(
        self: *D3D11StateCache,
        shader: ?*d3d11.ID3D11DomainShader,
    ) void {
        self.changed_fields.domain_shader = true;
        self.changed.domain_shader = shader;
    }

    pub fn setGeometryShader(
        self: *D3D11StateCache,
        shader: ?*d3d11.ID3D11GeometryShader,
    ) void {
        self.changed_fields.geometry_shader = true;
        self.changed.geometry_shader = shader;
    }

    pub fn setFragmentShader(
        self: *D3D11StateCache,
        shader: ?*d3d11.ID3D11PixelShader,
    ) void {
        self.changed_fields.fragment_shader = true;
        self.changed.fragment_shader = shader;
    }

    pub fn setComputeShader(
        self: *D3D11StateCache,
        shader: ?*d3d11.ID3D11ComputeShader,
    ) void {
        self.changed_fields.compute_shader = true;
        self.changed.compute_shader = shader;
    }

    pub fn setRasteriserState(
        self: *D3D11StateCache,
        rasteriser_state: ?*d3d11.ID3D11RasterizerState,
    ) void {
        self.changed_fields.rasteriser_state = true;
        self.changed.rasteriser_state = rasteriser_state;
    }

    pub fn setDepthStencilState(
        self: *D3D11StateCache,
        depth_stencil_state: ?*d3d11.ID3D11DepthStencilState,
        stencil_ref: ?u32,
    ) void {
        self.changed_fields.depth_stencil_ref_state = true;
        self.changed.depth_stencil_state = depth_stencil_state;
        if (stencil_ref) |sr| self.changed.stencil_ref = sr;
    }

    pub fn setStencilRef(
        self: *D3D11StateCache,
        stencil_ref: u32,
    ) void {
        self.changed_fields.depth_stencil_ref_state = true;
        self.changed.stencil_ref = stencil_ref;
    }

    pub fn setBlendState(
        self: *D3D11StateCache,
        blend_state: ?*d3d11.ID3D11BlendState,
        blend_factor: ?[4]f32,
        sample_mask: ?u32,
    ) void {
        self.changed_fields.blend_state_factor_sample = true;
        self.changed.blend_state = blend_state;
        if (blend_factor) |bf| self.changed.blend_factor = bf;
        if (sample_mask) |sm| self.changed.sample_mask = sm;
    }

    pub fn setBlendFactor(
        self: *D3D11StateCache,
        blend_factor: [4]f32,
    ) void {
        self.changed_fields.blend_state_factor_sample = true;
        self.changed.blend_factor = blend_factor;
    }

    pub fn setConstantBuffers(
        self: *D3D11StateCache,
        start_slot: u32,
        buffers: []const *d3d11.ID3D11Buffer,
        stages: Renderer.Shader.ShaderStages,
    ) void {
        if (stages.vertex) {
            self.context.?.ID3D11DeviceContext_VSSetConstantBuffers(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
            );
        }
        if (stages.hull) {
            self.context.?.ID3D11DeviceContext_HSSetConstantBuffers(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
            );
        }
        if (stages.domain) {
            self.context.?.ID3D11DeviceContext_DSSetConstantBuffers(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
            );
        }
        if (stages.geometry) {
            self.context.?.ID3D11DeviceContext_GSSetConstantBuffers(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
            );
        }
        if (stages.fragment) {
            self.context.?.ID3D11DeviceContext_PSSetConstantBuffers(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
            );
        }
        if (stages.compute) {
            self.context.?.ID3D11DeviceContext_CSSetConstantBuffers(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
            );
        }
    }

    pub fn setConstantBuffersRange(
        self: *D3D11StateCache,
        start_slot: u32,
        buffers: []const *d3d11.ID3D11Buffer,
        offsets: []const u32,
        sizes: []const u32,
        stages: Renderer.Shader.ShaderStages,
    ) void {
        if (stages.vertex) {
            self.context.?.ID3D11DeviceContext1_VSSetConstantBuffers1(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
                @ptrCast(offsets),
                sizes,
            );
        }
        if (stages.hull) {
            self.context.?.ID3D11DeviceContext1_HSSetConstantBuffers1(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
                @ptrCast(offsets),
                sizes,
            );
        }
        if (stages.domain) {
            self.context.?.ID3D11DeviceContext1_DSSetConstantBuffers1(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
                @ptrCast(offsets),
                sizes,
            );
        }
        if (stages.geometry) {
            self.context.?.ID3D11DeviceContext1_GSSetConstantBuffers1(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
                @ptrCast(offsets),
                sizes,
            );
        }
        if (stages.fragment) {
            self.context.?.ID3D11DeviceContext1_PSSetConstantBuffers1(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
                @ptrCast(offsets),
                sizes,
            );
        }
        if (stages.compute) {
            self.context.?.ID3D11DeviceContext1_CSSetConstantBuffers1(
                start_slot,
                buffers.len,
                @ptrCast(buffers),
                @ptrCast(offsets),
                sizes,
            );
        }
    }

    pub fn setShaderResources(
        self: *D3D11StateCache,
        start_slot: u32,
        resources: []const *d3d11.ID3D11ShaderResourceView,
        stages: Renderer.Shader.ShaderStages,
    ) void {
        if (stages.vertex) {
            self.context.?.ID3D11DeviceContext_VSSetShaderResources(
                start_slot,
                resources.len,
                @ptrCast(resources),
            );
        }
        if (stages.hull) {
            self.context.?.ID3D11DeviceContext_HSSetShaderResources(
                start_slot,
                resources.len,
                @ptrCast(resources),
            );
        }
        if (stages.domain) {
            self.context.?.ID3D11DeviceContext_DSSetShaderResources(
                start_slot,
                resources.len,
                @ptrCast(resources),
            );
        }
        if (stages.geometry) {
            self.context.?.ID3D11DeviceContext_GSSetShaderResources(
                start_slot,
                resources.len,
                @ptrCast(resources),
            );
        }
        if (stages.fragment) {
            self.context.?.ID3D11DeviceContext_PSSetShaderResources(
                start_slot,
                resources.len,
                @ptrCast(resources),
            );
        }
        if (stages.compute) {
            self.context.?.ID3D11DeviceContext_CSSetShaderResources(
                start_slot,
                resources.len,
                @ptrCast(resources),
            );
        }
    }

    pub fn setUnorderedAccessViews(
        self: *D3D11StateCache,
        start_slot: u32,
        uavs: []const *d3d11.ID3D11UnorderedAccessView,
        initial_counts: []const u32,
        stages: Renderer.Shader.ShaderStages,
    ) void {
        if (stages.fragment) {
            self.context.?.ID3D11DeviceContext_OMSetRenderTargetsAndUnorderedAccessViews(
                d3d11.D3D11_KEEP_RENDER_TARGETS_AND_DEPTH_STENCIL,
                null,
                null,
                start_slot,
                uavs.len,
                @ptrCast(uavs),
                @ptrCast(initial_counts),
            );
        }
        if (stages.compute) {
            self.context.?.ID3D11DeviceContext_CSSetUnorderedAccessViews(
                start_slot,
                uavs.len,
                @ptrCast(uavs),
                @ptrCast(initial_counts),
            );
        }
    }

    pub fn setSamplers(
        self: *D3D11StateCache,
        start_slot: u32,
        samplers: []const *d3d11.ID3D11SamplerState,
        stages: Renderer.Shader.ShaderStages,
    ) void {
        if (stages.vertex) {
            self.context.?.ID3D11DeviceContext_VSSetSamplers(
                start_slot,
                samplers.len,
                @ptrCast(samplers),
            );
        }
        if (stages.hull) {
            self.context.?.ID3D11DeviceContext_HSSetSamplers(
                start_slot,
                samplers.len,
                @ptrCast(samplers),
            );
        }
        if (stages.domain) {
            self.context.?.ID3D11DeviceContext_DSSetSamplers(
                start_slot,
                samplers.len,
                @ptrCast(samplers),
            );
        }
        if (stages.geometry) {
            self.context.?.ID3D11DeviceContext_GSSetSamplers(
                start_slot,
                samplers.len,
                @ptrCast(samplers),
            );
        }
        if (stages.fragment) {
            self.context.?.ID3D11DeviceContext_PSSetSamplers(
                start_slot,
                samplers.len,
                @ptrCast(samplers),
            );
        }
        if (stages.compute) {
            self.context.?.ID3D11DeviceContext_CSSetSamplers(
                start_slot,
                samplers.len,
                @ptrCast(samplers),
            );
        }
    }

    pub fn setGraphicsStaticSampler(
        self: *D3D11StateCache,
        static_sampler: *const D3D11StaticSampler,
    ) void {
        if (static_sampler.stage.vertex) {
            self.context.?.ID3D11DeviceContext_VSSetSamplers(
                static_sampler.slot,
                1,
                @ptrCast(&static_sampler.sampler_state),
            );
        }
        if (static_sampler.stage.hull) {
            self.context.?.ID3D11DeviceContext_HSSetSamplers(
                static_sampler.slot,
                1,
                @ptrCast(&static_sampler.sampler_state),
            );
        }
        if (static_sampler.stage.domain) {
            self.context.?.ID3D11DeviceContext_DSSetSamplers(
                static_sampler.slot,
                1,
                @ptrCast(&static_sampler.sampler_state),
            );
        }
        if (static_sampler.stage.geometry) {
            self.context.?.ID3D11DeviceContext_GSSetSamplers(
                static_sampler.slot,
                1,
                @ptrCast(&static_sampler.sampler_state),
            );
        }
        if (static_sampler.stage.fragment) {
            self.context.?.ID3D11DeviceContext_PSSetSamplers(
                static_sampler.slot,
                1,
                @ptrCast(&static_sampler.sampler_state),
            );
        }
    }

    pub fn setComputeStaticSampler(
        self: *D3D11StateCache,
        static_sampler: *const D3D11StaticSampler,
    ) void {
        if (static_sampler.stage.compute) {
            self.context.?.ID3D11DeviceContext_CSSetSamplers(
                static_sampler.slot,
                1,
                @ptrCast(&static_sampler.sampler_state),
            );
        }
    }

    pub fn setConstants(
        self: *D3D11StateCache,
        slot: u32,
        constants: []const u8,
        stages: Renderer.Shader.ShaderStages,
    ) !void {
        const alignment = 16 * 16;
        var range = try self.constant_staging_pool.write(
            constants,
            alignment,
        );

        var buffers: []?*d3d11.ID3D11Buffer = .{range.buffer};
        var offsets: []u32 = .{range.offset / 16};
        var sizes: []u32 = .{range.size / 16};

        self.setConstantBuffersRange(
            slot,
            buffers,
            offsets,
            sizes,
            stages,
        );
    }

    pub fn resetStagingBufferPools(self: *D3D11StateCache) void {
        self.constant_staging_pool.reset();
    }

    pub fn apply(self: *D3D11StateCache) void {
        // Viewports
        if (self.changed_fields.viewports) {
            var viewports: [d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]d3d11.D3D11_VIEWPORT = undefined;
            for (self.changed.viewports, 0..self.changed.used_viewports) |v, i| {
                viewports[i] = .{
                    .TopLeftX = v.x,
                    .TopLeftY = v.y,
                    .Width = v.width,
                    .Height = v.height,
                    .MinDepth = v.min_depth,
                    .MaxDepth = v.max_depth,
                };
            }
            self.context.?.ID3D11DeviceContext_RSSetViewports(
                self.changed.used_viewports,
                &viewports,
            );
            self.changed.used_viewports = 0;
        }
        // Scissors
        if (self.changed_fields.scissors) {
            var scissors: [d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]d3d11.D3D11_RECT = undefined;
            for (self.changed.scissors, 0..self.changed.used_scissors) |s, i| {
                scissors[i] = .{
                    .left = s.x,
                    .top = s.y,
                    .right = s.x + s.width,
                    .bottom = s.y + s.height,
                };
            }
            self.context.?.ID3D11DeviceContext_RSSetScissorRects(
                self.changed.used_scissors,
                &scissors,
            );
            self.changed.used_scissors = 0;
        }
        // Input Assembly
        if (self.changed_fields.primitive_topology) {
            self.context.?.ID3D11DeviceContext_IASetPrimitiveTopology(
                self.changed.primitive_topology,
            );
        }
        if (self.changed_fields.input_layout) {
            self.context.?.ID3D11DeviceContext_IASetInputLayout(
                @ptrCast(self.changed.input_layout),
            );
        }
        // Shaders
        if (self.changed_fields.vertex_shader) {
            self.context.?.ID3D11DeviceContext_VSSetShader(
                @ptrCast(self.changed.vertex_shader),
                null,
                0,
            );
        }
        if (self.changed_fields.hull_shader) {
            self.context.?.ID3D11DeviceContext_HSSetShader(
                @ptrCast(self.changed.hull_shader),
                null,
                0,
            );
        }
        if (self.changed_fields.domain_shader) {
            self.context.?.ID3D11DeviceContext_DSSetShader(
                @ptrCast(self.changed.domain_shader),
                null,
                0,
            );
        }
        if (self.changed_fields.geometry_shader) {
            self.context.?.ID3D11DeviceContext_GSSetShader(
                @ptrCast(self.changed.geometry_shader),
                null,
                0,
            );
        }
        if (self.changed_fields.fragment_shader) {
            self.context.?.ID3D11DeviceContext_PSSetShader(
                @ptrCast(self.changed.fragment_shader),
                null,
                0,
            );
        }
        if (self.changed_fields.compute_shader) {
            self.context.?.ID3D11DeviceContext_CSSetShader(
                @ptrCast(self.changed.compute_shader),
                null,
                0,
            );
        }
        // Rasteriser State
        if (self.changed_fields.rasteriser_state) {
            self.context.?.ID3D11DeviceContext_RSSetState(
                @ptrCast(self.changed.rasteriser_state),
            );
        }
        // Output Merger
        if (self.changed_fields.depth_stencil_ref_state) {
            self.context.?.ID3D11DeviceContext_OMSetDepthStencilState(
                @ptrCast(self.changed.depth_stencil_state),
                self.changed.stencil_ref,
            );
        }
        if (self.changed_fields.blend_state_factor_sample) {
            self.context.?.ID3D11DeviceContext_OMSetBlendState(
                @ptrCast(self.changed.blend_state),
                &self.changed.blend_factor,
                self.changed.sample_mask,
            );
        }

        self.changed_fields = .{};
    }
};

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
        descriptor: *const Renderer.SwapChain.SwapChainDescriptor,
        window: *app.window.Window,
    ) Renderer.Error!void {
        self.* = .{};
        try self.base.init(descriptor);

        self.base.fn_present = &_present;
        self.base.fn_getCurrentSwapIndex = &_getCurrentSwapIndex;
        self.base.fn_getNumSwapBuffers = &_getNumSwapBuffers;
        self.base.fn_getColourFormat = &_getColourFormat;
        self.base.fn_getDepthStencilFormat = &_getDepthStencilFormat;
        self.base.fn_resizeBuffers = &_resizeBuffers;

        self.base.render_target.fn_getSamples = &_getSamples;

        self.depth_stencil_format = d3dcommon.pickDepthStencilFormat(
            descriptor.depth_bits,
            descriptor.stencil_bits,
        );

        self.base.setSurface(window);
        try self.createSwapChain(
            factory,
            descriptor.resolution,
            descriptor.samples,
            descriptor.buffers,
        );
        try self.recreateBuffers();
    }

    pub fn deinit(
        self: *D3D11SwapChain,
    ) Renderer.Error!void {
        // try self.base.deinit();
        d3dcommon.releaseIUnknown(dxgi.IDXGISwapChain, &self.swapchain);
    }

    // SwapChain implementations
    fn _present(self: *Renderer.SwapChain) Renderer.Error!void {
        return fromBaseMut(self).present();
    }

    pub fn present(self: *D3D11SwapChain) Renderer.Error!void {
        var clear: [4]f32 = .{ 0.9, 0.2, 0.5, 1.0 };
        _ = state.device_context.?.ID3D11DeviceContext_ClearRenderTargetView(
            @ptrCast(self.render_target_view),
            &clear,
        );

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
        d3dcommon.releaseIUnknown(dxgi.IDXGISwapChain, &self.swapchain);
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
    descriptor: *const Renderer.SwapChain.SwapChainDescriptor,
    window: *app.window.Window,
) Renderer.Error!Handle(Renderer.SwapChain) {
    _ = r;

    const handle = state.swapchains.put(
        null,
        undefined,
    ) catch return Renderer.Error.SwapChainCreationFailed;
    const sc = state.swapchains.getColdMutable(handle).?;
    try sc.init(state.factory.?, descriptor, window);
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

    base: Renderer.Shader = .{},

    holder: ?D3D11ShaderHolder = null,
    bytecode: ?*d3d.ID3DBlob = null,
    // report
    input_layout: ?*d3d11.ID3D11InputLayout = null,
    // cbuffer reflections

    pub fn init(
        self: *D3D11Shader,
        descriptor: *const Renderer.Shader.ShaderDescriptor,
    ) !void {
        self.* = .{};
        self.base.init(descriptor.type);

        if (self.buildShader(descriptor)) {
            try self.buildInputLayout(descriptor.vertex.input orelse &.{});
        } else return Renderer.Error.ShaderCreationFailed;
    }

    pub fn deinit(
        self: *D3D11Shader,
    ) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11InputLayout, &self.input_layout);
        if (self.holder) |*h| h.deinit();
        d3dcommon.releaseIUnknown(d3d.ID3DBlob, &self.bytecode);
    }

    pub fn buildShader(self: *D3D11Shader, descriptor: *const Renderer.Shader.ShaderDescriptor) bool {
        if (descriptor.source_type == .code_string) {
            return self.compileSource(descriptor);
        } else {
            return self.loadBinary(descriptor);
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

    fn compileSource(self: *D3D11Shader, descriptor: *const Renderer.Shader.ShaderDescriptor) bool {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        var null_terminated_source_name = allocator.dupeZ(
            u8,
            descriptor.name orelse "shader_",
        ) catch return false;

        var defines = std.ArrayList(d3d.D3D_SHADER_MACRO).initCapacity(
            allocator,
            descriptor.macros.len,
        ) catch return false;
        for (descriptor.macros) |m| {
            var macro: d3d.D3D_SHADER_MACRO = .{
                .Name = @ptrCast(allocator.dupeZ(u8, m.name) catch return false),
                .Definition = @ptrCast(allocator.dupeZ(u8, m.value orelse "") catch return false),
            };
            defines.appendAssumeCapacity(macro);
        }

        var profile_null_terminated = allocator.dupeZ(
            u8,
            descriptor.profile orelse "",
        ) catch return false;

        var entry_point_null_terminated = allocator.dupeZ(
            u8,
            descriptor.entry_point,
        ) catch return false;

        var errors: ?*d3d.ID3DBlob = null;
        d3dcommon.releaseIUnknown(d3d.ID3DBlob, &self.bytecode);
        const hr = D3DCompile(
            @ptrCast(descriptor.source),
            descriptor.source.len,
            null_terminated_source_name,
            if (defines.items.len < 1) null else @ptrCast(defines.items),
            @ptrFromInt(1),
            @ptrCast(entry_point_null_terminated),
            @ptrCast(profile_null_terminated),
            d3dcommon.getFxcFlags(descriptor.compile_info),
            0,
            &self.bytecode,
            &errors,
        );

        if (self.bytecode) |bc| {
            _ = bc;
            self.createHolderShader(
                descriptor.vertex.output orelse &.{},
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

    fn loadBinary(self: *D3D11Shader, descriptor: *const Renderer.Shader.ShaderDescriptor) bool {
        var buf: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();
        _ = allocator;

        self.bytecode = d3dcommon.createBlob(descriptor.source);
        if (self.bytecode != null and self.bytecode.?.ID3DBlob_GetBufferSize() > 0) {
            self.createHolderShader(descriptor.vertex.output orelse &.{}, null);
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
    descriptor: *const Renderer.Shader.ShaderDescriptor,
) Renderer.Error!Handle(Renderer.Shader) {
    _ = r;
    const handle = state.shaders.put(
        .undefined,
        undefined,
    ) catch return Renderer.Error.ShaderCreationFailed;
    const shader = state.shaders.getColdMutable(handle).?;
    try shader.init(descriptor);
    return handle.as(Renderer.Shader);
}

fn destroyShader(r: *Renderer, handle: Handle(Renderer.Shader)) void {
    _ = r;
    const as_handle = handle.as(D3D11Shader);
    const shader = state.shaders.getColdMutable(as_handle) orelse return;
    shader.deinit();
    state.shaders.remove(as_handle) catch {};
}

// Resource utils

fn getBufferBindFlags(binding: Renderer.Resource.BindingInfo) d3d11.D3D11_BIND_FLAG {
    if (binding.constant_buffer) return .CONSTANT_BUFFER;

    return d3d11.D3D11_BIND_FLAG.initFlags(.{
        .VERTEX_BUFFER = if (binding.vertex_buffer) 1 else 0,
        .INDEX_BUFFER = if (binding.index_buffer) 1 else 0,
        .STREAM_OUTPUT = if (binding.stream_output_buffer) 1 else 0,
        .SHADER_RESOURCE = if (binding.sampled or binding.copy_source) 1 else 0,
        .UNORDERED_ACCESS = if (binding.storage or binding.copy_destination) 1 else 0,
    });
}

fn getBufferUsage(desc: *const Renderer.Buffer.BufferDescriptor) d3d11.D3D11_USAGE {
    if (!desc.binding.storage and desc.info.dynamic) return .DYNAMIC;
    return .DEFAULT;
}

fn getCpuAccessFlagsFromInfo(info: Renderer.Resource.ResourceInfo) d3d11.D3D11_CPU_ACCESS_FLAG {
    return d3d11.D3D11_CPU_ACCESS_FLAG.initFlags(.{
        .WRITE = if (info.dynamic) 1 else 0,
    });
}

fn getCpuAccessFlags(access: Renderer.Resource.CPUAccess) d3d11.D3D11_CPU_ACCESS_FLAG {
    return d3d11.D3D11_CPU_ACCESS_FLAG.initFlags(.{
        .READ = if (access.read) 1 else 0,
        .WRITE = if (access.write) 1 else 0,
    });
}

fn getBufferMiscInfoFlags(desc: *const Renderer.Buffer.BufferDescriptor) d3d11.D3D11_RESOURCE_MISC_FLAG {
    return d3d11.D3D11_RESOURCE_MISC_FLAG.initFlags(.{
        .DRAWINDIRECT_ARGS = if (desc.binding.indirect_command_buffer) 1 else 0,
        .BUFFER_STRUCTURED = if (desc.isStructuredBuffer()) 1 else 0,
        .BUFFER_ALLOW_RAW_VIEWS = if (desc.isByteAddressBuffer()) 1 else 0,
    });
}

fn bindInfoNeedsBufferWithResourceView(binding: Renderer.Resource.BindingInfo) bool {
    return binding.sampled or binding.storage;
}

fn mapCpuAccess(access: Renderer.Resource.CPUAccess) d3d11.D3D11_MAP {
    if (access.read and !access.discard) return .READ;
    if (access.write and !access.discard) return .WRITE;
    if (access.write and access.discard) return .WRITE_DISCARD;
    if (access.read and access.write) return .READ_WRITE;
    unreachable;
}

// Buffer
pub const D3D11Buffer = struct {
    pub const Hot = *d3d11.ID3D11Buffer;
    pub const Cold = D3D11Buffer;

    base: Renderer.Buffer,

    buffer: ?*d3d11.ID3D11Buffer = null,
    cpu_access_buffer: ?*d3d11.ID3D11Buffer = null,

    size: u32 = 0,
    stride: u32 = 0,
    format: dxgi.common.DXGI_FORMAT = .UNKNOWN,
    usage: d3d11.D3D11_USAGE = .DEFAULT,

    mapped_write_range: [2]u32 = .{ 0, 0 },

    // resource views only
    srv: ?*d3d11.ID3D11ShaderResourceView = null,
    uav: ?*d3d11.ID3D11UnorderedAccessView = null,
    uav_flags: u32 = 0,
    initial_count: u32 = std.math.maxInt(u32),

    pub inline fn fromBaseMut(rt: *Renderer.Buffer) *D3D11Buffer {
        return @fieldParentPtr(D3D11Buffer, "base", rt);
    }

    pub inline fn fromBase(rt: *const Renderer.Buffer) *const D3D11Buffer {
        return @fieldParentPtr(D3D11Buffer, "base", @constCast(rt));
    }

    pub fn init(
        self: *D3D11Buffer,
        descriptor: *const Renderer.Buffer.BufferDescriptor,
        initial_data: ?*const anyopaque,
    ) !void {
        self.* = .{ .base = .{ .fn_getBufferDescriptor = _getBufferDescriptor } };
        try self.base.init(descriptor.binding);

        try self.createGpuBuffer(descriptor, initial_data);
        if (descriptor.cpu_access.read or descriptor.cpu_access.write) {
            try self.createCpuAccessBuffer(
                @intCast(@intFromEnum(getCpuAccessFlags(descriptor.cpu_access))),
                descriptor.stride,
            );
        }

        if (bindInfoNeedsBufferWithResourceView(descriptor.binding)) {
            try self.createResourceView(descriptor);
        }
    }

    pub fn deinit(
        self: *D3D11Buffer,
    ) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.buffer);
        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.cpu_access_buffer);

        d3dcommon.releaseIUnknown(d3d11.ID3D11ShaderResourceView, &self.srv);
        d3dcommon.releaseIUnknown(d3d11.ID3D11UnorderedAccessView, &self.uav);
    }

    fn _getBufferDescriptor(self: *const Renderer.Buffer) Renderer.Buffer.BufferDescriptor {
        return fromBase(self).getBufferDescriptor();
    }

    pub fn getBufferDescriptor(self: *const D3D11Buffer) Renderer.Buffer.BufferDescriptor {
        var native_desc: d3d11.D3D11_BUFFER_DESC = undefined;
        _ = self.buffer.?.ID3D11Buffer_GetDesc(&native_desc);

        var desc: Renderer.Buffer.BufferDescriptor = .{};
        desc.size = native_desc.ByteWidth;
        desc.binding = self.base.getBindingInfo();

        if (self.cpu_access_buffer) |cab| {
            var cab_native_desc: d3d11.D3D11_BUFFER_DESC = undefined;
            _ = cab.ID3D11Buffer_GetDesc(&cab_native_desc);

            if ((cab_native_desc.CPUAccessFlags & @intFromEnum(d3d11.D3D11_CPU_ACCESS_READ)) != 0) {
                desc.cpu_access.read = true;
            }
            if ((cab_native_desc.CPUAccessFlags & @intFromEnum(d3d11.D3D11_CPU_ACCESS_WRITE)) != 0) {
                desc.cpu_access.write = true;
            }
        }

        if (native_desc.Usage == .DYNAMIC) {
            desc.info.dynamic = true;
        }

        return desc;
    }

    fn getBufferSizeFromDescriptor(descriptor: *const Renderer.Buffer.BufferDescriptor) u32 {
        var size: u32 = @intCast(descriptor.size);
        if (descriptor.binding.constant_buffer) {
            size = std.mem.alignForward(u32, size, 16);
        }
        return size;
    }

    pub fn createGpuBuffer(
        self: *D3D11Buffer,
        descriptor: *const Renderer.Buffer.BufferDescriptor,
        initial_data: ?*const anyopaque,
    ) Renderer.Error!void {
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var temp_allocator = fba.allocator();

        var desc: d3d11.D3D11_BUFFER_DESC = undefined;
        desc.ByteWidth = getBufferSizeFromDescriptor(descriptor);
        desc.Usage = getBufferUsage(descriptor);
        desc.BindFlags = @intCast(@intFromEnum(getBufferBindFlags(descriptor.binding)));
        desc.CPUAccessFlags = @intCast(@intFromEnum(getCpuAccessFlagsFromInfo(descriptor.info)));
        desc.MiscFlags = @intCast(@intFromEnum(getBufferMiscInfoFlags(descriptor)));
        desc.StructureByteStride = descriptor.stride;

        if (initial_data) |data| {
            const sub_resource_data: d3d11.D3D11_SUBRESOURCE_DATA = .{
                .pSysMem = data,
                .SysMemPitch = 0,
                .SysMemSlicePitch = 0,
            };
            d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.buffer);
            const hr = state.device.?.ID3D11Device_CreateBuffer(
                &desc,
                &sub_resource_data,
                &self.buffer,
            );
            if (winappimpl.reportHResultError(
                temp_allocator,
                hr,
                "Failed to create GPU buffer",
            )) return Renderer.Error.BufferCreationFailed;
        } else {
            d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.buffer);
            const hr = state.device.?.ID3D11Device_CreateBuffer(
                &desc,
                null,
                &self.buffer,
            );
            if (winappimpl.reportHResultError(
                temp_allocator,
                hr,
                "Failed to create GPU buffer",
            )) return Renderer.Error.BufferCreationFailed;
        }

        self.size = desc.ByteWidth;
        self.stride = if (descriptor.vertex_attributes == null or descriptor.vertex_attributes.?.len == 0)
            0
        else
            desc.StructureByteStride;
        self.format = d3dcommon.mapFormat(descriptor.format);
        self.usage = desc.Usage;
    }

    pub fn createCpuAccessBuffer(self: *D3D11Buffer, access_flags: u32, stride: u32) !void {
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var temp_allocator = fba.allocator();

        var desc: d3d11.D3D11_BUFFER_DESC = undefined;
        desc.ByteWidth = self.size;
        desc.Usage = .DEFAULT;
        desc.BindFlags = @intFromEnum(d3d11.D3D11_BIND_FLAG.SHADER_RESOURCE);
        desc.CPUAccessFlags = access_flags;
        desc.MiscFlags = 0;
        desc.StructureByteStride = stride;

        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.cpu_access_buffer);
        const hr = state.device.?.ID3D11Device_CreateBuffer(
            &desc,
            null,
            &self.cpu_access_buffer,
        );
        if (winappimpl.reportHResultError(
            temp_allocator,
            hr,
            "Failed to create CPU access buffer",
        )) return Renderer.Error.BufferCreationFailed;
    }

    pub fn writeSubresource(self: *D3D11Buffer, context: *d3d11.ID3D11DeviceContext1, data: []const u8, offset: u32) !void {
        if (data.len + offset > self.size) return Renderer.Error.BufferSubresourceWriteOutOfBounds;

        const is_whole_buffer = offset == 0 and data.len == self.size;

        if (self.usage == .DYNAMIC) {
            if (is_whole_buffer) {
                var mapped_subresource: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
                if (winapi.zig.SUCCEEDED(context.ID3D11DeviceContext_Map(
                    @ptrCast(self.buffer),
                    0,
                    .DISCARD,
                    0,
                    &mapped_subresource,
                ))) {
                    var data_pointer: usize = @intFromPtr(mapped_subresource.pData.?);
                    data_pointer += offset;
                    const dst = @as([*]u8, @ptrFromInt(data_pointer))[0..data.len];
                    @memcpy(dst, data);
                }
            } else {
                self.writeWithSubresourceCopyWithCpuAccess(context, data, offset);
            }
        } else {
            if (is_whole_buffer) {
                // ASSERT(dataSize == GetSize(), "cannot update D3D11 buffer partially when it is created with static usage");
                context.ID3D11DeviceContext_UpdateSubresource(
                    @ptrCast(self.buffer),
                    0,
                    null,
                    @ptrCast(data),
                    0,
                    0,
                );
            } else if (self.base.getBindingInfo().constant_buffer) {
                self.writeWithSubresourceCopyWithCpuAccess(context, data, offset);
            } else {
                const dst_box: d3d11.D3D11_BOX = .{
                    .left = offset,
                    .top = 0,
                    .front = 0,
                    .right = offset + data.len,
                    .bottom = 1,
                    .back = 1,
                };
                context.ID3D11DeviceContext_UpdateSubresource(
                    @ptrCast(self.buffer),
                    0,
                    &dst_box,
                    @ptrCast(data),
                    0,
                    0,
                );
            }
        }
    }

    pub fn readSubresource(
        self: *D3D11Buffer,
        context: *d3d11.ID3D11DeviceContext1,
        data: []u8,
        offset: u32,
    ) !void {
        return self.readFromSubresourceCopyWithCpuAccess(context, data, offset);
    }

    fn getCpuAccessTypeForUsage(usage: d3d11.D3D11_USAGE, access: Renderer.Resource.CPUAccess) d3d11.D3D11_MAP {
        if (access.write and access.discard and usage != .DYNAMIC) return .WRITE;
        return mapCpuAccess(access);
    }

    pub fn map(
        self: *D3D11Buffer,
        context: *d3d11.ID3D11DeviceContext1,
        access: Renderer.Resource.CPUAccess,
        offset: u32,
        length: u32,
    ) ?[]u8 {
        if (offset + length > self.size) return null;

        var hr: win32.foundation.HRESULT = win32.foundation.S_OK;
        var mapped_subresource: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;

        if (self.cpu_access_buffer) |cab| {
            if (access.read) {
                if (offset == 0 and length == self.size) {
                    context.ID3D11DeviceContext_CopyResource(
                        @ptrCast(cab),
                        @ptrCast(self.buffer),
                    );
                } else {
                    const src_range: d3d11.D3D11_BOX = .{
                        .left = offset,
                        .top = 0,
                        .front = 0,
                        .right = offset + length,
                        .bottom = 1,
                        .back = 1,
                    };
                    context.ID3D11DeviceContext_CopySubresourceRegion(
                        @ptrCast(cab),
                        0,
                        offset,
                        0,
                        0,
                        @ptrCast(self.buffer),
                        0,
                        &src_range,
                    );
                }
            }

            if (access.write) {
                self.mapped_write_range[0] = offset;
                self.mapped_write_range[1] = offset + length;
            }

            hr = context.ID3D11DeviceContext_Map(
                @ptrCast(cab),
                0,
                getCpuAccessTypeForUsage(.DEFAULT, access),
                0,
                &mapped_subresource,
            );
        } else {
            hr = context.ID3D11DeviceContext_Map(
                @ptrCast(self.buffer),
                0,
                getCpuAccessTypeForUsage(self.usage, access),
                0,
                &mapped_subresource,
            );
        }

        return if (winapi.zig.SUCCEEDED(hr)) @as([*]u8, @ptrCast(
            mapped_subresource.pData.?,
        ))[0..length] else null;
    }

    pub fn unmap(self: *D3D11Buffer, context: *d3d11.ID3D11DeviceContext1) void {
        if (self.cpu_access_buffer) |cab| {
            context.ID3D11DeviceContext_Unmap(
                @ptrCast(cab),
                0,
            );
            if (self.mapped_write_range[0] < self.mapped_write_range[1]) {
                const dst_range: d3d11.D3D11_BOX = .{
                    .left = self.mapped_write_range[0],
                    .top = 0,
                    .front = 0,
                    .right = self.mapped_write_range[1],
                    .bottom = 1,
                    .back = 1,
                };
                context.ID3D11DeviceContext_CopySubresourceRegion(
                    @ptrCast(self.buffer),
                    0,
                    self.mapped_write_range[0],
                    0,
                    0,
                    @ptrCast(cab),
                    0,
                    &dst_range,
                );
                self.mapped_write_range[0] = 0;
                self.mapped_write_range[1] = 0;
            }
        } else {
            context.ID3D11DeviceContext_Unmap(
                @ptrCast(self.buffer),
                0,
            );
        }
    }

    pub fn readFromStagingBuffer(
        self: *D3D11Buffer,
        context: *d3d11.ID3D11DeviceContext1,
        staging_buffer: *d3d11.ID3D11Buffer,
        offset: u32,
        data: []u8,
        data_offset: u32,
    ) void {
        const src_range: d3d11.D3D11_BOX = .{
            .left = data_offset,
            .top = 0,
            .front = 0,
            .right = data_offset + data.len,
            .bottom = 1,
            .back = 1,
        };
        context.ID3D11DeviceContext_CopySubresourceRegion(
            @ptrCast(staging_buffer),
            0,
            offset,
            0,
            0,
            @ptrCast(self.buffer),
            0,
            &src_range,
        );

        var mapped_subresource: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
        if (winapi.zig.SUCCEEDED(context.ID3D11DeviceContext_Map(
            @ptrCast(staging_buffer),
            0,
            .READ,
            0,
            &mapped_subresource,
        ))) {
            var data_pointer: usize = @intFromPtr(mapped_subresource.pData.?);
            data_pointer += offset;
            const src = @as([*]u8, @ptrFromInt(data_pointer))[0..data.len];
            @memcpy(data, src);
            context.ID3D11DeviceContext_Unmap(@ptrCast(staging_buffer), 0);
        }
    }

    pub fn readFromSubresourceCopyWithCpuAccess(self: *D3D11Buffer, context: *d3d11.ID3D11DeviceContext1, data: []u8, offset: u32) void {
        const staging_buffer_desc: d3d11.D3D11_BUFFER_DESC = .{
            .ByteWidth = data.len,
            .Usage = .STAGING,
            .BindFlags = 0,
            .CPUAccessFlags = @intFromEnum(d3d11.D3D11_CPU_ACCESS_FLAG.READ),
            .MiscFlags = 0,
            .StructureByteStride = 0,
        };
        var staging_buffer: ?*d3d11.ID3D11Buffer = null;
        const hr = state.device.?.ID3D11Device_CreateBuffer(
            &staging_buffer_desc,
            null,
            &staging_buffer,
        );
        if (winappimpl.reportHResultError(
            .allocator,
            hr,
            "Failed to create staging buffer",
        )) return;

        self.readFromStagingBuffer(
            context,
            staging_buffer.?,
            0,
            data,
            offset,
        );

        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &staging_buffer);
    }

    pub fn writeWithStagingBuffer(
        self: *D3D11Buffer,
        context: *d3d11.ID3D11DeviceContext1,
        staging_buffer: *d3d11.ID3D11Buffer,
        data: []const u8,
        offset: u32,
    ) void {
        var mapped_subresource: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
        if (winapi.zig.SUCCEEDED(context.ID3D11DeviceContext_Map(
            @ptrCast(staging_buffer),
            0,
            .WRITE_DISCARD,
            0,
            &mapped_subresource,
        ))) {
            var data_pointer: usize = @intFromPtr(mapped_subresource.pData.?);
            data_pointer += offset;
            const dst = @as([*]u8, @ptrFromInt(data_pointer))[0..data.len];
            @memcpy(dst, data);
            context.ID3D11DeviceContext_Unmap(@ptrCast(staging_buffer), 0);
        }

        const src_range: d3d11.D3D11_BOX = .{
            .left = 0,
            .top = 0,
            .front = 0,
            .right = data.len,
            .bottom = 1,
            .back = 1,
        };
        context.ID3D11DeviceContext_CopySubresourceRegion(
            @ptrCast(self.buffer),
            0,
            offset,
            0,
            0,
            @ptrCast(staging_buffer),
            0,
            &src_range,
        );
    }

    pub fn writeWithSubresourceCopyWithCpuAccess(
        self: *D3D11Buffer,
        data: []const u8,
        offset: u32,
    ) void {
        const staging_buffer_desc: d3d11.D3D11_BUFFER_DESC = .{
            .ByteWidth = data.len,
            .Usage = .DYNAMIC,
            .BindFlags = @intFromEnum(d3d11.D3D11_BIND_FLAG.SHADER_RESOURCE),
            .CPUAccessFlags = @intFromEnum(d3d11.D3D11_CPU_ACCESS_FLAG.WRITE),
            .MiscFlags = 0,
            .StructureByteStride = 0,
        };
        var staging_buffer: ?*d3d11.ID3D11Buffer = null;
        const hr = state.device.?.ID3D11Device_CreateBuffer(
            &staging_buffer_desc,
            null,
            &staging_buffer,
        );
        if (winappimpl.reportHResultError(
            .allocator,
            hr,
            "Failed to create staging buffer",
        )) return;

        self.writeWithStagingBuffer(
            staging_buffer.?,
            data,
            offset,
        );

        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &staging_buffer);
    }

    fn getD3DRVFormat(descriptor: *const Renderer.Buffer.BufferDescriptor) dxgi.common.DXGI_FORMAT {
        if (descriptor.isTypedBuffer()) return d3dcommon.mapFormat(descriptor.format);
        if (descriptor.isByteAddressBuffer()) return .R32_TYPELESS;
        return .UNKNOWN;
    }

    fn getUAVFlags(descriptor: *const Renderer.Buffer.BufferDescriptor) u32 {
        if (!descriptor.binding.storage) return 0;
        if (descriptor.isStructuredBuffer()) {
            return @intCast(@intFromEnum(util.initEnum(d3d11.D3D11_BUFFER_UAV_FLAG, .{
                .APPEND = descriptor.info.append,
                .COUNTER = descriptor.info.counter,
            })));
        } else if (descriptor.isByteAddressBuffer()) {
            return @intFromEnum(d3d11.D3D11_BUFFER_UAV_FLAG.RAW);
        }
        return 0;
    }

    pub fn createResourceView(self: *D3D11Buffer, descriptor: *const Renderer.Buffer.BufferDescriptor) !void {
        self.uav_flags = getUAVFlags(descriptor);
        const stride = if (descriptor.isByteAddressBuffer()) 4 else descriptor.getStride();

        const format = getD3DRVFormat(descriptor);
        const elements = descriptor.size / stride;

        if (descriptor.binding.sampled) {
            d3dcommon.releaseIUnknown(d3d11.ID3D11ShaderResourceView, &self.srv);
            try self.createSubresourceSRV(&self.srv, format, 0, @intCast(elements));
        }
        if (descriptor.binding.storage) {
            d3dcommon.releaseIUnknown(d3d11.ID3D11UnorderedAccessView, &self.uav);
            try self.createSubresourceUAV(&self.uav, format, 0, @intCast(elements));
        }
    }

    pub fn createSubresourceSRV(
        self: *D3D11Buffer,
        out_srv: ?*?*d3d11.ID3D11ShaderResourceView,
        format: dxgi.common.DXGI_FORMAT,
        first: u32,
        elements: u32,
    ) !void {
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var temp_allocator = fba.allocator();

        var desc: d3d11.D3D11_SHADER_RESOURCE_VIEW_DESC = undefined;
        desc.Format = format;
        if (format == .R32_TYPELESS) {
            desc.ViewDimension = ._SRV_DIMENSION_BUFFEREX;
            desc.Anonymous.BufferEx.FirstElement = first;
            desc.Anonymous.BufferEx.NumElements = elements;
            desc.Anonymous.BufferEx.Flags = @intFromEnum(d3d11.D3D11_BUFFEREX_SRV_FLAG_RAW);
        } else {
            desc.ViewDimension = ._SRV_DIMENSION_BUFFER;
            desc.Anonymous.Buffer.Anonymous1.FirstElement = first;
            desc.Anonymous.Buffer.Anonymous2.NumElements = elements;
        }
        const hr = state.device.?.ID3D11Device_CreateShaderResourceView(
            @ptrCast(self.buffer),
            &desc,
            out_srv,
        );
        if (winappimpl.reportHResultError(
            temp_allocator,
            hr,
            "Failed to create buffer subresource SRV",
        )) return Renderer.Error.BufferCreationFailed;
    }

    pub fn createSubresourceUAV(
        self: *D3D11Buffer,
        out_uav: ?*?*d3d11.ID3D11UnorderedAccessView,
        format: dxgi.common.DXGI_FORMAT,
        first: u32,
        elements: u32,
    ) !void {
        var buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var temp_allocator = fba.allocator();

        var desc: d3d11.D3D11_UNORDERED_ACCESS_VIEW_DESC = undefined;
        desc.Format = format;
        desc.ViewDimension = .BUFFER;
        desc.Anonymous.Buffer.FirstElement = first;
        desc.Anonymous.Buffer.NumElements = elements;
        desc.Anonymous.Buffer.Flags = self.uav_flags;
        const hr = state.device.?.ID3D11Device_CreateUnorderedAccessView(
            @ptrCast(self.buffer),
            &desc,
            out_uav,
        );
        if (winappimpl.reportHResultError(
            temp_allocator,
            hr,
            "Failed to create buffer subresource UAV",
        )) return Renderer.Error.BufferCreationFailed;
    }
};

fn createBuffer(
    r: *Renderer,
    descriptor: *const Renderer.Buffer.BufferDescriptor,
    initial_data: ?*const anyopaque,
) Renderer.Error!Handle(Renderer.Buffer) {
    _ = r;
    const handle = state.buffers.put(
        undefined,
        undefined,
    ) catch return Renderer.Error.BufferCreationFailed;
    const buffer = state.buffers.getColdMutable(handle).?;
    try buffer.init(descriptor, initial_data);
    var hot = state.buffers.getHotMutable(handle);
    hot.?.* = buffer.buffer.?;
    return handle.as(Renderer.Buffer);
}

fn destroyBuffer(r: *Renderer, handle: Handle(Renderer.Buffer)) void {
    _ = r;
    const as_handle = handle.as(D3D11Buffer);
    const buffer = state.buffers.getColdMutable(as_handle) orelse return;
    buffer.deinit();
    state.buffers.remove(as_handle) catch {};
}

const D3D11BufferRange = struct {
    buffer: ?*d3d11.ID3D11Buffer = null,
    offset: u32 = 0,
    size: u32 = 0,
};

const D3D11StagingBuffer = struct {
    buffer: ?*d3d11.ID3D11Buffer = null,
    usage: d3d11.D3D11_USAGE = .STAGING,
    size: u32 = 0,
    offset: u32 = 0,

    fn cpuAccessFromUsage(usage: d3d11.D3D11_USAGE) d3d11.D3D11_CPU_ACCESS_FLAG {
        switch (usage) {
            .STAGING => return d3d11.D3D11_CPU_ACCESS_FLAG.initFlags(.{
                .READ = 1,
                .WRITE = 1,
            }),
            .DYNAMIC => return .WRITE,
            else => return 0,
        }
    }

    pub fn init(
        size: u32,
        usage: ?d3d11.D3D11_USAGE,
        cpu_access_flags: ?d3d11.D3D11_CPU_ACCESS_FLAG,
        bind_flags: ?d3d11.D3D11_BIND_FLAG,
    ) !D3D11StagingBuffer {
        var self = .{};
        self.size = size;
        self.usage = usage orelse .STAGING;
        const access = cpu_access_flags orelse d3d11.D3D11_CPU_ACCESS_FLAG.initFlags(.{
            .READ = 1,
            .WRITE = 1,
        });
        std.debug.assert(cpuAccessFromUsage(self.usage) == access);
        var desc: d3d11.D3D11_BUFFER_DESC = undefined;
        desc.ByteWidth = size;
        desc.Usage = self.usage;
        desc.BindFlags = if (bind_flags) |bf| @intFromEnum(bf) else 0;
        desc.CPUAccessFlags = @intFromEnum(access);
        desc.MiscFlags = 0;
        desc.StructureByteStride = 0;

        const hr = state.device.?.ID3D11Device_CreateBuffer(
            &desc,
            null,
            &self.buffer,
        );
        if (winappimpl.reportHResultError(
            .allocator,
            hr,
            "Failed to create staging buffer",
        )) return Renderer.Error.BufferCreationFailed;
    }

    pub fn deinit(self: *D3D11StagingBuffer) void {
        d3dcommon.releaseIUnknown(d3d11.ID3D11Buffer, &self.buffer);
    }

    pub fn reset(self: *D3D11StagingBuffer) void {
        self.offset = 0;
    }

    pub fn hasCapacity(self: *const D3D11StagingBuffer, size: u32) u32 {
        return self.offset + size <= self.size;
    }

    pub fn write(
        self: *D3D11StagingBuffer,
        context: ?*d3d11.ID3D11DeviceContext1,
        data: []const u8,
    ) void {
        if (self.usage == .DYNAMIC) {
            var subresource: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
            if (winapi.zig.SUCCEEDED(context.?.ID3D11DeviceContext_Map(
                @ptrCast(self.buffer),
                0,
                .WRITE_DISCARD,
                0,
                &subresource,
            ))) {
                var data_pointer: usize = @intFromPtr(subresource.pData.?);
                data_pointer += self.offset;
                const dst = @as([*]u8, @ptrFromInt(data_pointer))[0..data.len];
                @memcpy(dst, data);
                context.?.ID3D11DeviceContext_Unmap(@ptrCast(self.buffer), 0);
            }
        } else {
            const dst_box: d3d11.D3D11_BOX = .{
                .left = self.offset,
                .top = 0,
                .front = 0,
                .right = self.offset + data.len,
                .bottom = 1,
                .back = 1,
            };
            context.?.ID3D11DeviceContext_UpdateSubresource(
                @ptrCast(self.buffer),
                0,
                &dst_box,
                @ptrCast(data),
                0,
                0,
            );
        }
    }

    pub fn writeAndMove(self: *D3D11StagingBuffer, context: ?*d3d11.ID3D11DeviceContext1, data: []const u8, stride: u32) void {
        self.write(context, data);
        self.offset += @max(data.len, stride);
    }
};

const D3D11StagingBufferPool = struct {
    context: ?*d3d11.ID3D11DeviceContext1 = null,

    chunks: std.ArrayList(D3D11StagingBuffer),
    current_chunk: usize = 0,
    chunk_size: u32 = 0,
    usage: d3d11.D3D11_USAGE,
    cpu_access_flags: d3d11.D3D11_CPU_ACCESS_FLAG,
    bind_flags: d3d11.D3D11_BIND_FLAG,

    pub fn init(
        allocator: std.mem.Allocator,
        context: ?*d3d11.ID3D11DeviceContext1,
        chunk_size: u32,
        usage: ?d3d11.D3D11_USAGE,
        cpu_access_flags: ?d3d11.D3D11_CPU_ACCESS_FLAG,
        bind_flags: ?d3d11.D3D11_BIND_FLAG,
    ) D3D11StagingBufferPool {
        d3dcommon.refIUnknown(d3d11.ID3D11DeviceContext1, &context);
        return .{
            .context = context,
            .chunks = std.ArrayList(D3D11StagingBuffer).init(allocator),
            .chunk_size = chunk_size,
            .usage = usage orelse .STAGING,
            .cpu_access_flags = cpu_access_flags orelse d3d11.D3D11_CPU_ACCESS_FLAG.initFlags(.{
                .READ = 1,
                .WRITE = 1,
            }),
            .bind_flags = bind_flags orelse @enumFromInt(0),
        };
    }

    pub fn deinit(self: *D3D11StagingBufferPool) void {
        for (self.chunks.items) |*c| {
            c.deinit();
        }
        self.chunks.deinit();
        d3dcommon.releaseIUnknown(d3d11.ID3D11DeviceContext1, &self.context);
    }

    pub fn reset(self: *D3D11StagingBufferPool) void {
        for (self.chunks) |*c| {
            c.reset();
        }
        self.current_chunk = 0;
    }

    pub fn write(self: *D3D11StagingBufferPool, data: []const u8, alignment: ?u32) !D3D11BufferRange {
        const _alignment = alignment orelse 1;
        const size = std.mem.alignForward(u32, data.len, _alignment);

        if (self.current_chunk == self.chunks.items.len) {
            try self.allocateChunk(size);
        } else if (!self.chunks.items[self.current_chunk].hasCapacity(size)) {
            self.current_chunk += 1;
            if (self.current_chunk == self.chunks.items.len) {
                try self.allocateChunk(size);
            }
        }

        var chunk = &self.chunks.items[self.current_chunk];
        const range: D3D11BufferRange = .{
            .buffer = chunk.buffer,
            .offset = chunk.offset,
            .size = size,
        };
        chunk.write(self.context, data);
        return range;
    }

    fn allocateChunk(self: *D3D11StagingBufferPool, min_size: u32) !void {
        const size = @max(self.chunk_size, min_size);
        var chunk = try D3D11StagingBuffer.init(
            size,
            self.usage,
            self.cpu_access_flags,
            self.bind_flags,
        );
        self.chunks.append(chunk);
        self.current_chunk = self.chunks.items.len - 1;
    }
};

// Samplers
const D3D11StaticSampler = struct {
    slot: u32 = 0,
    stage: Renderer.Shader.ShaderStages = .{},
    sampler_state: ?*d3d11.ID3D11SamplerState = null,
};

const D3D11Sampler = struct {
    // base: Sampler
};

test {
    std.testing.refAllDecls(@This());
}
