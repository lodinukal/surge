const std = @import("std");

pub fn getRoot(comptime T: type, root: anytype) if (std.meta.trait.isConstPtr(@TypeOf(root)))
    *const T
else
    *T {
    return @constCast(@fieldParentPtr(T, "root", @constCast(root)));
}
