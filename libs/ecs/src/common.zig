const std = @import("std");
const builtin = @import("builtin");

pub const assert = std.debug.assert;
pub const err = std.log.err;

pub const Error = error{
    ComponentNotFound,
};
pub const EntityId = u32;
