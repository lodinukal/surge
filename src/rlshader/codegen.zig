const std = @import("std");

const rl = @import("rl");
const Tree = rl.Tree;

pub const hlsl = @import("codegen/hlsl.zig");

pub const OutputLanguage = enum {
    hlsl,
};

pub fn generate(
    tree: *Tree,
    allocator: std.mem.Allocator,
    output_language: OutputLanguage,
) ![]u8 {
    switch (output_language) {
        OutputLanguage.hlsl => hlsl.generate(allocator, tree),
    }
}

pub const shader_prelude = @embedFile("prelude.rl");

pub const custom_keywords: []const []const u8 = &.{
    "discard",
};

pub const Attributes = enum {
    location,
    binding,
    group,
    workgroup,
    storage,
    read_write,
    builtin,
    workgroup_size,
    compute,
    vertex,
    fragment,
};
