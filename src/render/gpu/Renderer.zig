const std = @import("std");
const builtin = @import("builtin");

const app = @import("../../app/app.zig");

pub const format = @import("format.zig");

const Pool = @import("pool.zig").Pool;
const DynamicPool = @import("pool.zig").DynamicPool;
pub const Handle = @import("pool.zig").Handle;

pub const RenderTarget = @import("RenderTarget.zig");
pub const SwapChain = @import("SwapChain.zig");
pub const Shader = @import("Shader.zig");
pub const VertexAttribute = @import("VertexAttribute.zig");
pub const VertexFormat = VertexAttribute.VertexFormat;
pub const FragmentAttribute = @import("FragmentAttribute.zig");
pub const Resource = @import("Resource.zig");
pub const ResourceHeap = @import("ResourceHeap.zig");
pub const Buffer = @import("Buffer.zig");
pub const Fence = struct {};
pub const Texture = @import("Texture.zig");
pub const RenderPass = @import("RenderPass.zig");
pub const PipelineLayout = @import("PipelineLayout.zig");
pub const PipelineState = @import("PipelineState.zig");
pub const Sampler = @import("Sampler.zig");
pub const QueryHeap = @import("QueryHeap.zig");
pub const CommandQueue = @import("CommandQueue.zig");
pub const CommandBuffer = @import("CommandBuffer.zig");
pub const Image = @import("Image.zig");

const Self = @This();

pub var global_renderer: ?*Self = null;

pub const Error = error{
    Unknown,
    RendererNotLoaded,
    InitialisationFailed,
    InvalidHandle,
    DeviceLost,

    // RenderTarget
    InvalidResolution,

    // SwapChain
    SwapChainCreationFailed,
    SwapChainBufferCreationFailed,
    SwapChainPresentFailed,

    // Shader
    ShaderCreationFailed,
    ShaderInputLayoutCreationFailed,

    // Buffer
    BufferCreationFailed,
    BufferSubresourceWriteOutOfBounds,

    // Fence
    FenceCreationFailed,

    // Texture
    TextureCreationFailed,
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
    init: *const fn (self: *Self, descriptor: RendererDescriptor) Error!void,
    deinit: *const fn (self: *Self) void,

    createSwapChain: *const fn (
        self: *Self,
        descriptor: *const SwapChain.SwapChainDescriptor,
        window: *app.window.Window,
    ) Error!Handle(SwapChain),
    /// Do not store this pointer returned, use the handle
    useSwapChain: *const fn (self: *const Self, swapchain: Handle(SwapChain)) Error!*const SwapChain,
    /// Do not store this pointer returned, use the handle
    useSwapChainMutable: *const fn (self: *Self, swapchain: Handle(SwapChain)) Error!*SwapChain,
    destroySwapChain: *const fn (self: *Self, swapchain: Handle(SwapChain)) void,

    createShader: *const fn (self: *Self, descriptor: *const Shader.ShaderDescriptor) Error!Handle(Shader),
    destroyShader: *const fn (self: *Self, shader: Handle(Shader)) void,

    createBuffer: *const fn (
        self: *Self,
        descriptor: *const Buffer.BufferDescriptor,
        initial_data: ?*const anyopaque,
    ) Error!Handle(Buffer),
    destroyBuffer: *const fn (self: *Self, buffer: Handle(Buffer)) void,

    createFence: *const fn (self: *Self) Error!Handle(Fence),
    destroyFence: *const fn (self: *Self, fence: Handle(Fence)) void,
};

pub const max_num_colour_attachments = 8;
pub const max_num_attachments = max_num_colour_attachments + 1;

backing_allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,
descriptor: RendererDescriptor = .{},
symbols: ?*const SymbolTable = null,
library_loaded: ?std.DynLib = null,
debug: bool = builtin.mode == .Debug, // TODO: make this a runtime option

renderer_info: RendererInfo = undefined,
rendering_capabilities: RenderingCapabilities = undefined,

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

pub fn create(allocator: std.mem.Allocator, descriptor: RendererDescriptor) !*Self {
    if (global_renderer) |gr| return gr;
    var ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);
    try ptr.init(allocator, descriptor);
    global_renderer = ptr;
    return ptr;
}

pub fn destroy(self: *Self) void {
    if (self == global_renderer) global_renderer = null;
    self.deinit();
    self.backing_allocator.destroy(self);
}

