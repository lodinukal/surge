const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");
const Handle = Renderer.Handle;

const Self = @This();

pub const PrimitiveTopology = enum {
    point_list,
    line_list,
    line_strip,
    line_list_adjacency,
    line_strip_adjacency,
    triangle_list,
    triangle_strip,
    triangle_list_adjacency,
    triangle_strip_adjacency,
    patches_1,
    patches_2,
    patches_3,
    patches_4,
    patches_5,
    patches_6,
    patches_7,
    patches_8,
    patches_9,
    patches_10,
    patches_11,
    patches_12,
    patches_13,
    patches_14,
    patches_15,
    patches_16,
    patches_17,
    patches_18,
    patches_19,
    patches_20,
    patches_21,
    patches_22,
    patches_23,
    patches_24,
    patches_25,
    patches_26,
    patches_27,
    patches_28,
    patches_29,
    patches_30,
    patches_31,
    patches_32,
};

pub const CompareOperation = enum {
    never,
    less,
    equal,
    less_or_equal,
    greater,
    not_equal,
    greater_or_equal,
    always,
};

pub const StencilOperation = enum {
    keep,
    zero,
    replace,
    increment_and_clamp,
    decrement_and_clamp,
    wrap,
    increment_and_wrap,
    decrement_and_wrap,
};

pub const BlendOperation = enum {
    zero,
    one,
    src_colour,
    inv_src_colour,
    src_alpha,
    inv_src_alpha,
    dst_colour,
    inv_dst_colour,
    dst_alpha,
    inv_dst_alpha,
    src_alpha_saturate,
    blend_factor,
    inv_blend_factor,
    src1_colour,
    inv_src1_colour,
    src1_alpha,
    inv_src1_alpha,
};

pub const BlendArithmetic = enum {
    add,
    subtract,
    reverse_subtract,
    min,
    max,
};

pub const PolygonMode = enum {
    fill,
    line,
    point,
};

pub const CullMode = enum {
    none,
    front,
    back,
};

pub const LogicalOperation = enum {
    none,
    clear,
    set,
    copy,
    copy_inverted,
    no_op,
    invert,
    @"and",
    and_reverse,
    and_inverted,
    nand,
    @"or",
    or_reverse,
    or_inverted,
    nor,
    xor,
    equivalent,
};

pub const TesselationPartition = enum {
    undefined,
    integer,
    pow2,
    fractional_odd,
    fractional_even,
};

pub const ColourMask = struct {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,
};

pub const Viewport = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,
    min_depth: f32 = 0.0,
    max_depth: f32 = 1.0,
};

pub const Scissor = struct {
    x: u32 = 0,
    y: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub const DepthDescriptor = struct {
    test_enable: bool = false,
    write_enable: bool = false,
    compare_operation: CompareOperation = .less,
};

pub const StencilFaceDescriptor = struct {
    fail_operation: StencilOperation = .keep,
    depth_fail_operation: StencilOperation = .keep,
    depth_pass_operation: StencilOperation = .keep,
    compare_operation: CompareOperation = .less,
    read_mask: u32 = ~0,
    write_mask: u32 = ~0,
    stencil_reference: u32 = 0,
};

pub const StencilDescriptor = struct {
    enabled: bool = false,
    reference_dynamic: bool = false,
    front: StencilFaceDescriptor,
    back: StencilFaceDescriptor,
};

pub const DepthBiasDescriptor = struct {
    constant_factor: f32 = 0.0,
    slope_factor: f32 = 0.0,
    clamp: f32 = 0.0,
};

pub const RasteriserDescriptor = struct {
    polygon_mode: PolygonMode = .fill,
    cull_mode: CullMode = .none,
    depth_bias: DepthBiasDescriptor,
    front_ccw: bool = false,
    discard_enabled: bool = false,
    depth_clamp_enabled: bool = false,
    scissor_test_enabled: bool = false,
    multisample_enabled: bool = false,
    antialiased_lines_enabled: bool = false,
    conservative_rasterisation_enabled: bool = false,
    line_width: f32 = 1.0,
};

pub const BlendTargetDescriptor = struct {
    blend_enabled: bool = false,
    src_colour: BlendOperation = .src_alpha,
    dst_colour: BlendOperation = .inv_src_alpha,
    colour_arithmetic: BlendArithmetic = .add,
    src_alpha: BlendOperation = .src_alpha,
    dst_alpha: BlendOperation = .inv_src_alpha,
    alpha_arithmetic: BlendArithmetic = .add,
    colour_mask: ColourMask = .{},
};

pub const BlendDescriptor = struct {
    const max_num = Renderer.max_num_colour_attachments;
    alpha_to_coverage_enabled: bool = false,
    independent_blend_enabled: bool = false,
    sample_mask: u32 = ~0,
    logic_operation: LogicalOperation = .none,
    blend_factor: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
    blend_factor_dynamic: bool = false,
    targets: [max_num]BlendTargetDescriptor = .{} ** max_num,
};

pub const TesselationDescriptor = struct {
    partition_mode: TesselationPartition = .undefined,
    max_tesselation_factor: u32 = 64,
    output_winding_ccw: bool = false,
};

pub const GraphicsPipelineDescriptor = struct {
    pipeline_layout: ?Handle(Renderer.PipelineLayout) = null,
    render_pass: ?Handle(Renderer.RenderPass) = null,
    vertex_shader: ?Handle(Renderer.Shader) = null,
    tesselation_control_shader: ?Handle(Renderer.Shader) = null,
    tesselation_evaluation_shader: ?Handle(Renderer.Shader) = null,
    geometry_shader: ?Handle(Renderer.Shader) = null,
    fragment_shader: ?Handle(Renderer.Shader) = null,
    index_format: Renderer.format.Format = .undefined,
    primitive_topology: PrimitiveTopology = .triangle_list,
    viewports: ?[]const Viewport = null,
    scissors: ?[]const Scissor = null,
    depth: DepthDescriptor,
    stencil: StencilDescriptor,
    rasteriser: RasteriserDescriptor,
    blend: BlendDescriptor,
    tesselation: TesselationDescriptor,
};

pub const ComputerPipelineDescriptor = struct {
    pipeline_layout: ?Handle(Renderer.PipelineLayout) = null,
    compute_shader: ?Handle(Renderer.Shader) = null,
};
