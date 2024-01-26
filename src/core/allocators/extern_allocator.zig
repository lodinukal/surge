const std = @import("std");

pub const ExternAllocator = extern struct {
    ptr: *anyopaque,
    vtable: *align(@alignOf(std.mem.Allocator.VTable)) const anyopaque,

    pub inline fn fromStd(al: std.mem.Allocator) ExternAllocator {
        return .{
            .ptr = @ptrCast(al.ptr),
            .vtable = @ptrCast(al.vtable),
        };
    }

    pub inline fn toStd(self: ExternAllocator) std.mem.Allocator {
        return .{
            .ptr = @ptrCast(self.ptr),
            .vtable = @ptrCast(self.vtable),
        };
    }
};
