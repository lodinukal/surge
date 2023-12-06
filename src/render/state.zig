const std = @import("std");
const gpu = @import("gpu.zig");

pub const BufferStateTracker = struct {
    descriptor: *const gpu.Buffer.Descriptor,
    permanent_state: gpu.ResourceStates = .{},
};

pub const TextureStateTracker = struct {
    descriptor: *const gpu.Texture.Descriptor,
    permanent_state: gpu.ResourceStates = .{},
    initialised: bool = false,
};

pub const TextureState = struct {
    subresource_states: std.ArrayList(gpu.ResourceStates),
    state: gpu.ResourceStates = .{},
    enable_uav_barriers: bool = false,
    first_uav_barrier_placed: bool = false,
    permanent_transition: bool = false,

    pub fn init(allocator: std.mem.Allocator) !TextureState {
        const self = TextureState{
            .subresource_states = try allocator.alloc(std.ArrayList(gpu.ResourceStates)),
        };
        return self;
    }
};

pub const BufferState = struct {
    state: gpu.ResourceStates = .{},
    enable_uav_barriers: bool = false,
    first_uav_barrier_placed: bool = false,
    permanent_transition: bool = false,
};

pub const TextureBarrier = struct {
    texture: ?*TextureStateTracker = null,
    mip_level: gpu.MipLevel = 0,
    array_slice: gpu.ArraySlice = 0,
    entire_texture: bool = false,
    before: gpu.ResourceStates = .{},
    after: gpu.ResourceStates = .{},
};

pub const BufferBarrier = struct {
    buffer: ?*BufferStateTracker = null,
    before: gpu.ResourceStates = .{},
    after: gpu.ResourceStates = .{},
};

pub const CommandListResourceStateTracker = struct {};
