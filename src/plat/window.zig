const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../core/common.zig");
const input_enums = @import("../core/input_enums.zig");

pub const WindowFlags = packed struct {
    resized_disabled: bool,
    borderless: bool,
    always_on_top: bool,
    transparent: bool,
    no_focus: bool,
    popup: bool,
    extend_to_title_bar: bool,
    mouse_passthrough: bool,
};
