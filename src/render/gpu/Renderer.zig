const std = @import("std");
const builtin = @import("builtin");

const app = @import("../../app/app.zig");

pub const format = @import("format.zig");

const Pool = @import("pool.zig").Pool;
const DynamicPool = @import("pool.zig").DynamicPool;
const Handle = @import("pool.zig").Handle;

const Self = @This();

pub var global_renderer: ?*Self = null;

pub const Error = error{
    RendererNotLoaded,
    InitialisationFailed,
    InvalidHandle,
    DeviceLost,
};

pub const RendererType = enum {
    d3d11,
    d3d12,
    gles,
    vulkan,
    metal,
    webgpu,
};

pub const SymbolTable = struct {
    init: *const fn (self: *Self) Error!void,
    deinit: *const fn (self: *Self) void,
    get_renderer_info: *const fn (self: *Self) Error!*const RendererInfo,
    get_rendering_capabilities: *const fn (self: *Self) Error!*const RenderingCapabilities,
};

allocator: std.mem.Allocator,
symbols: ?*const SymbolTable = null,
library_loaded: ?std.DynLib = null,
debug: bool = builtin.mode == .Debug, // TODO: make this a runtime option

pub fn availableRenderers() []const RendererType {
    return &[_]RendererType{
        .d3d11,
        // .d3d12,
        // .gles,
        // .vulkan,
        // .metal,
        // .webgpu,
    };
}

pub fn create(allocator: std.mem.Allocator) !*Self {
    if (global_renderer) |gr| return gr;
    var ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);
    try ptr.init(allocator);
    global_renderer = ptr;
    return ptr;
}

pub fn destroy(self: *Self) void {
    if (self == global_renderer) global_renderer = null;
    self.deinit();
    self.allocator.destroy(self);
}

pub fn init(self: *Self, allocator: std.mem.Allocator) Error!void {
    self.* = .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.unload();
}

const SymbolLoaderFn = *const fn () *const SymbolTable;
pub fn load(self: *Self, backend: RendererType) !void {
    if (self.loaded()) self.unload();
    switch (backend) {
        .d3d11 => {
            self.library_loaded = try std.DynLib.open("render_d3d11.dll");
            errdefer {
                self.library_loaded.?.close();
                self.library_loaded = null;
                self.symbols = null;
            }
            var symbols = self.library_loaded.?.lookup(
                SymbolLoaderFn,
                "getSymbols",
            ) orelse return Error.RendererNotLoaded;
            self.symbols = symbols();

            try self.symbols.?.init(self);
        },
        .d3d12 => {},
        .gles => {},
        .vulkan => {},
        .metal => {},
        .webgpu => {},
    }
}

pub fn unload(self: *Self) void {
    if (self.symbols) |s| {
        s.deinit(self);
        self.symbols = null;
    }
    if (self.library_loaded) |*lib| {
        lib.close();
    }
}

pub fn loaded(self: *const Self) bool {
    return self.symbols != null;
}

fn ensureLoaded(self: *Self) Error!void {
    if (self.symbols == null) {
        return Error.RendererNotLoaded;
    }
}

// Swapchain
// pub fn createSwapchain(
//     self: *Self,
//     swapchain_descriptor: *const Swapchain.SwapchainDescriptor,
//     window: *app.window.Window,
// ) !Handle(Swapchain) {
//     try self.ensureLoaded();
//     _ = swapchain_descriptor;
//     _ = window;
//     return Error.RendererNotLoaded;
// }

// pub fn destroySwapchain(self: *Self, swapchain: Handle(Swapchain)) !void {
//     try self.ensureLoaded();
//     _ = swapchain;
// }

// info

pub fn getRendererInfo(self: *Self) Error!*const RendererInfo {
    try self.ensureLoaded();
    return self.symbols.?.get_renderer_info(self);
}

