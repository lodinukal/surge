const std = @import("std");

const commonutil = @import("../util.zig");

pub const impl = @import("impl.zig");
// pub const impl = @import("d3d11/main.zig");
pub const procs = @import("procs.zig");
pub const util = @import("util.zig");

pub const loadBackend = if (@hasDecl(impl, "loadBackend")) impl.loadBackend else struct {
    pub fn load(backend: BackendType) bool {
        _ = backend;
        return true;
    }
}.load;
pub const closeBackend = if (@hasDecl(impl, "closeBackend")) impl.closeBackend else struct {
    pub fn close() void {}
}.close;

pub const createInstance = impl.createInstance;

pub const array_layer_count_undefined = 0xffffffff;
pub const mip_level_count_undefined = 0xffffffff;
pub const copy_stride_undefined = 0xffffffff;
pub const limit_u32_undefined = 0xffffffff;
pub const limit_u64_undefined = 0xffffffffffffffff;
pub const query_set_index_undefined = 0xffffffff;
pub const whole_map_size = std.math.maxInt(u64);
pub const whole_size = 0xffffffffffffffff;

pub const Device = @import("device.zig").Device;
pub const Instance = @import("instance.zig").Instance;
pub const PhysicalDevice = @import("physical_device.zig").PhysicalDevice;
pub const Surface = @import("surface.zig").Surface;
pub const SwapChain = @import("swap_chain.zig").SwapChain;

pub const Error = blk: {
    var err = error{};
    inline for (.{
        Device,
        Instance,
        PhysicalDevice,
        Surface,
    }) |T| {
        if (@hasDecl(T, "Error")) {
            err = err || T.Error;
        }
    }

    break :blk err;
};

pub const ErrorEnum = commonutil.ErrorEnum(Error);

pub const max_render_targets: u32 = 8;
pub const max_viewports: u32 = 16;
pub const max_vertex_attributes: u32 = 16;
pub const max_binding_layouts: u32 = 5;
pub const max_bindings_per_layout: u32 = 128;
pub const max_volatile_constant_buffers_per_layout: u32 = 6;
pub const max_volatile_constant_buffers: u32 = 32;
// D3D12: root signature is 256 bytes max., Vulkan: 128 bytes of push constants guaranteed
pub const max_push_constant_size: u32 = 128;
// Partially bound constant buffers must have offsets aligned to this and sizes multiple of this
pub const constant_buffer_offset_size_alignment: u32 = 256;

pub const Colour = @Vector(4, f32);

pub const Viewport = struct {
    min_x: f32,
    max_x: f32,
    min_y: f32,
    max_y: f32,
    min_depth: f32,
    max_depth: f32,

    pub fn equal(a: Viewport, b: Viewport) bool {
        return std.simd.countTrues(@Vector(6, bool){
            a.min_x == b.min_x,
            a.max_x == b.max_x,
            a.min_y == b.min_y,
            a.max_y == b.max_y,
            a.min_depth == b.min_depth,
            a.max_depth == b.max_depth,
        }) == 6;
    }

    pub fn width(a: Viewport) f32 {
        return a.max_x - a.min_x;
    }

    pub fn height(a: Viewport) f32 {
        return a.max_y - a.min_y;
    }
};

pub const Rect = struct {
    min_x: i32,
    max_x: i32,
    min_y: i32,
    max_y: i32,

    pub fn equal(a: Rect, b: Rect) bool {
        return std.simd.countTrues(@Vector(4, bool){
            a.min_x == b.min_x,
            a.max_x == b.max_x,
            a.min_y == b.min_y,
            a.max_y == b.max_y,
        }) == 4;
    }

    pub fn width(a: Rect) i32 {
        return a.max_x - a.min_x;
    }

    pub fn height(a: Rect) i32 {
        return a.max_y - a.min_y;
    }
};

pub const BackendType = enum(u32) {
    undefined,
    null,
    webgpu,
    d3d11,
    d3d12,
    metal,
    vulkan,
    opengl,
    opengles,

    pub fn name(t: BackendType) []const u8 {
        return switch (t) {
            .undefined => "Undefined",
            .null => "Null",
            .webgpu => "WebGPU",
            .d3d11 => "D3D11",
            .d3d12 => "D3D12",
            .metal => "Metal",
            .vulkan => "Vulkan",
            .opengl => "OpenGL",
            .opengles => "OpenGLES",
        };
    }
};

pub const Format = enum(u8) {
    unknown,

    r8_uint,
    r8_sint,
    r8_unorm,
    r8_snorm,
    rg8_uint,
    rg8_sint,
    rg8_unorm,
    rg8_snorm,
    r16_uint,
    r16_sint,
    r16_unorm,
    r16_snorm,
    r16_float,
    bgra4_unorm,
    b5g6r5_unorm,
    b5g5r5a1_unorm,
    rgba8_uint,
    rgba8_sint,
    rgba8_unorm,
    rgba8_snorm,
    bgra8_unorm,
    srgba8_unorm,
    sbgra8_unorm,
    r10g10b10a2_unorm,
    r11g11b10_float,
    rg16_uint,
    rg16_sint,
    rg16_unorm,
    rg16_snorm,
    rg16_float,
    r32_uint,
    r32_sint,
    r32_float,
    rgba16_uint,
    rgba16_sint,
    rgba16_float,
    rgba16_unorm,
    rgba16_snorm,
    rg32_uint,
    rg32_sint,
    rg32_float,
    rgb32_uint,
    rgb32_sint,
    rgb32_float,
    rgba32_uint,
    rgba32_sint,
    rgba32_float,

    d16,
    d24s8,
    x24g8_uint,
    d32,
    d32s8,
    x32g8_uint,

    bc1_unorm,
    bc1_unorm_srgb,
    bc2_unorm,
    bc2_unorm_srgb,
    bc3_unorm,
    bc3_unorm_srgb,
    bc4_unorm,
    bc4_snorm,
    bc5_unorm,
    bc5_snorm,
    bc6h_ufloat,
    bc6h_sfloat,
    bc7_unorm,
    bc7_unorm_srgb,
};

