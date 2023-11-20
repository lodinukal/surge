const std = @import("std");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
const dxgi = win32.graphics.dxgi;
const dxgicommon = win32.graphics.dxgi.common;

const app = @import("../../../app/app.zig");

const Renderer = @import("../Renderer.zig");

const winappimpl = @import("../../../app/platform/windows.zig");

pub fn getSuitableAdapterInfo(
    allocator: std.mem.Allocator,
    factory: *dxgi.IDXGIFactory,
    pref: Renderer.RendererDevicePreference,
    adapter: *?*dxgi.IDXGIAdapter,
) ?Renderer.AdapterInfo {
    const wants_device = pref.amd or pref.intel or pref.nvidia;
    var info: Renderer.AdapterInfo = undefined;
    if (wants_device) {
        if (getAdapterInfo(allocator, factory, pref, &info, adapter)) {
            return info;
        }
    }

    if (getAdapterInfo(allocator, factory, .{}, &info, adapter)) {
        return info;
    }

    return null;
}

pub fn getAdapterInfo(
    allocator: std.mem.Allocator,
    factory: *dxgi.IDXGIFactory,
    pref: Renderer.RendererDevicePreference,
    info: *Renderer.AdapterInfo,
    adapter: ?*?*dxgi.IDXGIAdapter,
) bool {
    var adapter_index: u32 = 0;
    var found_adapter: ?*dxgi.IDXGIAdapter = null;
    while (true) : (adapter_index += 1) {
        var hr = factory.IDXGIFactory_EnumAdapters(adapter_index, &found_adapter);
        if (hr == dxgi.DXGI_ERROR_NOT_FOUND) {
            break;
        }

        var desc: dxgi.DXGI_ADAPTER_DESC = undefined;
        _ = found_adapter.?.IDXGIAdapter_GetDesc(&desc);

        const vendor = Renderer.DeviceVendor.fromId(@intCast(desc.VendorId));
        const is_preferred = vendor.matchDevicePreference(pref);
        if (is_preferred or pref.isNoPreference()) {
            info.allocator = allocator;
            info.vendor = vendor;
            info.name = winappimpl.convertToUtf8WithAllocator(allocator, @ptrCast(&desc.Description));
            info.memory = @intCast(desc.DedicatedVideoMemory);
            info.outputs = getAdapterOutputs(allocator, found_adapter.?) catch unreachable;
            if (is_preferred) {
                if (adapter) |a| a.* = found_adapter.?;
            }
            return true;
        }
    }
    return false;
}

pub fn getAdapterOutputs(
    allocator: std.mem.Allocator,
    adapter: *dxgi.IDXGIAdapter,
) !std.ArrayList(std.ArrayList(app.display.DisplayMode)) {
    var output_infos = std.ArrayList(std.ArrayList(app.display.DisplayMode)).init(allocator);

    var output: ?*dxgi.IDXGIOutput = null;
    var output_index: u32 = 0;
    while (true) : (output_index += 1) {
        if (output) |o| _ = o.IUnknown_Release();
        var hr = adapter.IDXGIAdapter_EnumOutputs(output_index, &output);
        if (hr == dxgi.DXGI_ERROR_NOT_FOUND) {
            break;
        }

        var desc: dxgi.DXGI_OUTPUT_DESC = undefined;
        _ = output.?.IDXGIOutput_GetDesc(&desc);

        var num_modes: u32 = 0;
        _ = output.?.IDXGIOutput_GetDisplayModeList(
            .R8G8B8A8_UNORM,
            dxgi.DXGI_ENUM_MODES_INTERLACED,
            &num_modes,
            null,
        );

        var stack_allocator = std.heap.stackFallback(1024, allocator);
        var temp_allocator = stack_allocator.get();

        var temp_modes = try std.ArrayList(dxgicommon.DXGI_MODE_DESC).initCapacity(
            temp_allocator,
            num_modes,
        );
        defer temp_modes.deinit();

        hr = output.?.IDXGIOutput_GetDisplayModeList(
            .R8G8B8A8_UNORM,
            dxgi.DXGI_ENUM_MODES_INTERLACED,
            &num_modes,
            @ptrCast(temp_modes.items),
        );

        if (winapi.zig.FAILED(hr)) {
            winappimpl.messageBox(
                allocator,
                "Failed to get display mode list",
                "Error: {}",
                .{hr},
                .OK,
            );
            return Renderer.Error.Unknown;
        }

        var video_outputs = std.ArrayList(app.display.DisplayMode).init(allocator);
        for (temp_modes.items) |dm| {
            try video_outputs.append(.{
                .refresh_rate = if (dm.RefreshRate.Denominator > 0) @divFloor(
                    dm.RefreshRate.Numerator,
                    dm.RefreshRate.Denominator,
                ) else 0,
                .resolution = .{ dm.Width, dm.Height },
            });
        }

        try output_infos.append(video_outputs);
    }

    return output_infos;
}