pub fn getRenderingCapabilities(self: *Self) Error!*const RenderingCapabilities {
    try self.ensureLoaded();
    return self.symbols.?.get_rendering_capabilities(self);
}

test {
    std.testing.refAllDecls(format);
}

pub const ShadingLanguage = enum(u32) {
    const glsl_: u32 = 0x10000;
    const essl_: u32 = 0x20000;
    const hlsl_: u32 = 0x30000;
    const msl_: u32 = 0x40000;
    const spirv_: u32 = 0x50000;

    glsl = glsl_,
    glsl_110 = glsl_ | 110,
    glsl_120 = glsl_ | 120,
    glsl_130 = glsl_ | 130,
    glsl_140 = glsl_ | 140,
    glsl_150 = glsl_ | 150,
    glsl_330 = glsl_ | 330,
    glsl_400 = glsl_ | 400,
    glsl_410 = glsl_ | 410,
    glsl_420 = glsl_ | 420,
    glsl_430 = glsl_ | 430,
    glsl_440 = glsl_ | 440,
    glsl_450 = glsl_ | 450,
    glsl_460 = glsl_ | 460,

    essl = essl_,
    essl_100 = essl_ | 100,
    essl_300 = essl_ | 300,
    essl_310 = essl_ | 310,
    essl_320 = essl_ | 320,

    hlsl = hlsl_,
    hlsl_2_0 = hlsl_ | 200,
    hlsl_2_0a = hlsl_ | 201,
    hlsl_2_0b = hlsl_ | 202,
    hlsl_3_0 = hlsl_ | 300,
    hlsl_4_0 = hlsl_ | 400,
    hlsl_4_1 = hlsl_ | 410,
    hlsl_5_0 = hlsl_ | 500,
    hlsl_5_1 = hlsl_ | 510,
    hlsl_6_0 = hlsl_ | 600,
    hlsl_6_1 = hlsl_ | 610,
    hlsl_6_2 = hlsl_ | 620,
    hlsl_6_3 = hlsl_ | 630,
    hlsl_6_4 = hlsl_ | 640,

    msl = msl_,
    msl_1_0 = msl_ | 100,
    msl_1_1 = msl_ | 110,
    msl_1_2 = msl_ | 120,
    msl_2_0 = msl_ | 200,
    msl_2_1 = msl_ | 210,

    spirv = spirv_,
    spirv_100 = spirv_ | 100,

    pub fn getParent(self: ShadingLanguage) ShadingLanguage {
        return @enumFromInt(@intFromEnum(self) & 0xFFFF0000);
    }

    pub fn getSemver(self: ShadingLanguage) struct { u32, u32, u32 } {
        const ver = @intFromEnum(self) & 0x0000FFFF;
        return .{
            @as(u32, ver / 100),
            @as(u32, (ver / 10) % 10),
            @as(u32, ver % 10),
        };
    }

    pub fn getMajor(self: ShadingLanguage) u32 {
        return self.getSemver().@"0";
    }

    pub fn getMinor(self: ShadingLanguage) u32 {
        return self.getSemver().@"1";
    }

    pub fn getPatch(self: ShadingLanguage) u32 {
        return self.getSemver().@"2";
    }
};

test "ShadingLanguage" {
    const glsl = ShadingLanguage.glsl_450;
    try std.testing.expectEqual(ShadingLanguage.glsl, glsl.getParent());
    try std.testing.expectEqual(@as(u32, 4), glsl.getMajor());
    try std.testing.expectEqual(@as(u32, 5), glsl.getMinor());

    const hlsl = ShadingLanguage.hlsl_6_4;
    try std.testing.expectEqual(ShadingLanguage.hlsl, hlsl.getParent());
    try std.testing.expectEqual(@as(u32, 6), hlsl.getMajor());
    try std.testing.expectEqual(@as(u32, 4), hlsl.getMinor());

    const msl = ShadingLanguage.msl_2_1;
    try std.testing.expectEqual(ShadingLanguage.msl, msl.getParent());
    try std.testing.expectEqual(@as(u32, 2), msl.getMajor());
    try std.testing.expectEqual(@as(u32, 1), msl.getMinor());
}