pub const FormatKind = enum(u8) {
    integer,
    normalised,
    float,
    depth_stencil,
};

pub const FormatInfo = struct {
    format: Format,
    name: []const u8,
    bytes_per_block: u8,
    block_size: u8,
    kind: FormatKind,
    has_red: bool,
    has_green: bool,
    has_blue: bool,
    has_alpha: bool,
    has_depth: bool,
    has_stencil: bool,
    is_signed: bool,
    is_srgb: bool,
};

pub inline fn getFormatInfo(format: Format) *const FormatInfo {
    return @import("format_info.zig").format_infos[@intFromEnum(format)];
}

pub const FormatSupport = packed struct {
    buffer: bool,
    index_buffer: bool,
    vertex_buffer: bool,

    texture: bool,
    depth_stencil: bool,
    render_target: bool,
    blendable: bool,

    shader_load: bool,
    shader_sample: bool,
    shader_uav_load: bool,
    shader_uav_store: bool,
    shader_atomic: bool,

    _padding: u4,
};

// Heap

pub const Heap = opaque {
    pub const Type = enum(u8) {
        unknown,
        buffer,
        texture,
    };

    pub const Descriptor = struct {
        capacity: u64 = 0,
        type: Type,
        debug_label: ?[]const u8 = null,
    };

    pub inline fn getDescriptor(self: *Heap) *const Descriptor {
        return impl.heapGetDescriptor(self);
    }

    pub inline fn destroy(self: *Heap) void {
        return impl.heapDestroy(self);
    }
};

pub const MemoryRequirements = struct {
    size: u64,
    alignment: u64,
};

// Texture

pub const TextureDimension = enum(u8) {
    unknown,
    texture_1d,
    texture_1d_array,
    texture_2d,
    texture_2d_array,
    texture_cube,
    texture_cube_array,
    texture_2d_ms,
    texture_2d_ms_array,
    texture_3d,
};

pub const CpuAccessMode = enum(u8) {
    none,
    read,
    write,
};

pub const ResourceStates = packed struct {
    common: bool,
    constant_buffer: bool,
    vertex_buffer: bool,
    index_buffer: bool,
    indirect_argument: bool,
    shader_resource: bool,
    unordered_access: bool,
    render_target: bool,
    depth_write: bool,
    depth_read: bool,
    stream_out: bool,
    copy_dest: bool,
    copy_source: bool,
    resolve_dest: bool,
    resolve_source: bool,
    present: bool,
    accel_structure_read: bool,
    accel_structure_write: bool,
    accel_structure_build_input: bool,
    accel_structure_build_bias: bool,
    shading_rate_surface: bool,
    opacity_micromap_write: bool,
    opacity_micromap_build_input: bool,

    _padding: u9 = 0,
};

pub const MipLevel = u32;
pub const ArraySlice = u32;

pub const Texture = opaque {
    pub const Descriptor = struct {
        width: u32 = 1,
        height: u32 = 1,
        depth: u32 = 1,
        array_size: u32 = 1,
        mip_levels: u32 = 1,
        sample_count: u32 = 1,
        sample_quality: u32 = 0,
        format: Format = .unknown,
        dimension: TextureDimension = .texture_2d,
        debug_label: ?[]const u8 = null,

        is_shader_resource: bool = false,
        is_render_target: bool = false,
        is_uav: bool = false,
        is_typeless: bool = false,
        is_shading_rate_surface: bool = false,

        is_virtual: bool = false,

        clear_colour: ?Colour = null,

        initial_state: ResourceStates = .{},
        keep_initial_state: bool = false,
    };

    pub const Slice = struct {
        x: u32 = 0,
        y: u32 = 0,
        z: u32 = 0,
        width: ?u32 = null,
        height: ?u32 = null,
        depth: ?u32 = null,

        mip_level: MipLevel = 0,
        array_slice: ArraySlice = 0,

        pub fn resolve(self: Slice, desc: *const Descriptor) Slice {
            std.debug.assert(self.mip_level < desc.mip_levels);

            var ret_value = self;
            ret_value.width = ret_value.width orelse @max(desc.width >> ret_value.mip_level, 1);
            ret_value.height = ret_value.height orelse @max(desc.height >> ret_value.mip_level, 1);
            ret_value.depth = ret_value.depth orelse
                if (desc.dimension == .texture_3d) @max(desc.depth >> ret_value.mip_level, 1) else 1;
            return ret_value;
        }
    };

    pub const SubresourceSet = struct {
        base_mip_level: MipLevel = 0,
        num_mip_levels: MipLevel = 1,
        base_array_slice: ArraySlice = 0,
        num_array_slices: ArraySlice = 1,

        pub const all = SubresourceSet{
            .base_mip_level = 0,
            .num_mip_levels = mip_level_count_undefined,
            .base_array_slice = 0,
            .num_array_slices = array_layer_count_undefined,
        };

        pub fn resolve(self: SubresourceSet, desc: *const Descriptor, single_mip_level: bool) SubresourceSet {
            var ret_value = SubresourceSet{};
            ret_value.base_mip_level = self.base_mip_level;

            if (single_mip_level) {
                ret_value.num_mip_levels = 1;
            } else {
                const last_mip_level_plus_one = @min(self.base_mip_level + self.num_mip_levels, desc.mip_levels);
                ret_value.num_mip_levels = @max(0, last_mip_level_plus_one - self.base_mip_level);
            }

            switch (desc.dimension) {
                .texture_1d_array, .texture_2d_array, .texture_cube, .texture_cube_array, .texture_2d_ms_array => {
                    ret_value.base_array_slice = self.base_array_slice;
                    const last_array_slice_plus_one = @min(self.base_array_slice + self.num_array_slices, desc.array_size);
                    ret_value.num_array_slices = @max(0, last_array_slice_plus_one - self.base_array_slice);
                },
                else => {
                    ret_value.base_array_slice = 0;
                    ret_value.num_array_slices = 1;
                },
            }

            return ret_value;
        }

        pub fn isEntireTexture(self: SubresourceSet, desc: *const Descriptor) bool {
            if (self.base_mip_level > 0 or self.base_mip_level + self.num_mip_levels < desc.mip_levels)
                return false;

            switch (desc.dimension) {
                .texture_1d_array, .texture_2d_array, .texture_cube, .texture_cube_array, .texture_2d_ms_array => {
                    if (self.base_array_slice > 0 or self.base_array_slice + self.num_array_slices < desc.array_size)
                        return false;
                },
                else => {
                    return true;
                },
            }
        }

        pub inline fn equal(a: SubresourceSet, b: SubresourceSet) bool {
            return std.simd.countTrues(@Vector(4, bool){
                a.base_mip_level == b.base_mip_level,
                a.num_mip_levels == b.num_mip_levels,
                a.base_array_slice == b.base_array_slice,
                a.num_array_slices == b.num_array_slices,
            }) == 4;
        }
    };

    pub inline fn getDescriptor(self: *Texture) *const Descriptor {
        return impl.textureGetDescriptor(self);
    }

    pub inline fn destroy(self: *Texture) void {
        return impl.textureDestroy(self);
    }
};

