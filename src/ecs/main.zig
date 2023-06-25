const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");

pub const EntityId = common.EntityId;

const component_registry = @import("component_registry.zig");
pub const Component = component_registry.Component;

pub const id_component = component_registry.id_component;
pub const Composition = @import("composition.zig").Composition;
pub const World = @import("world.zig").World;

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
    const b_comp = try world.registerTypeComponent(B);

    var compose1 = try world.addComposition(.{A});
    var compose2 = try world.addComposition(.{ A, B });
    var compose3 = try world.addComposition(.{B});

    const e1 = try world.addManyEntities(10);
    inline for (e1, 0..) |e, i| {
        _ = try world.transferEntity(compose1, e);
        try world.setComponent(e, A, A{ .x = i * 10 });
    }

    const use_ent1 = e1[5];
    _ = try world.transferEntity(compose2, use_ent1);
    try world.setComponent(use_ent1, B, B{ .x = true });

    const use_ent2 = e1[6];
    _ = try world.transferEntity(compose2, use_ent2);
    try world.setComponent(use_ent2, B, B{ .x = true });
    _ = try world.transferEntity(compose3, use_ent2);

    const components_1 = (try compose1.composition.sliceComponent(
        A,
        a_comp,
    ))[0..compose1.composition.len];
    try testing.expectEqual(@intCast(usize, 8), components_1.len);

    const components_2 = (try compose2.composition.sliceComponent(
        B,
        b_comp,
    ))[0..compose2.composition.len];
    try testing.expectEqual(@intCast(usize, 1), components_2.len);

    const components_3 = (try compose3.composition.sliceComponent(
        B,
        b_comp,
    ))[0..compose3.composition.len];
    try testing.expectEqual(@intCast(usize, 1), components_3.len);

    // print memory usage
    // std.debug.print("arena: {}\n", .{arena.queryCapacity()});
}
