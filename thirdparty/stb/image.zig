pub const std = @import("std");

const c = @cImport({
    @cInclude("stb_image.h");
});

pub const Error = error{
    FailedToLoad,
};

pub const Info = struct {
    width: u32 = 0,
    height: u32 = 0,
    channels: u32 = 0,
};

var stbi_allocator: std.mem.Allocator = undefined;

fn allocatorPointerFromClient(pv: [*]u8) []u8 {
    const original_ptr: [*]u8 = @ptrFromInt(@intFromPtr(pv) - 8);
    const original_size = std.mem.readInt(usize, @ptrCast(original_ptr[0..8]), .little);
    return original_ptr[0 .. original_size + 8];
}

fn clientPointerFromAllocator(pv: []u8) [*]u8 {
    std.mem.writeInt(usize, pv[0..8], pv.len - 8, .little);
    return @ptrFromInt(@intFromPtr(pv.ptr) + 8);
}

export fn _stbi_malloc(size: usize) callconv(.C) [*c]u8 {
    const ptr = stbi_allocator.alloc(u8, size + 8) catch return null;
    std.mem.writeInt(usize, ptr[0..8], size, .little);
    return clientPointerFromAllocator(ptr);
}

export fn _stbi_free(ptr: [*]u8) callconv(.C) void {
    if (@intFromPtr(ptr) == 0) return;
    stbi_allocator.free(allocatorPointerFromClient(ptr));
}

export fn _stbi_realloc(ptr: [*]u8, size: usize) callconv(.C) [*c]u8 {
    if (@intFromPtr(ptr) == 0) return _stbi_malloc(size);
    const original_ptr = allocatorPointerFromClient(ptr);
    const new_ptr = stbi_allocator.realloc(original_ptr, size + 8) catch return null;
    std.mem.writeInt(usize, new_ptr[0..8], size, .little);
    return clientPointerFromAllocator(new_ptr);
}

pub inline fn setAllocator(al: std.mem.Allocator) void {
    stbi_allocator = al;
}

pub const Image = struct {
    data: []u8,
    info: Info,

    pub fn load(buffer: []const u8) !Image {
        var x: c_int = 0;
        var y: c_int = 0;
        var channels: c_int = 0;
        const raw_img: ?[*]u8 = @ptrCast(c.stbi_load_from_memory(
            buffer.ptr,
            @intCast(buffer.len),
            &x,
            &y,
            &channels,
            c.STBI_rgb_alpha,
        ));
        channels = 4;
        const img: [*]u8 = raw_img orelse return Error.FailedToLoad;

        return .{
            .data = img[0 .. @as(
                usize,
                @intCast(x),
            ) * @as(
                usize,
                @intCast(y),
            ) * @as(
                usize,
                @intCast(channels),
            )],
            .info = .{
                .width = @intCast(x),
                .height = @intCast(y),
                .channels = @intCast(channels),
            },
        };
    }

    pub fn deinit(self: *Image) void {
        c.stbi_image_free(@ptrCast(self.data));
    }
};

comptime {
    _ = _stbi_free;
    _ = _stbi_malloc;
    _ = _stbi_realloc;
}