pub const StagingTexture = opaque {
    pub inline fn getDescriptor(self: *StagingTexture) *const Texture.Descriptor {
        return impl.stagingTextureGetDescriptor(self);
    }

    pub inline fn destroy(self: *StagingTexture) void {
        return impl.stagingTextureDestroy(self);
    }
};

// Input Layout
pub const VertexAttributeDescriptor = struct {
    name: []const u8,
    format: Format = .unknown,
    array_size: u32 = 1,
    buffer_index: u32 = 0,
    offset: u32 = 0,
    element_stride: u32 = 0,
    instanced: bool = false,
};

pub const InputLayout = opaque {
    pub inline fn getAttributes(self: *const InputLayout) []const VertexAttributeDescriptor {
        return impl.inputLayoutGetAttributes(self);
    }

    pub inline fn destroy(self: *InputLayout) void {
        return impl.inputLayoutDestroy(self);
    }
};

// Buffer
pub const Buffer = opaque {
    pub const Descriptor = struct {
        byte_size: u64 = 0,
        struct_stride: u32 = 0,
        /// vulkan volatile buffers
        max_versions: u32 = 0,
        debug_label: ?[]const u8 = null,
        format: Format = .unknown,
        can_have_uavs: bool = false,
        can_have_typed_views: bool = false,
        can_have_raw_views: bool = false,
        is_vertex_buffer: bool = false,
        is_index_buffer: bool = false,
        is_constant_buffer: bool = false,
        is_draw_indirect_buffer: bool = false,
        is_accel_struct_build_input: bool = false,
        is_accel_struct_storage: bool = false,
        is_shader_binding_table: bool = false,

        is_volatile: bool = false,
        is_virtual: bool = false,

        initial_state: ResourceStates = .{},
        keep_initial_state: bool = false,

        cpu_access: CpuAccessMode = .none,
    };

    pub const Range = struct {
        byte_offset: u64 = 0,
        byte_size: u64 = 0,

        pub const entire = Range{
            .byte_offset = 0,
            .byte_size = whole_size,
        };

        pub fn resolve(self: Range, desc: *const Descriptor) Range {
            var ret_value = Range{};
            ret_value.byte_offset = @min(self.byte_offset, desc.byte_size);
            ret_value.byte_size = if (self.byte_size == 0)
                desc.byte_size - ret_value.byte_offset
            else
                @min(self.byte_size, desc.byte_size - ret_value.byte_offset);
            return ret_value;
        }
    };

    pub inline fn getDescriptor(self: *Buffer) *const Descriptor {
        return impl.bufferGetDescriptor(self);
    }

    pub inline fn destroy(self: *Buffer) void {
        return impl.bufferDestroy(self);
    }
};

// Shader
pub const Shader = opaque {
    pub const Type = packed struct(u16) {
        compute: bool = false,

        vertex: bool = false,
        hull: bool = false,
        domain: bool = false,
        geometry: bool = false,
        pixel: bool = false,
        amplification: bool = false,
        mesh: bool = false,

        ray_generation: bool = false,
        any_hit: bool = false,
        closest_hit: bool = false,
        miss: bool = false,
        intersection: bool = false,
        callable: bool = false,

        pub const all_graphics = @This(){
            .vertex = true,
            .hull = true,
            .domain = true,
            .geometry = true,
            .pixel = true,
            .amplification = true,
            .mesh = true,
        };

        pub const all_ray_tracing = @This(){
            .ray_generation = true,
            .any_hit = true,
            .closest_hit = true,
            .miss = true,
            .intersection = true,
            .callable = true,
        };
    };

    pub const FastGeometryShaderInfo = packed struct {
        force_fast_geometry_shader: bool = false,
        use_viewport_mask: bool = false,
        offset_target_index_by_viewport_index: bool = false,
        strict_api_order: bool = false,
    };

    pub const Descriptor = struct {
        type: Type,
        debug_label: ?[]const u8 = null,
        entry_point: []const u8 = "main",

        fast_geometry_shader_info: FastGeometryShaderInfo = .{},
    };

    pub const Specialisation = struct {
        constant_id: u32 = 0,
        value: extern union {
            u: u32,
            i: i32,
            f: f32,
        },

        pub inline fn fromU32(id: u32, value: u32) Specialisation {
            return Specialisation{
                .constant_id = id,
                .value = .{ .u = value },
            };
        }

        pub inline fn fromI32(id: u32, value: i32) Specialisation {
            return Specialisation{
                .constant_id = id,
                .value = .{ .i = value },
            };
        }

        pub inline fn fromF32(id: u32, value: f32) Specialisation {
            return Specialisation{
                .constant_id = id,
                .value = .{ .f = value },
            };
        }
    };

    pub inline fn getDescriptor(self: *const Shader) *const Descriptor {
        return impl.shaderGetDescriptor(self);
    }

    pub inline fn getBytecode(self: *const Shader) *[]const u8 {
        return impl.shaderGetBytecode(self);
    }

    pub inline fn destroy(self: *Shader) void {
        return impl.shaderDestroy(self);
    }
};