pub fn init(self: *Self, allocator: std.mem.Allocator, descriptor: RendererDescriptor) Error!void {
    self.* = .{
        .backing_allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .allocator = undefined,
        .descriptor = descriptor,
    };

    // self.allocator = self.arena.allocator();
    self.allocator = allocator;
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

            try self.symbols.?.init(self, self.descriptor);
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
        _ = self.arena.reset(.free_all);
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
pub fn createSwapchain(
    self: *Self,
    descriptor: *const SwapChain.SwapChainDescriptor,
    window: *app.window.Window,
) Error!Handle(SwapChain) {
    try self.ensureLoaded();
    return self.symbols.?.createSwapChain(self, descriptor, window);
}

/// Do not store this pointer returned, use the handle
pub fn useSwapchain(self: *const Self, swapchain: Handle(SwapChain)) Error!*const SwapChain {
    try self.ensureLoaded();
    return self.symbols.?.useSwapChain(self, swapchain);
}

/// Do not store this pointer returned, use the handle
pub fn useSwapchainMutable(self: *Self, swapchain: Handle(SwapChain)) Error!*SwapChain {
    try self.ensureLoaded();
    return self.symbols.?.useSwapChainMutable(self, swapchain);
}

pub fn destroySwapchain(self: *Self, swapchain: Handle(SwapChain)) Error!void {
    try self.ensureLoaded();
    self.symbols.?.destroySwapChain(self, swapchain);
}

pub fn createShader(self: *Self, descriptor: *const Shader.ShaderDescriptor) Error!Handle(Shader) {
    try self.ensureLoaded();
    return self.symbols.?.createShader(self, descriptor);
}

pub fn destroyShader(self: *Self, shader: Handle(Shader)) Error!void {
    try self.ensureLoaded();
    self.symbols.?.destroyShader(self, shader);
}

pub fn createBuffer(self: *Self, descriptor: *const Buffer.BufferDescriptor, initial_data: ?[]const u8) Error!Handle(Buffer) {
    try self.ensureLoaded();
    return self.symbols.?.createBuffer(self, descriptor, if (initial_data) |d| @ptrCast(d.ptr) else null);
}

pub fn destroyBuffer(self: *Self, buffer: Handle(Buffer)) Error!void {
    try self.ensureLoaded();
    self.symbols.?.destroyBuffer(self, buffer);
}

pub fn createFence(self: *Self) Error!Handle(Fence) {
    try self.ensureLoaded();
    return self.symbols.?.createFence(self);
}

pub fn destroyFence(self: *Self, fence: Handle(Fence)) Error!void {
    try self.ensureLoaded();
    self.symbols.?.destroyFence(self, fence);
}

// info

pub fn getRendererInfo(self: *Self) Error!*const RendererInfo {
    try self.ensureLoaded();
    return &self.renderer_info;
}

pub fn getRenderingCapabilities(self: *Self) Error!*const RenderingCapabilities {
    try self.ensureLoaded();
    return &self.rendering_capabilities;
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

pub const RendererInfo = struct {
    name: ?[]const u8,
    vendor: []const u8,
    device: ?[]const u8,
    shading_language: ShadingLanguage,
    extensions: std.ArrayList([]const u8),
    pipeline_cache_id: std.ArrayList(u8),

    pub fn deinit(self: *RendererInfo) void {
        self.extensions.deinit();
        self.pipeline_cache_id.deinit();
    }

    pub fn format(
        self: RendererInfo,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            \\RendererInfo:
            \\  name: {?s}
            \\  vendor: {s}
            \\  device: {?s}
            \\  shading_language: {s}
            // \\  extensions: {s}
            // \\  pipeline_cache_id: {s}
        , .{
            self.name,
            self.vendor,
            self.device,
            @tagName(self.shading_language),
            // self.extensions,
            // self.pipeline_cache_id,
        });
    }
};

pub const RendererDevicePreference = packed struct(u4) {
    debug: bool = false,
    nvidia: bool = false,
    amd: bool = false,
    intel: bool = false,

    pub fn isNoPreference(self: RendererDevicePreference) bool {
        return !self.nvidia and !self.amd and !self.intel;
    }
};

pub const RendererDescriptor = struct {
    preference: RendererDevicePreference = .{},
    debugger: ?*const u8 = null,
    specific_config: ?[]const u8 = null,
};

pub const DeviceVendor = enum {
    unknown,
    apple,
    amd,
    intel,
    matrox,
    microsoft,
    nvidia,
    oracle,
    vmware,

    pub fn fromId(id: u16) DeviceVendor {
        return switch (id) {
            0x106B => .apple,
            0x1002 => .amd,
            0x8086 => .intel,
            0x102B => .matrox,
            0x1414 => .microsoft,
            0x10DE => .nvidia,
            0x108E => .oracle,
            0x15AD => .vmware,
            else => .unknown,
        };
    }

    pub fn getName(self: DeviceVendor) []const u8 {
        return switch (self) {
            .unknown => "unknown vendor",
            .apple => "Apple Inc.",
            .amd => "Advanced Micro Devices, Inc.",
            .intel => "Intel Corporation",
            .matrox => "Matrox Electronic Systems Ltd.",
            .microsoft => "Microsoft Corporation",
            .nvidia => "NVIDIA Corporation",
            .oracle => "Oracle Corporation",
            .vmware => "VMware Inc.",
        };
    }

    pub fn matchDevicePreference(self: DeviceVendor, pref: RendererDevicePreference) bool {
        return switch (self) {
            .nvidia => pref.nvidia,
            .amd => pref.amd,
            .intel => pref.intel,
            else => false,
        };
    }
};

pub const AdapterInfo = struct {
    allocator: std.mem.Allocator,
    name: ?[]const u8,
    vendor: DeviceVendor,
    memory: u64 = 0,
    outputs: std.ArrayList(std.ArrayList(app.display.DisplayMode)),

    pub fn deinit(self: *AdapterInfo) void {
        if (self.name) |n| self.allocator.free(n);
        for (self.outputs.items) |output| {
            output.deinit();
        }
        self.outputs.deinit();
    }
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
    render_conditions: bool = false,
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
    origin: ScreenOrigin = .lower_left,
    depth_range: DepthRange = .minus_one_to_one,
    shading_languages: std.ArrayList(ShadingLanguage),
    formats: std.ArrayList(format.Format),
    features: RenderingFeatures = .{},
    limits: RenderingLimits = .{},

    pub fn deinit(self: *RenderingCapabilities) void {
        self.shading_languages.deinit();
        self.formats.deinit();
    }
};
