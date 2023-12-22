const gpu = @import("gpu.zig");

pub fn alignUp(x: usize, a: usize) usize {
    return (x + a - 1) / a * a;
}

pub fn calcOrigin(dimension: gpu.Texture.Dimension, origin: gpu.Origin3D) struct {
    x: u32,
    y: u32,
    z: u32,
    array_slice: u32,
} {
    return .{
        .x = origin.x,
        .y = origin.y,
        .z = if (dimension == .dimension_3d) origin.z else 0,
        .array_slice = if (dimension == .dimension_3d) 0 else origin.z,
    };
}

pub fn calcExtent(dimension: gpu.Texture.Dimension, extent: gpu.Extent3D) struct {
    width: u32,
    height: u32,
    depth: u32,
    array_count: u32,
} {
    return .{
        .width = extent.width,
        .height = extent.height,
        .depth = if (dimension == .dimension_3d) extent.depth_or_array_layers else 1,
        .array_count = if (dimension == .dimension_3d) 0 else extent.depth_or_array_layers,
    };
}
