const std = @import("std");

const ComponentA = struct {
    e: u32,
};
const ComponentB = struct {
    p: bool,
};

const IdComponent = Component{
    .id = 0,
    .type_size = @typeInfo(Component).size,
};

pub fn registerTypeComponent(comptime T: type, allocator: std.mem.Allocator) !Component {
    const id = typeUnique(T);

    var gop = try type_id_to_id.getOrPut(allocator, id);
    if (!gop.found_existing) {
        gop.value_ptr.* = registerComponent(@sizeOf(T));
    }
    return gop.value_ptr.*;
}

fn typeUnique(comptime T: type) usize {
    _ = T;
    return @ptrToInt(&struct {
        const x: u32 = 0;
    }.x);
}

var component_id_counter: u32 = 1;
pub fn registerComponent(size: u32) Component {
    defer component_id_counter += 1;
    return Component{
        .id = component_id_counter,
        .type_size = size,
    };
}

const Component = packed struct(u64) {
    id: u32,
    type_size: u32,
};

var type_id_to_id: std.AutoHashMapUnmanaged(usize, Component) = undefined;

pub fn main() !void {}

test "t" {
    type_id_to_id = std.AutoHashMapUnmanaged(usize, Component){};
    defer type_id_to_id.deinit(std.heap.page_allocator);

    const x = try registerTypeComponent(ComponentA, std.heap.page_allocator);
    const y = try registerTypeComponent(ComponentB, std.heap.page_allocator);
    const z = try registerTypeComponent(ComponentA, std.heap.page_allocator);
    std.debug.print("a:   {}\nb:   {}\nc:   {}\n", .{ x, y, z });
    const rt1 = registerComponent(1);
    const rt2 = registerComponent(2);
    const rt3 = registerComponent(3);
    std.debug.print("rt1: {}\nrt2: {}\nrt3: {}\n", .{ rt1, rt2, rt3 });
}
