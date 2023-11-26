const Renderer = @import("Renderer.zig");

pub const ImageView = struct {
    format: Renderer.format.ImageFormat = .rgba,
    data_type: Renderer.format.DataType = .u8,
    data: []const u8,
};

pub const MutableImageView = struct {
    format: Renderer.format.ImageFormat = .rgba,
    data_type: Renderer.format.DataType = .u8,
    data: []u8,
};