// ShaderLibrary
pub const ShaderLibrary = struct {
    pub inline fn getBytecode(self: *const ShaderLibrary) *[]const u8 {
        return impl.shaderLibraryGetBytecode(self);
    }

    pub inline fn getShader(self: *ShaderLibrary, entry_point: []const u8, ty: Shader.Type) ?*Shader {
        return impl.shaderLibraryGetShader(self, entry_point, ty);
    }

    pub inline fn destroy(self: *ShaderLibrary) void {
        return impl.shaderLibraryDestroy(self);
    }
};

// BlendState

pub const ColourMask = packed struct {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,

    pub fn equal(a: ColourMask, b: ColourMask) bool {
        return std.simd.countTrues(@Vector(4, bool){
            a.red == b.red,
            a.green == b.green,
            a.blue == b.blue,
            a.alpha == b.alpha,
        }) == 4;
    }
};

pub const BlendState = struct {
    pub const Factor = enum {
        zero,
        one,
        src_colour,
        inv_src_colour,
        src_alpha,
        inv_src_alpha,
        dst_alpha,
        inv_dst_alpha,
        dst_colour,
        inv_dst_colour,
        src_alpha_sat,
        constant_colour,
        inv_constant_colour,
        src_1_colour,
        inv_src_1_colour,
        src_1_alpha,
        inv_src_1_alpha,
    };

    pub const Op = enum {
        add,
        subtract,
        reverse_subtract,
        min,
        max,
    };

    pub const RenderTarget = struct {
        blend_enabled: bool = false,
        src_blend: Factor = .one,
        dst_blend: Factor = .zero,
        blend_op: Op = .add,
        src_blend_alpha: Factor = .one,
        dst_blend_alpha: Factor = .zero,
        blend_op_alpha: Op = .add,
        write_mask: ColourMask = .{},

        pub fn usesConstantColour(self: RenderTarget) bool {
            return std.simd.countTrues(@Vector(8, bool){
                self.src_blend == .constant_colour,
                self.src_blend == .inv_constant_colour,
                self.dst_blend == .constant_colour,
                self.dst_blend == .inv_constant_colour,
                self.src_blend_alpha == .constant_colour,
                self.src_blend_alpha == .inv_constant_colour,
                self.dst_blend_alpha == .constant_colour,
                self.dst_blend_alpha == .inv_constant_colour,
            }) > 0;
        }

        pub inline fn equal(a: RenderTarget, b: RenderTarget) bool {
            return std.simd.countTrues(@Vector(8, bool){
                a.blend_enabled == b.blend_enabled,
                a.src_blend == b.src_blend,
                a.dst_blend == b.dst_blend,
                a.blend_op == b.blend_op,
                a.src_blend_alpha == b.src_blend_alpha,
                a.dst_blend_alpha == b.dst_blend_alpha,
                a.blend_op_alpha == b.blend_op_alpha,
                ColourMask.equal(a.write_mask, b.write_mask),
            }) == 11;
        }
    };

    targets: [max_render_targets]RenderTarget,
    alpha_coverage_enabled: bool = false,

    pub fn usesConstantColour(self: BlendState) bool {
        for (self.targets) |target| {
            if (target.usesConstantColour()) return true;
        }
        return false;
    }

    pub inline fn equal(a: BlendState, b: BlendState) bool {
        inline for (0..max_render_targets) |index| {
            if (!RenderTarget.equal(a.targets[index], b.targets[index])) return false;
        }
        return a.alpha_coverage_enabled == b.alpha_coverage_enabled;
    }
};

// Raster State
pub const RasterState = struct {
    pub const FillMode = enum {
        solid,
        wireframe,
    };

    pub const CullMode = enum {
        back,
        front,
        none,
    };

    fill_mode: FillMode = .solid,
    cull_mode: CullMode = .back,
    front_counter_clockwise: bool = false,
    depth_clip_enabled: bool = true,
    scissor_enabled: bool = false,
    multisample_enabled: bool = false,
    antialiased_line_enabled: bool = false,
    depth_bias: i32 = 0,
    depth_bias_clamp: f32 = 0.0,
    slope_scaped_depth_bias: f32 = 0.0,
};

// DepthStencilState
pub const DepthStencilState = struct {
    pub const Op = enum {
        keep,
        zero,
        rpelace,
        increment_and_clamp,
        decrement_and_clamp,
        invert,
        increment_and_wrap,
        decrement_and_wrap,
    };

    pub const Comparison = enum {
        never,
        less,
        equal,
        less_or_equal,
        greater,
        not_equal,
        greater_or_equal,
        always,
    };

    pub const Descriptor = struct {
        fail_op: Op = .keep,
        depth_fail_op: Op = .keep,
        pass_op: Op = .keep,
        comparison: Comparison = .always,
    };

    depth_test_enabled: bool = false,
    depth_write_enabled: bool = false,
    depth_func: Comparison = .less,
    stencil_enable: bool = false,
    stencil_read_mask: ColourMask = .{},
    stencil_write_mask: ColourMask = .{},
    stencil_ref_value: u8 = 0,
    front_face: Descriptor = .{},
    back_face: Descriptor = .{},
};

// ViewportState
pub const ViewportState = struct {
    viewports: std.BoundedArray(Viewport, max_viewports) =
        std.BoundedArray(Viewport, max_viewports).init(max_viewports),
    scissors: std.BoundedArray(Rect, max_viewports) =
        std.BoundedArray(Rect, max_viewports).init(max_viewports),

    pub fn addViewport(self: *ViewportState, v: Viewport) *ViewportState {
        self.viewports.appendAssumeCapacity(v);
        return self;
    }

    pub fn addScissorRect(self: *ViewportState, r: Rect) *ViewportState {
        self.scissors.appendAssumeCapacity(r);
        return self;
    }

    pub fn addViewportAndScissorRect(self: *ViewportState, v: Viewport, r: Rect) *ViewportState {
        return self.addViewport(v).addScissorRect(r);
    }
};

