const std = @import("std");
const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d12 = win32.graphics.direct3d12;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const TRUE = win32.foundation.TRUE;
const FALSE = win32.foundation.FALSE;

const d3dcommon = @import("../d3d/common.zig");

const common = @import("../../core/common.zig");

pub inline fn convertFormat(format: gpu.Format) dxgi.common.DXGI_FORMAT {
    return d3dcommon.convertFormat(format);
}

pub fn convertShaderStage(s: gpu.Shader.Type) d3d12.D3D12_SHADER_VISIBILITY {
    if (s.vertex) return .VERTEX;
    if (s.hull) return .HULL;
    if (s.domain) return .DOMAIN;
    if (s.geometry) return .GEOMETRY;
    if (s.pixel) return .PIXEL;
    if (s.amplification) return .AMPLIFICATION;
    if (s.mesh) return .MESH;
    return .ALL;
}

pub fn convertBlendValue(factor: gpu.BlendState.Factor) d3d12.D3D12_BLEND {
    return switch (factor) {
        .zero => .ZERO,
        .one => .ONE,
        .src_colour => .SRC_COLOR,
        .inv_src_colour => .INV_SRC_COLOR,
        .src_alpha => .SRC_ALPHA,
        .inv_src_alpha => .INV_SRC_ALPHA,
        .dst_alpha => .DEST_ALPHA,
        .inv_dst_alpha => .INV_DEST_ALPHA,
        .dst_colour => .DEST_COLOR,
        .inv_dst_colour => .INV_DEST_COLOR,
        .src_alpha_sat => .SRC_ALPHA_SAT,
        .constant_colour => .BLEND_FACTOR,
        .inv_constant_colour => .INV_BLEND_FACTOR,
        .src_1_colour => .SRC1_COLOR,
        .inv_src_1_colour => .INV_SRC1_COLOR,
        .src_1_alpha => .SRC1_ALPHA,
        .inv_src_1_alpha => .INV_SRC1_ALPHA,
        else => unreachable,
    };
}

pub fn convertBlendOp(op: gpu.BlendState.Op) d3d12.D3D12_BLEND_OP {
    return switch (op) {
        .add => .ADD,
        .subtract => .SUBTRACT,
        .reverse_subtract => .REV_SUBTRACT,
        .min => .MIN,
        .max => .MAX,
        else => unreachable,
    };
}

pub fn convertStencilOp(op: gpu.DepthStencilState.Op) d3d12.D3D12_STENCIL_OP {
    return switch (op) {
        .keep => .KEEP,
        .zero => .ZERO,
        .replace => .REPLACE,
        .increment_and_clamp => .INCR_SAT,
        .decrement_and_clamp => .DECR_SAT,
        .invert => .INVERT,
        .increment_and_wrap => .INCR,
        .decrement_and_wrap => .DECR,
        else => unreachable,
    };
}

pub fn convertComparisonFunc(func: gpu.DepthStencilState.Comparison) d3d12.D3D12_COMPARISON_FUNC {
    return switch (func) {
        .never => .NEVER,
        .less => .LESS,
        .equal => .EQUAL,
        .less_or_equal => .LESS_EQUAL,
        .greater => .GREATER,
        .not_equal => .NOT_EQUAL,
        .greater_or_equal => .GREATER_EQUAL,
        .always => .ALWAYS,
        else => unreachable,
    };
}

pub fn convertPrimitiveType(ty: gpu.PrimitiveType, control_points: u32) d3d.D3D_PRIMITIVE_TOPOLOGY {
    return switch (ty) {
        .point_list => ._PRIMITIVE_TOPOLOGY_POINTLIST,
        .line_list => ._PRIMITIVE_TOPOLOGY_LINELIST,
        .triangle_list => ._PRIMITIVE_TOPOLOGY_TRIANGLELIST,
        .triangle_strip => ._PRIMITIVE_TOPOLOGY_TRIANGLESTRIP,
        .triangle_fan => unreachable,
        .triangle_list_with_adjacency => ._PRIMITIVE_TOPOLOGY_TRIANGLELIST_ADJ,
        .triangle_strip_with_adjacency => ._PRIMITIVE_TOPOLOGY_TRIANGLESTRIP_ADJ,
        .patch_list => {
            if (control_points == 0 or control_points > 32) unreachable;
            return @enumFromInt(d3d.D3D_PRIMITIVE_TOPOLOGY(
                @intFromEnum(d3d.D3D_PRIMITIVE_TOPOLOGY_1_CONTROL_POINT_PATCHLIST) + control_points - 1,
            ));
        },
        else => ._PRIMITIVE_TOPOLOGY_UNDEFINED,
    };
}

pub fn convertSamplerAddressMode(mode: gpu.Sampler.AddressMode) d3d12.D3D12_TEXTURE_ADDRESS_MODE {
    return switch (mode) {
        .clamp => .CLAMP,
        .wrap => .WRAP,
        .border => .BORDER,
        .mirror => .MIRROR,
        .mirror_once => .MIRROR_ONCE,
        else => unreachable,
    };
}

pub fn convertSamplerReductionType(ty: gpu.Sampler.ReductionType) d3d12.D3D12_FILTER_REDUCTION_TYPE {
    return switch (ty) {
        .standard => .STANDARD,
        .comparison => .COMPARISON,
        .minimum => .MINIMUM,
        .maximum => .MAXIMUM,
        else => unreachable,
    };
}

pub fn convertResourceStates(state: gpu.ResourceStates) d3d12.D3D12_RESOURCE_STATES {
    var res: u32 = 0;
    if (state.constant_buffer) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER);
    if (state.vertex_buffer) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER);
    if (state.index_buffer) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_INDEX_BUFFER);
    if (state.indirect_argument) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT);
    if (state.shader_resource) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE) |
        @intFromEnum(d3d12.D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE);
    if (state.unordered_access) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
    if (state.render_target) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RENDER_TARGET);
    if (state.depth_write) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_DEPTH_WRITE);
    if (state.depth_read) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_DEPTH_READ);
    if (state.stream_out) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_STREAM_OUT);
    if (state.copy_dest) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_COPY_DEST);
    if (state.copy_source) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_COPY_SOURCE);
    if (state.resolve_dest) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RESOLVE_DEST);
    if (state.resolve_source) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RESOLVE_SOURCE);
    if (state.present) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_PRESENT);
    if (state.accel_structure_read) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
    if (state.accel_structure_write) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
    if (state.accel_structure_build_input) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
    if (state.accel_structure_build_bias) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
    if (state.shading_rate_source) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_SHADING_RATE_SOURCE);
    if (state.opacity_micromap_build_input) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
    if (state.opacity_micromap_write) res |= @intFromEnum(d3d12.D3D12_RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);

    return @enumFromInt(res);
}

pub fn convertPixelShadingRate(rate: gpu.VariableShadingRate) d3d12.D3D12_SHADING_RATE {
    return switch (rate) {
        .e1x1 => .@"1X1",
        .e1x2 => .@"1X2",
        .e2x1 => .@"2X1",
        .e2x2 => .@"2X2",
        .e2x4 => .@"2X4",
        .e4x2 => .@"4X2",
        .e4x4 => .@"4X4",
    };
}

pub fn convertShadingRateCombiner(combiner: gpu.ShadingRateCombiner) d3d12.D3D12_SHADING_RATE_COMBINER {
    return switch (combiner) {
        .override => .OVERRIDE,
        .min => .MIN,
        .max => .MAX,
        .apply_relative => .SUM,
        else => .PASSTHROUGH,
    };
}