pub const ScreenOrigin = enum { lower_left, upper_left };

pub const DepthRange = enum { minus_one_to_one, zero_to_one };

pub const CPUAccess = enum { read, write, write_discard, read_write };

pub const RenderSystemInfo = packed struct(u4) {
    debug: bool = false,
    nvidia: bool = false,
    amd: bool = false,
    intel: bool = false,
};

pub const RendererInfo = struct {
    name: []const u8,
    vendor: []const u8,
    device: []const u8,
    shading_language: ShadingLanguage,
    extensions: std.ArrayList([]const u8),
    pipeline_cache_id: std.ArrayList(u8),

    pub fn deinit(self: *RendererInfo) void {
        self.extensions.deinit();
        self.pipeline_cache_id.deinit();
    }
};

pub const RenderSystemCreateInfo = struct {
    info: RenderSystemInfo,
    debugger: ?*const u8 = null,
    specific_config: ?[]const u8 = null,
};

pub const RenderingFeatures = struct {
    @"3d_textures": bool = false,
    cube_textures: bool = false,
    array_textures: bool = false,
    cube_array_textures: bool = false,
    multisample_textures: bool = false,
    multisample_array_textures: bool = false,
    texture_views: bool = false,
    texture_view_format_swizzle: bool = false,
    buffer_views: bool = false,
    constant_buffers: bool = false,
    storage_buffers: bool = false,
    geometry_shaders: bool = false,
    tessellation_shaders: bool = false,
    tessellator_shaders: bool = false,
    compute_shaders: bool = false,
    instancing: bool = false,
    offset_instancing: bool = false,
    indirect_draw: bool = false,
    viewport_arrays: bool = false,
    conservative_rasterisation: bool = false,
    stream_outputs: bool = false,
    logic_ops: bool = false,
    pipeline_caching: bool = false,
    pipeline_statistics: bool = false,
    render_confitions: bool = false,
};

pub const RenderingLimits = struct {
    line_width_range: struct { f32, f32 } = .{ 1.0, 1.0 },
    max_texture_array_layers: u32 = 0,
    max_colour_attachments: u32 = 0,
    max_patch_vertices: u32 = 0,
    max_1d_texture_size: u32 = 0,
    max_2d_texture_size: u32 = 0,
    max_3d_texture_size: u32 = 0,
    max_cube_texture_size: u32 = 0,
    max_anisotropy: u32 = 0,
    max_compute_shader_work_groups: struct { u32, u32, u32 } = .{ 0, 0, 0 },
    max_compute_shader_work_group_size: struct { u32, u32, u32 } = .{ 0, 0, 0 },
    max_viewports: u32 = 0,
    max_viewport_dimensions: struct { u32, u32 } = .{ 0, 0 },
    max_buffer_size: u32 = 0,
    max_constant_buffer_size: u32 = 0,
    max_stream_outputs: u32 = 0,
    max_tesselation_factor: u32 = 0,
    min_constant_buffer_alignment: u32 = 0,
    min_sampled_buffer_alignment: u32 = 0,
    min_storage_buffer_alignment: u32 = 0,
    max_colour_buffer_samples: u32 = 0,
    max_depth_buffer_samples: u32 = 0,
    max_stencil_buffer_samples: u32 = 0,
    max_no_attachments_samples: u32 = 0,
};

pub const RenderingCapabilities = struct {
    origin: ScreenOrigin,
    depth_range: DepthRange,
    shading_languages: std.ArrayList(ShadingLanguage),
    formats: std.ArrayList(format.Format),
    features: RenderingFeatures,
    limits: RenderingLimits,

    pub fn deinit(self: *RenderingCapabilities) void {
        self.shading_languages.deinit();
        self.formats.deinit();
    }
};