// Sampler
pub const Sampler = opaque {
    pub const AddressMode = enum {
        clamp,
        wrap,
        border,
        mirror,
        mirror_once,
    };

    pub const ReductionType = enum {
        standard,
        comparison,
        minimum,
        maximum,
    };

    pub const Descriptor = struct {
        borer_colour: Colour = .{ 1.0, 1.0, 1.0, 1.0 },
        max_anistropy: f32 = 1.0,
        mip_bias: f32 = 0.0,

        min_filter: bool = true,
        mag_filter: bool = true,
        mip_filter: bool = true,
        address_u: AddressMode = .clamp,
        address_v: AddressMode = .clamp,
        address_w: AddressMode = .clamp,
        reduction_type: ReductionType = .standard,
    };

    pub inline fn getDescriptor(self: *const Sampler) *const Descriptor {
        return impl.samplerGetDescriptor(self);
    }

    pub inline fn destroy(self: *Sampler) void {
        return impl.samplerDestroy(self);
    }
};

// Framebuffer
pub const Framebuffer = opaque {
    pub const Attachment = struct {
        texture: ?*Texture = null,
        subresources: Texture.SubresourceSet = .{
            .num_mip_levels = 1,
            .num_array_slices = 1,
        },
        format: Format = .unknown,
        read_only: bool = false,

        pub inline fn valid(self: Attachment) bool {
            return self.texture != null;
        }
    };

    pub const Descriptor = struct {
        colour_attachments: std.BoundedArray(Attachment, max_render_targets) =
            std.BoundedArray(Attachment, max_render_targets).init(max_render_targets),
        depth_attachment: Attachment = .{},
        shading_rate_attachment: Attachment = .{},

        pub fn addColourAttachment(self: *Descriptor, attachment: Attachment) *Descriptor {
            self.colour_attachments.appendAssumeCapacity(attachment);
            return self;
        }

        pub fn setDepthAttachment(self: *Descriptor, attachment: Attachment) *Descriptor {
            self.depth_attachment = attachment;
            return self;
        }

        pub fn setShadingRateAttachment(self: *Descriptor, attachment: Attachment) *Descriptor {
            self.shading_rate_attachment = attachment;
            return self;
        }
    };

    pub const Info = struct {
        colour_formats: std.BoundedArray(Format, max_render_targets) =
            std.BoundedArray(Format, max_render_targets).init(max_render_targets),
        depth_format: Format = .unknown,
        sample_count: u32 = 1,
        sample_quality: u32 = 0,

        pub fn init(desc: *const Descriptor) Info {
            var info = Info{};

            for (desc.colour_attachments.buffer) |attachment| {
                info.colour_formats.appendAssumeCapacity(if (attachment.format == .unknown and attachment.texture != null)
                    attachment.texture.?.getDescriptor().format
                else
                    attachment.format);
            }

            if (desc.depth_attachment.valid()) {
                const texture_desc = desc.depth_attachment.texture.?.getDescriptor();
                info.depth_format = texture_desc.format;
                info.sample_count = texture_desc.sample_count;
                info.sample_quality = texture_desc.sample_quality;
            } else if (desc.colour_attachments.len != 0 and desc.colour_attachments.buffer[0].valid()) {
                const texture_desc = desc.colour_attachments.buffer[0].texture.?.getDescriptor();
                info.sample_count = texture_desc.sample_count;
                info.sample_quality = texture_desc.sample_quality;
            }
        }

        pub inline fn equal(a: Info, b: Info) bool {
            inline for (0..max_render_targets) |index| {
                if (a.colour_formats[index] != b.colour_formats[index]) return false;
            }
            return std.simd.countTrues(@Vector(3, bool){
                a.depth_format == b.depth_format,
                a.sample_count == b.sample_count,
                a.sample_quality == b.sample_quality,
            }) == 3;
        }
    };

    pub inline fn getDescriptor(self: *const Framebuffer) *const Descriptor {
        return impl.framebufferGetDescriptor(self);
    }

    pub inline fn getFramebufferInfo(self: *const Framebuffer) *const Info {
        return impl.framebufferGetFramebufferInfo(self);
    }

    pub inline fn destroy(self: *Framebuffer) void {
        return impl.framebufferDestroy(self);
    }
};

// skip raytracing for now

// BindingLayouts
pub const ResourceType = enum(u8) {
    none,
    texture_srv,
    texture_uav,
    typed_buffer_srv,
    typed_buffer_uav,
    structured_bhffer_srv,
    structured_buffer_uav,
    raw_buffer_srv,
    raw_buffer_uav,
    constant_buffer,
    volatile_constant_buffer,
    sampler,
    ray_tracing_acceleration_structure,
    push_constants,
};