pub fn featureLevelToVersionString(level: d3d.D3D_FEATURE_LEVEL) []const u8 {
    return switch (level) {
        .@"12_1" => "12.1",
        .@"12_0" => "12.0",
        .@"11_1" => "11.1",
        .@"11_0" => "11.0",
        .@"10_1" => "10.1",
        .@"10_0" => "10.0",
        .@"9_3" => "9.3",
        .@"9_2" => "9.2",
        .@"9_1" => "9.1",
        else => "",
    };
}

pub fn featureLevelToShaderModel(level: d3d.D3D_FEATURE_LEVEL) Renderer.ShadingLanguage {
    return switch (level) {
        .@"12_1" => .hlsl_5_1,
        .@"12_0" => .hlsl_5_0,
        .@"11_1" => .hlsl_5_0,
        .@"11_0" => .hlsl_5_0,
        .@"10_1" => .hlsl_4_1,
        .@"10_0" => .hlsl_4_0,
        .@"9_3" => .hlsl_3_0,
        .@"9_2" => .hlsl_2_0a,
        .@"9_1" => .hlsl_2_0b,
        else => unreachable,
    };
}

pub fn isGreaterFeatureLevel(a: d3d.D3D_FEATURE_LEVEL, b: d3d.D3D_FEATURE_LEVEL) bool {
    return @intFromEnum(a) > @intFromEnum(b);
}

pub fn isGreaterOrEqualFeatureLevel(a: d3d.D3D_FEATURE_LEVEL, b: d3d.D3D_FEATURE_LEVEL) bool {
    return @intFromEnum(a) >= @intFromEnum(b);
}

pub fn getRenderingCapabilitiesFromFeatureLevel(
    allocator: std.mem.Allocator,
    level: d3d.D3D_FEATURE_LEVEL,
) !Renderer.RenderingCapabilities {
    var caps = Renderer.RenderingCapabilities{
        .formats = std.ArrayList(Renderer.format.Format).init(allocator),
        .shading_languages = try getHlslVersionsFromFeatureLevel(allocator, level),
    };
    const max_thread_group_count: u32 = 65535;

    caps.origin = .upper_left;
    caps.depth_range = .zero_to_one;
    try caps.formats.appendSlice(getSupportedFormats());

    if (isGreaterOrEqualFeatureLevel(level, .@"10_0")) {
        try caps.formats.appendSlice(&[_]Renderer.format.Format{
            .bc4unorm,
            .bc4snorm,
            .bc5unorm,
            .bc5snorm,
        });
    }

    caps.features = .{
        .@"3d_textures" = true,
        .cube_textures = true,
        .array_textures = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .cube_array_textures = isGreaterOrEqualFeatureLevel(level, .@"10_1"),
        .multisample_textures = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .multisample_array_textures = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .texture_views = true,
        .texture_view_format_swizzle = false,
        .buffer_views = true,
        .constant_buffers = true,
        .storage_buffers = true,
        .geometry_shaders = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .tessellation_shaders = isGreaterOrEqualFeatureLevel(level, .@"11_0"),
        .tessellator_shaders = false, // reassign based on above
        .compute_shaders = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .instancing = isGreaterOrEqualFeatureLevel(level, .@"9_3"),
        .offset_instancing = isGreaterOrEqualFeatureLevel(level, .@"9_3"),
        .indirect_draw = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .viewport_arrays = true,
        .conservative_rasterisation = false,
        .stream_outputs = isGreaterOrEqualFeatureLevel(level, .@"10_0"),
        .logic_ops = isGreaterOrEqualFeatureLevel(level, .@"11_1"),
        .pipeline_caching = false,
        .pipeline_statistics = true,
        .render_conditions = true,
    };
    caps.features.tessellator_shaders = caps.features.tessellation_shaders;

    caps.limits = .{
        .line_width_range = .{ 1.0, 1.0 },
        .max_texture_array_layers = if (isGreaterOrEqualFeatureLevel(level, .@"10_0")) 2048 else 256,
        .max_colour_attachments = getMaxRenderTargetsForFeatureLevel(level),
        .max_patch_vertices = 32,
        .max_1d_texture_size = getMaxTextureDimensionFromFeatureLevel(level),
        .max_2d_texture_size = getMaxTextureDimensionFromFeatureLevel(level),
        .max_3d_texture_size = if (isGreaterOrEqualFeatureLevel(level, .@"10_0")) 2048 else 256,
        .max_cube_texture_size = getMaxCubeTextureDimensionFromFeatureLevel(level),
        .max_anisotropy = if (isGreaterOrEqualFeatureLevel(level, .@"9_2")) 16 else 2,
        .max_compute_shader_work_groups = .{
            max_thread_group_count,
            max_thread_group_count,
            if (isGreaterOrEqualFeatureLevel(level, .@"11_0")) max_thread_group_count else 1,
        },
        .max_compute_shader_work_group_size = .{ 1024, 1024, 1024 },
        .max_stream_outputs = 4,
        .max_tesselation_factor = 64,
        .min_constant_buffer_alignment = 256,
        .min_sampled_buffer_alignment = 32,
        .min_storage_buffer_alignment = 32,
    };

    return caps;
}

