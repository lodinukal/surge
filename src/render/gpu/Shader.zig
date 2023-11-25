const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");
const Handle = Renderer.Handle;
const VertexAttribute = Renderer.VertexAttribute;
const FragmentAttribute = Renderer.FragmentAttribute;

const Self = @This();

type: ShaderType = .undefined,

pub fn init(self: *Self, t: ShaderType) void {
    self.type = t;
}

pub const ShaderType = enum {
    undefined,
    vertex,
    tesselation_control, // aka. hull
    tesselation_evaluation, // aka. domain
    geometry,
    fragment,
    compute,

    pub fn toStages(self: ShaderType) ShaderStages {
        switch (self) {
            .vertex => return .{ .vertex = true },
            .tesselation_control => return .{ .tesselation_control = true },
            .tesselation_evaluation => return .{ .tesselation_evaluation = true },
            .geometry => return .{ .geometry = true },
            .fragment => return .{ .fragment = true },
            .compute => return .{ .compute = true },
            else => return .{},
        }
    }
};

pub const ShaderSourceType = enum {
    code_string,
    binary_buffer,
};

pub const ShaderOptimisationLevel = enum {
    none,
    one,
    two,
    three,
};

pub const ShaderCompileInfo = struct {
    debug: bool = true,
    optimisation_level: ShaderOptimisationLevel = .none,
    warnings_as_errors: bool = true,
};

pub const ShaderStages = struct {
    vertex: bool = false,
    tesselation_control: bool = false,
    tesselation_evaluation: bool = false,
    geometry: bool = false,
    fragment: bool = false,
    compute: bool = false,

    pub fn isTesselationStage(self: ShaderStages) bool {
        return self.tesselation_control or self.tesselation_evaluation;
    }

    pub fn isGraphicsStage(self: ShaderStages) bool {
        return self.vertex or self.isTesselationStage() or self.geometry or self.fragment;
    }
};

// Shader Reflection
pub const ShaderMacro = struct {
    name: []const u8,
    value: ?[]const u8 = null,
};

pub const SystemValue = enum {
    /// Undefined system value.
    undefined,

    /// Forward-compatible mechanism for vertex clipping.
    clip_distance,

    /// Fragment output color value.
    color,

    /// Mechanism for controlling user culling.
    cull_distance,

    /// Fragment depth value.
    depth,

    /// Fragment depth value that is greater than or equal to the previous one.
    depth_greater,

    /// Fragment depth value that is less than or equal to the previous one.
    depth_less,

    /// Indicates whether a primitive is front or back facing.
    front_facing,

    /// Index of the input instance.
    /// This value behaves differently between Direct3D and OpenGL.
    /// CommandBuffer.drawInstanced(u32, u32, u32, u32)
    instance_id,

    /// Vertex or fragment position.
    position,

    /// Index of the geometry primitive.
    primitive_id,

    /// Index of the render target layer.
    render_target_index,

    /// Sample coverage mask.
    sample_mask,

    /// Index of the input sample.
    sample_id,

    /// Fragment stencil value.
    /// Only supported with: Direct3D 11.3, Direct3D 12, Metal.
    stencil,

    /// Index of the input vertex.
    /// This value behaves differently between Direct3D and OpenGL.
    /// CommandBuffer::Draw
    vertex_id,

    /// Index of the viewport array.
    viewport_index,
};

pub const VertexShaderAttributes = struct {
    input: ?[]const VertexAttribute = null,
    output: ?[]const VertexAttribute = null,
};

pub const FragmentShaderAttributes = struct {
    input: ?[]const FragmentAttribute = null,
};

pub const ComputeShaderAttributes = struct {
    work_group_size: [3]u32,
};

pub const ShaderDescriptor = struct {
    type: ShaderType = .undefined,
    source: []const u8,
    source_type: ShaderSourceType = .code_string,
    entry_point: []const u8 = "main",
    profile: ?[]const u8 = null,
    macros: []const ShaderMacro = &.{},
    compile_info: ShaderCompileInfo = .{},
    name: ?[]const u8 = null,
    vertex: VertexShaderAttributes = .{},
    fragment: FragmentShaderAttributes = .{},
    /// metal only
    compute: ?ComputeShaderAttributes = null,
};