pub const BindingLayout = opaque {
    pub const BindingLayoutItem = struct {
        slot: u32,
        type: ResourceType,
        unused: u8 = 0,
        size: u16 = 0,

        comptime {
            if (@sizeOf(BindingLayoutItem) != 8) {
                @compileError("BindingLayoutItem must be 8 bytes");
            }
        }

        pub fn equal(a: BindingLayoutItem, b: BindingLayoutItem) bool {
            return std.simd.countTrues(@Vector(3, bool){
                a.slot == b.slot,
                a.type == b.type,
                a.size == b.size,
            }) == 3;
        }

        pub fn fromTextureSRV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .texture_srv,
            };
        }

        pub fn fromTextureUAV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .texture_uav,
            };
        }

        pub fn fromTypedBufferSRV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .typed_buffer_srv,
            };
        }

        pub fn fromTypedBufferUAV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .typed_buffer_uav,
            };
        }

        pub fn fromStructuredBufferSRV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .structured_bhffer_srv,
            };
        }

        pub fn fromStructuredBufferUAV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .structured_buffer_uav,
            };
        }

        pub fn fromRawBufferSRV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .raw_buffer_srv,
            };
        }

        pub fn fromRawBufferUAV(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .raw_buffer_uav,
            };
        }

        pub fn fromConstantBuffer(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .constant_buffer,
            };
        }

        pub fn fromVolatileConstantBuffer(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .volatile_constant_buffer,
            };
        }

        pub fn fromSampler(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .sampler,
            };
        }

        pub fn fromRayTracingAccelerationStructure(slot: u32) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .ray_tracing_acceleration_structure,
            };
        }

        pub fn fromPushConstants(slot: u32, size: usize) BindingLayoutItem {
            return .{
                .slot = slot,
                .type = .push_constants,
                .size = @abs(size),
            };
        }
    };

    pub const BindingLayoutItemArray = std.BoundedArray(BindingLayoutItem, max_bindings_per_layout);

    pub const VulkanBindingOffsets = struct {
        shader_resource: u32 = 0,
        sampler: u32 = 128,
        constant_buffer: u32 = 256,
        unordered_access: u32 = 384,
    };

    pub const Descriptor = struct {
        visibility: Shader.Type = .{},
        register_space: u32 = 0,
        bindings: BindingLayoutItemArray,
        binding_offsets: VulkanBindingOffsets,
    };

    pub const BindlessDescriptor = struct {
        visibility: Shader.Type = .{},
        first_slot: u32 = 0,
        max_capacity: u32 = 0,
        register_spaces: std.BoundedArray(BindingLayoutItem, 16) = std.BoundedArray(BindingLayoutItem, 16).init(16),

        pub fn addRegisterSpace(self: *BindlessDescriptor, value: *const BindingLayoutItem) *BindlessDescriptor {
            self.register_spaces.appendAssumeCapacity(value.*);
            return self;
        }
    };

    pub inline fn getDescriptor(self: *const BindingLayout) ?*const Descriptor {
        return impl.bindingLayoutGetDescriptor(self);
    }

    pub inline fn getBindlessDescriptor(self: *const BindingLayout) ?*const BindlessDescriptor {
        return impl.bindingLayoutGetBindlessDescriptor(self);
    }

    pub inline fn destroy(self: *BindingLayout) void {
        return impl.bindingLayoutDestroy(self);
    }
};

pub const BindingLayoutArray = std.BoundedArray(*BindingLayout, max_binding_layouts);

// BindingSet