pub fn getHlslVersionsFromFeatureLevel(
    allocator: std.mem.Allocator,
    level: d3d.D3D_FEATURE_LEVEL,
) !std.ArrayList(Renderer.ShadingLanguage) {
    var versions = std.ArrayList(Renderer.ShadingLanguage).init(allocator);

    try versions.append(.hlsl);
    try versions.append(.hlsl_2_0);

    inline for (.{
        .{ .@"9_1", .hlsl_2_0a },
        .{ .@"9_2", .hlsl_2_0b },
        .{ .@"9_3", .hlsl_3_0 },
        .{ .@"10_0", .hlsl_4_0 },
        .{ .@"10_1", .hlsl_4_1 },
        .{ .@"11_0", .hlsl_5_0 },
        .{ .@"12_0", .hlsl_5_1 },
    }) |pair| {
        if (isGreaterOrEqualFeatureLevel(level, pair.@"0")) {
            try versions.append(pair.@"1");
        }
    }

    return versions;
}

pub fn getSupportedFormats() []const Renderer.format.Format {
    return &[_]Renderer.format.Format{
        .a8unorm,
        .r8unorm,
        .r8snorm,
        .r8uint,
        .r8sint,
        .r16unorm,
        .r16snorm,
        .r16uint,
        .r16sint,
        .r16float,
        .r32uint,
        .r32sint,
        .r32float,
        .rg8unorm,
        .rg8snorm,
        .rg8uint,
        .rg8sint,
        .rg16unorm,
        .rg16snorm,
        .rg16uint,
        .rg16sint,
        .rg16float,
        .rg32uint,
        .rg32sint,
        .rg32float,
        .rgb32uint,
        .rgb32sint,
        .rgb32float,
        .rgba8unorm,
        .rgba8unorm_srgb,
        .rgba8snorm,
        .rgba8uint,
        .rgba8sint,
        .rgba16unorm,
        .rgba16snorm,
        .rgba16uint,
        .rgba16sint,
        .rgba16float,
        .rgba32uint,
        .rgba32sint,
        .rgba32float,
        .bgra8unorm,
        .bgra8unorm_srgb,
        .rgb10a2unorm,
        .rgb10a2uint,
        .rg11b10float,
        .rgb9e5float,
        .d16unorm,
        .d32float,
        .d24unorms8uint,
        .d32floats8x24uint,
        .bc1unorm,
        .bc1unorm_srgb,
        .bc2unorm,
        .bc2unorm_srgb,
        .bc3unorm,
        .bc3unorm_srgb,
    };
}

fn getMaxRenderTargetsForFeatureLevel(level: d3d.D3D_FEATURE_LEVEL) u32 {
    if (isGreaterOrEqualFeatureLevel(level, .@"10_0")) return 0;
    if (isGreaterOrEqualFeatureLevel(level, .@"9_3")) return 4;
    return 1;
}

pub fn getMaxTextureDimensionFromFeatureLevel(level: d3d.D3D_FEATURE_LEVEL) u32 {
    if (isGreaterOrEqualFeatureLevel(level, .@"11_0")) return 16384; // D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION
    if (isGreaterOrEqualFeatureLevel(level, .@"10_0")) return 8192; // D3D10_REQ_TEXTURE2D_U_OR_V_DIMENSION
    if (isGreaterOrEqualFeatureLevel(level, .@"9_3")) return 4096;
    return 2048;
}

pub fn getMaxCubeTextureDimensionFromFeatureLevel(level: d3d.D3D_FEATURE_LEVEL) u32 {
    if (isGreaterOrEqualFeatureLevel(level, .@"11_0")) return 16384; // D3D11_REQ_TEXTURECUBE_DIMENSION
    if (isGreaterOrEqualFeatureLevel(level, .@"10_0")) return 8192; // D3D10_REQ_TEXTURECUBE_DIMENSION
    if (isGreaterOrEqualFeatureLevel(level, .@"9_3")) return 4096;
    return 512;
}
