const std = @import("std");

const app = @import("../../app/app.zig");

const Renderer = @import("Renderer.zig");
const Handle = Renderer.Handle;

const Self = @This();

vtable: *const struct {
    submit: *const fn (*Self, command_buffer: Handle(Renderer.CommandBuffer)) void,
    queryResult: *const fn (
        *Self,
        query_heap: Handle(Renderer.QueryHeap),
        first_query: u32,
        num_queries: u32,
        data: []const u8,
    ) bool,
    submitFence: *const fn (*Self, Handle(Renderer.Fence)) void,
    waitFence: *const fn (*Self, Handle(Renderer.Fence), timeout: u64) void,
    waitIdle: *const fn (*Self) void,
},

pub inline fn submit(self: *Self, command_buffer: Handle(Renderer.CommandBuffer)) void {
    self.vtable.submit(self, command_buffer);
}

pub inline fn queryResult(
    self: *Self,
    query_heap: Handle(Renderer.QueryHeap),
    first_query: u32,
    num_queries: u32,
    data: []const u8,
) bool {
    return self.vtable.queryResult(self, query_heap, first_query, num_queries, data);
}

pub inline fn submitFence(self: *Self, fence: Handle(Renderer.Fence)) void {
    self.vtable.submitFence(self, fence);
}

pub inline fn waitFence(self: *Self, fence: Handle(Renderer.Fence), timeout: u64) void {
    self.vtable.waitFence(self, fence, timeout);
}

pub inline fn waitIdle(self: *Self) void {
    self.vtable.waitIdle(self);
}