pub const BindingSet = opaque {
    pub const Resource = union {
        texture: *Texture,
        buffer: *Buffer,
        sampler: *Sampler,
        op: *anyopaque,
    };

    pub const BindingSetItem = struct {
        resource: ?Resource = null,
        slot: u32 = 0,
        type: ResourceType = .none,
        dimension: TextureDimension = .unknown,
        format: Format = .unknown,
        unused: u8 = 0,
        un: union {
            subresources: Texture.SubresourceSet,
            range: Buffer.Range,
            raw_data: [2]u64,
        } = .{ .raw_data = .{ 0, 0 } },

        pub inline fn equal(a: BindingSetItem, b: BindingSetItem) bool {
            return std.simd.countTrues(@Vector(8, bool){
                a.resource == b.resource,
                a.slot == b.slot,
                a.type == b.type,
                a.dimension == b.dimension,
                a.format == b.format,
                a.un.raw_data[0] == b.un.raw_data[0],
                a.un.raw_data[1] == b.un.raw_data[1],
            }) == 9;
        }

        pub inline fn none(slot: u32) BindingSetItem {
            return .{
                .slot = slot,
            };
        }

        pub inline fn fromTextureSRV(
            slot: u32,
            texture: ?*Texture,
            format: ?Format,
            subresources: ?Texture.SubresourceSet,
            dimension: ?TextureDimension,
        ) BindingSetItem {
            const use_format = format orelse .unknown;
            const use_subresource = subresources orelse Texture.SubresourceSet.all;
            const use_dimension = dimension orelse .unknown;

            return .{
                .slot = slot,
                .type = .texture_srv,
                .resource = if (texture) |t| .{ .texture = t } else null,
                .format = use_format,
                .dimension = use_dimension,
                .un = .{
                    .subresources = use_subresource,
                },
            };
        }

        pub inline fn fromTextureUAV(
            slot: u32,
            texture: ?*Texture,
            format: ?Format,
            subresources: ?Texture.SubresourceSet,
            dimension: ?TextureDimension,
        ) BindingSetItem {
            const use_format = format orelse .unknown;
            const use_subresource = subresources orelse Texture.SubresourceSet{
                .num_array_slices = array_layer_count_undefined,
            };
            const use_dimension = dimension orelse .unknown;

            return .{
                .slot = slot,
                .type = .texture_uav,
                .resource = if (texture) |t| .{ .texture = t } else null,
                .format = use_format,
                .dimension = use_dimension,
                .un = .{
                    .subresources = use_subresource,
                },
            };
        }

        pub inline fn fromTypedBufferSRV(
            slot: u32,
            buffer: ?*Buffer,
            format: ?Format,
            range: ?Buffer.Range,
        ) BindingSetItem {
            const use_format = format orelse .unknown;
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = .typed_buffer_srv,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .format = use_format,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromTypedBufferUAV(
            slot: u32,
            buffer: ?*Buffer,
            format: ?Format,
            range: ?Buffer.Range,
        ) BindingSetItem {
            const use_format = format orelse .unknown;
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = .typed_buffer_uav,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .format = use_format,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromConstantBuffer(slot: u32, buffer: ?*Buffer, range: ?Buffer.Range) BindingSetItem {
            const is_volatile = if (buffer) |b| b.getDescriptor().is_volatile else false;
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = if (is_volatile) .volatile_constant_buffer else .constant_buffer,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromSampler(slot: u32, sampler: ?*Sampler) BindingSetItem {
            return .{
                .slot = slot,
                .type = .sampler,
                .resource = if (sampler) |s| .{ .sampler = s } else null,
            };
        }

        pub inline fn fromStructuredBufferSRV(
            slot: u32,
            buffer: ?*Buffer,
            format: ?Format,
            range: ?Buffer.Range,
        ) BindingSetItem {
            const use_format = format orelse .unknown;
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = .structured_bhffer_srv,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .format = use_format,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromStructuredBufferUAV(
            slot: u32,
            buffer: ?*Buffer,
            format: ?Format,
            range: ?Buffer.Range,
        ) BindingSetItem {
            const use_format = format orelse .unknown;
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = .structured_buffer_uav,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .format = use_format,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromRawBufferSRV(
            slot: u32,
            buffer: ?*Buffer,
            range: ?Buffer.Range,
        ) BindingSetItem {
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = .raw_buffer_srv,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromRawBufferUAV(
            slot: u32,
            buffer: ?*Buffer,
            range: ?Buffer.Range,
        ) BindingSetItem {
            const use_range = range orelse Buffer.Range.entire;

            return .{
                .slot = slot,
                .type = .raw_buffer_uav,
                .resource = if (buffer) |b| .{ .buffer = b } else null,
                .un = .{
                    .range = use_range,
                },
            };
        }

        pub inline fn fromPushConstants(slot: u32, byte_size: u32) BindingSetItem {
            return .{
                .slot = slot,
                .type = .push_constants,
                .un = .{
                    .range = .{
                        .byte_size = byte_size,
                    },
                },
            };
        }
    };

    pub const BindingSetItemArray = std.BoundedArray(BindingSetItem, max_bindings_per_layout);

    pub const Descriptor = struct {
        bindings: BindingSetItemArray = BindingSetItemArray.init(max_bindings_per_layout),
        clear_items: bool = false,

        pub inline fn equal(a: Descriptor, b: Descriptor) bool {
            if (a.bindings.len != b.bindings.len) return false;
            inline for (0..a.bindings.len) |index| {
                if (!BindingSetItem.equal(a.bindings.buffer[index], b.bindings.buffer[index])) return false;
            }
            return true;
        }
    };

    pub inline fn getDescriptor(self: *const BindingSet) *const Descriptor {
        return impl.bindingSetGetDescriptor(self);
    }

    pub inline fn getLayout(self: *const BindingSet) *BindingLayout {
        return impl.bindingSetGetLayout(self);
    }

    pub inline fn destroy(self: *BindingSet) void {
        return impl.bindingSetDestroy(self);
    }
};

pub const BindingSetArray = std.BoundedArray(*BindingSet, max_binding_layouts);

/// basically BindingSet
pub const DescriptorTable = opaque {
    pub inline fn getDescriptor(self: *const DescriptorTable) *const BindingSet.Descriptor {
        return impl.descriptorTableGetDescriptor(self);
    }

    pub inline fn getLayout(self: *const DescriptorTable) *BindingLayout {
        return impl.descriptorTableGetLayout(self);
    }

    pub inline fn getCapacity(self: *const DescriptorTable) u32 {
        return impl.descriptorTableGetCapacity(self);
    }

    pub inline fn destroy(self: *DescriptorTable) void {
        return impl.descriptorTableDestroy(self);
    }
};

pub const PrimitiveType = enum(u8) {
    point_list,
    line_list,
    triangle_list,
    triangle_strip,
    triangle_fan,
    triangle_list_with_adjacency,
    triangle_strip_with_adjacency,
    patch_list,
};

pub const SinglePassStereoState = struct {
    enabled: bool = false,
    independent_viewport_mask: bool = false,
    render_target_index_offset: u32 = 0,

    pub fn equal(a: SinglePassStereoState, b: SinglePassStereoState) bool {
        return std.simd.countTrues(@Vector(3, bool){
            a.enabled == b.enabled,
            a.independent_viewport_mask == b.independent_viewport_mask,
            a.render_target_index_offset == b.render_target_index_offset,
        }) == 3;
    }
};

pub const RenderState = struct {
    blend_state: BlendState = .{},
    depth_stencil_state: DepthStencilState = .{},
    raster_state: RasterState = .{},
    single_pass_stereo_state: SinglePassStereoState = .{},
};

pub const VariableShadingRate = enum(u8) {
    e1x1,
    e1x2,
    e2x1,
    e2x2,
    e2x4,
    e4x2,
    e4x4,
};

pub const ShadingRateCombiner = enum(u8) {
    passthrough,
    override,
    min,
    max,
    apply_relative,
};

pub const VariableRateShadingState = struct {
    enabled: bool = false,
    shading_rate: VariableShadingRate = .e1x1,
    pipeline_primitive_combinder: ShadingRateCombiner = .passthrough,
    image_combiner: ShadingRateCombiner = .passthrough,

    pub inline fn equal(a: VariableRateShadingState, b: VariableRateShadingState) bool {
        return std.simd.countTrues(@Vector(4, bool){
            a.enabled == b.enabled,
            a.shading_rate == b.shading_rate,
            a.pipeline_primitive_combinder == b.pipeline_primitive_combinder,
            a.image_combiner == b.image_combiner,
        }) == 4;
    }
};

pub const GraphicsPipeline = opaque {
    pub const Descriptor = struct {
        primitive_type: PrimitiveType = .triangle_list,
        patch_control_points: u32 = 0,
        input_layout: ?*InputLayout = null,

        vs: ?*Shader = null,
        hs: ?*Shader = null,
        ds: ?*Shader = null,
        gs: ?*Shader = null,
        ps: ?*Shader = null,

        render_state: RenderState = .{},
        variable_rate_shading_state: VariableRateShadingState = .{},

        binding_layouts: BindingLayoutArray = BindingLayoutArray.init(max_binding_layouts),
    };

    pub inline fn getDescriptor(self: *const GraphicsPipeline) *const Descriptor {
        return impl.graphicsPipelineGetDescriptor(self);
    }

    pub inline fn getFramebufferInfo(self: *const GraphicsPipeline) *const Framebuffer.Info {
        return impl.graphicsPipelineGetFramebufferInfo(self);
    }

    pub inline fn destroy(self: *GraphicsPipeline) void {
        return impl.graphicsPipelineDestroy(self);
    }
};

pub const ComputePipeline = opaque {
    pub const Descriptor = struct {
        cs: ?*Shader = null,
        binding_layouts: BindingLayoutArray = BindingLayoutArray.init(max_binding_layouts),
    };

    pub inline fn getDescriptor(self: *const ComputePipeline) *const Descriptor {
        return impl.computePipelineGetDescriptor(self);
    }

    pub inline fn destroy(self: *ComputePipeline) void {
        return impl.computePipelineDestroy(self);
    }
};

pub const MeshletPipeline = opaque {
    pub const Descriptor = struct {
        primitive_type: PrimitiveType = .triangle_list,

        as: ?*Shader = null,
        ms: ?*Shader = null,
        ps: ?*Shader = null,

        render_state: RenderState = .{},
        binding_layouts: BindingLayoutArray = BindingLayoutArray.init(max_binding_layouts),
    };

    pub inline fn getDescriptor(self: *const MeshletPipeline) *const Descriptor {
        return impl.meshletPipelineGetDescriptor(self);
    }

    pub inline fn getFramebufferInfo(self: *const MeshletPipeline) *const Framebuffer.Info {
        return impl.meshletPipelineGetFramebufferInfo(self);
    }

    pub inline fn destroy(self: *MeshletPipeline) void {
        return impl.meshletPipelineDestroy(self);
    }
};

// Draw and dispatch
pub const EventQuery = opaque {
    pub inline fn destroy(self: *EventQuery) void {
        return impl.eventQueryDestroy(self);
    }
};

pub const TimerQuery = opaque {
    pub inline fn destroy(self: *TimerQuery) void {
        return impl.timerQueryDestroy(self);
    }
};

pub const VertexBufferBinding = struct {
    buffer: ?*Buffer = null,
    slot: u32 = 0,
    offset: u64 = 0,

    pub inline fn equal(a: VertexBufferBinding, b: VertexBufferBinding) bool {
        return std.simd.countTrues(@Vector(3, bool){
            a.buffer == b.buffer,
            a.slot == b.slot,
            a.offset == b.offset,
        }) == 3;
    }
};

pub const IndexBufferBindings = struct {
    buffer: ?*Buffer = null,
    format: Format = .unknown,
    offset: u64 = 0,

    pub inline fn equal(a: IndexBufferBindings, b: IndexBufferBindings) bool {
        return std.simd.countTrues(@Vector(3, bool){
            a.buffer == b.buffer,
            a.format == b.format,
            a.offset == b.offset,
        }) == 3;
    }
};

pub const GraphicsState = struct {
    pipeline: ?*GraphicsPipeline = null,
    framebuffer: ?*Framebuffer = null,
    viewport: ViewportState = .{},
    blend_constant_colour: Colour = .{ 0.0, 0.0, 0.0, 0.0 },
    shading_rate_state: VariableRateShadingState = .{},

    bindings: BindingSetArray = BindingSetArray.init(max_binding_layouts),

    vertex_buffers: std.BoundedArray(VertexBufferBinding, max_vertex_attributes) =
        std.BoundedArray(VertexBufferBinding, max_vertex_attributes).init(max_vertex_attributes),
    index_buffer: IndexBufferBindings = .{},

    indirect_params: ?*Buffer = null,
};

pub const DrawArguments = struct {
    vertex_count: u32 = 0,
    instance_count: u32 = 1,
    start_index_location: u32 = 0,
    start_vertex_location: u32 = 0,
    start_instance_location: u32 = 0,
};

pub const DrawIndirectArguments = struct {
    vertex_count: u32 = 0,
    instance_count: u32 = 1,
    start_vertex_location: u32 = 0,
    start_instance_location: u32 = 0,
};

pub const DrawIndexedIndirectArguments = struct {
    index_count: u32 = 0,
    instance_count: u32 = 1,
    start_index_location: u32 = 0,
    base_vertex_location: i32 = 0,
    start_instance_location: u32 = 0,
};

pub const ComputeState = struct {
    pipeline: ?*ComputePipeline = null,
    bindings: BindingSetArray = BindingSetArray.init(max_binding_layouts),
    indirect_params: ?*Buffer = null,
};

pub const MeshletState = struct {
    pipeline: ?*MeshletPipeline = null,
    framebuffer: ?*Framebuffer = null,
    viewport: ViewportState = .{},
    blend_constant_colour: Colour = .{ 0.0, 0.0, 0.0, 0.0 },

    bindings: BindingSetArray = BindingSetArray.init(max_binding_layouts),

    indirect_params: ?*Buffer = null,
};

pub const Feature = enum(u8) {
    deferred_command_lists,
    single_pass_stereo,
    ray_tracing_accel_struct,
    ray_tracing_pipeline,
    ray_tracing_opacity_micromap,
    ray_query,
    shader_execution_reordering,
    fast_geometry_shader,
    meshlets,
    conservative_rasterization,
    variable_rate_shading,
    shader_specializations,
    virtual_resources,
    compute_queue,
    copy_queue,
    constant_buffer_ranges,
};

pub const MessageSeverity = enum(u8) {
    info,
    warning,
    err,
    fatal,
};

pub const CommandQueue = enum(u8) {
    graphics,
    computer,
    copy,
};

pub const CommandList = opaque {
    pub const Parameters = struct {
        enable_immediate_execution: bool = true,
        upload_chunk_size: usize = 64 * 1024,
        scratch_chunk_size: usize = 64 * 1024,
        scratch_max_memory: usize = 1024 * 1024 * 1024,
        queue: CommandQueue = .graphics,
    };
};
