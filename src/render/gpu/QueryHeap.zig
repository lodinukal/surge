const std = @import("std");

const Renderer = @import("Renderer.zig");

const Self = @This();

pub const QueryType = enum {
    samples_passed,
    any_samples_passed,
    any_samples_passed_conservative,
    time_elapsed,
    stream_out_primitives_written,
    stream_out_overflow,
    pipeline_statistics,
};

pub const QueryPipelineStatistics = struct {
    input_assembly_vertices: u64 = 0,
    input_assembly_primitives: u64 = 0,
    vertex_shader_invocations: u64 = 0,
    geometry_shader_invocations: u64 = 0,
    geometry_shader_primitives: u64 = 0,
    clipping_invocations: u64 = 0,
    clipping_primitives: u64 = 0,
    fragment_shader_invocations: u64 = 0,
    tessellation_control_shader_invocations: u64 = 0,
    tessellation_evaluation_shader_invocations: u64 = 0,
    compute_shader_invocations: u64 = 0,
};

pub const QueryHeapDescriptor = struct {
    query_type: QueryType = .samples_passed,
    num_queries: u32 = 1,
    render_condition: bool = false,
};
