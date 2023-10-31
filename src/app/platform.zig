const std = @import("std");
const builtin = @import("builtin");

const root = @import("root");
pub const Platform = enum {
    windows,
    osx,
    ios,
    android,
    xboxone,
    ps5,
    ps4,
    nx,
    ouya,
    androidtv,
    chromecast,
    linux,
    steamos,
    webos,
    @"switch",
    none,

    pub fn fromTag(target: std.Target) Platform {
        if (std.meta.trait.hasDecls(root, .{"target_override"}))
            return root.target_override;
        return switch (target.os.tag) {
            .windows => if (std.meta.trait.hasDecls(root, .{"xbox"}))
                .xboxone
            else
                .windows,
            .macos => .osx,
            .linux => switch (target.abi) {
                .android => if (std.meta.trait.hasDecls(root, .{"android_tv"}))
                    .androidtv
                else
                    .android,
                .linux => .linux,
            },
            .ps4 => .ps4,
            .ios => .ios,
            .tvos => .ios,
            else => .none,
        };
    }
};

pub const this_platform = if (std.meta.trait.hasDecls(root, .{"target_override"}))
    root.target_override
else
    Platform.fromTag(builtin.target);
pub const impl = switch (this_platform) {
    .windows => @import("./platform/windows.zig"),
    .xboxone => @import("./platform/windows.zig"),
    inline else => @compileError("Unsupported OS"),
};
