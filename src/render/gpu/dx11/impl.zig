const std = @import("std");

const Renderer = @import("../Renderer.zig");

const symbols = Renderer.SymbolTable{
    .get_renderer_info = &getRendererInfo,
    .get_rendering_capabilities = &getRenderingCapabilities,
    .deinit = &deinit,
};

pub export fn getSymbols() *const Renderer.SymbolTable {
    return &symbols;
}

fn deinit(r: *Renderer) void {
    _ = r;
}

fn getRendererInfo(r: *Renderer) Renderer.Error!*const Renderer.RendererInfo {
    return &.{
        .name = "d3d11 null renderer",
        .vendor = "none",
        .device = "software",
        .shading_language = .hlsl_5_0,
        .extensions = std.ArrayList([]const u8).init(r.allocator),
        .pipeline_cache_id = std.ArrayList(u8).init(r.allocator),
    };
}

fn getRenderingCapabilities(r: *Renderer) Renderer.Error!*const Renderer.RenderingCapabilities {
    return &.{
        .origin = .upper_left,
        .depth_range = .zero_to_one,
        .shading_languages = std.ArrayList(Renderer.ShadingLanguage).init(r.allocator),
        .formats = std.ArrayList(Renderer.format.Format).init(r.allocator),
        .features = .{},
        .limits = .{},
    };
}
