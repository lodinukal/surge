const std = @import("std");

pub fn getRoot(comptime T: type, root: anytype) if (std.meta.trait.isConstPtr(@TypeOf(root)))
    *const T
else
    *T {
    return @constCast(@fieldParentPtr(T, "root", @constCast(root)));
}

pub fn populateVirtual(destination: anytype, comptime Src: type) void {
    if (comptime !(std.meta.trait.isSingleItemPtr(@TypeOf(destination)) and !std.meta.trait.isConstPtr(@TypeOf(destination)))) {
        @compileError("destination must be a pointer to a single item");
    }
    const typeInfo: std.builtin.Type = @typeInfo(@TypeOf(destination.virtual));
    inline for (typeInfo.Struct.fields) |field| {
        if (comptime std.meta.trait.hasFn(field.name)(Src)) {
            @field(destination.virtual, field.name) = @ptrCast(
                @constCast(&@field(Src, field.name)),
            );
        }
    }
}
