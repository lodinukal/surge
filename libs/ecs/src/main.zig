const std = @import("std");
const testing = std.testing;

pub const common = @import("common.zig");

pub const EntityId = common.EntityId;

pub const component_registry = @import("component_registry.zig");

pub const id_component = component_registry.id_component;
pub const Composition = @import("composition.zig").Composition;
pub const World = @import("world.zig").World;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "composition_storage" {
    var buffer_a = [_]u8{0} ** (1024 * 20);

    var scratch_buffer_a = std.heap.FixedBufferAllocator.init(&buffer_a);

    var arena = std.heap.ArenaAllocator.init(scratch_buffer_a.allocator());

    const A = struct {
        x: i32,
    };
    const B = struct {
        x: bool,
    };

    var allocator = arena.allocator();

    var world = try World.init(allocator);
    const a_comp = try world.registerTypeComponent(A);

    const e1 = try world.addManyEntities(10);
    inline for (e1, 0..) |e, i| {
        try world.setComponent(e, A, A{ .x = i * 10 });
    }

    const use_ent1 = e1[5];
    try world.setComponent(use_ent1, B, B{ .x = true });

    const use_ent2 = e1[6];
    try world.setComponent(use_ent2, B, B{ .x = true });
    try world.removeComponent(use_ent2, A);

    var composition_1: *Composition = world.composition_storage.map.entries.get(1).value.?;
    const components_1 = (try composition_1.sliceComponent(A, a_comp))[0..composition_1.len];
    try testing.expectEqual(components_1.len, 8);

    var composition_2: *Composition = world.composition_storage.map.entries.get(2).value.?;
    const components_2 = (try composition_1.sliceComponent(B, a_comp))[0..composition_2.len];
    try testing.expectEqual(components_2.len, 1);

    var composition_3: *Composition = world.composition_storage.map.entries.get(3).value.?;
    const components_3 = (try composition_1.sliceComponent(B, a_comp))[0..composition_3.len];
    try testing.expectEqual(components_3.len, 1);

    // print memory usage
    // std.debug.print("arena: {}\n", .{arena.queryCapacity()});
}
