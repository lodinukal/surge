const std = @import("std");
const testing = std.testing;

pub const common = @import("common.zig");
pub const composition_ns = @import("composition.zig");
pub const component_registry = @import("component_registry.zig");
pub const composition_storage = @import("composition_storage.zig");

const Component = component_registry.Component;
const CompositionStorage = composition_storage.CompositionStorage;
const ComponentRegistry = component_registry.ComponentRegistry;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "composition_storage" {
    var buffer_a = [_]u8{0} ** 1024;
    var buffer_b = [_]u8{0} ** (1024 * 4);

    var scratch_buffer_a = std.heap.FixedBufferAllocator.init(&buffer_a);
    var scratch_buffer_b = std.heap.FixedBufferAllocator.init(&buffer_b);

    var arena_long = std.heap.ArenaAllocator.init(scratch_buffer_a.allocator());
    var arena_comp = std.heap.ArenaAllocator.init(scratch_buffer_b.allocator());

    var allocator_long = arena_long.allocator();
    var allocator_comp = arena_comp.allocator();

    var store = try CompositionStorage.init(allocator_long);
    defer store.deinit();

    const A = struct {
        x: u32,
    };

    const B = struct {
        x: bool,
    };

    const C = struct {
        x: u16,
    };

    const D = packed struct(u48) {
        x: u48,
    };

    var register = component_registry.ComponentRegistry.init(allocator_long);
    const comps = try register.registerTypeComponentTuple(.{ A, B, C, D });
    const a_comp = comps[0];
    const b_comp = comps[1];
    const c_comp = comps[2];
    var d_comp = comps[2];
    d_comp.type_size = 6;

    const ensure_cap = 0;

    // compositions
    var composition_path_a = [_]Component{ a_comp, b_comp };
    var composition_a = try store.addComposition(&composition_path_a);
    try composition_a.ensureCapacity(allocator_comp, ensure_cap);
    var composition_path_b = [_]Component{ a_comp, c_comp, b_comp };
    var composition_b = try store.addComposition(&composition_path_b);
    try composition_b.ensureCapacity(allocator_comp, ensure_cap);
    var composition_path_c = [_]Component{ a_comp, c_comp, d_comp };
    var composition_c = try store.addComposition(&composition_path_c);
    try composition_c.ensureCapacity(allocator_comp, ensure_cap);

    // entities
    var data_a = [_]u8{ 0, 0, 0, 0, 50, 0, 0, 0, 1 };
    var a_row = try composition_a.addRow(allocator_comp);
    composition_a.setRow(a_row, &data_a);

    var data_b = [_]u8{ 1, 0, 0, 0, 2, 1, 0, 0, 0, 3, 0 };
    var b_row = try composition_b.addRow(allocator_comp);
    composition_b.setRow(b_row, &data_b);

    var data_c = [_]u8{ 2, 0, 0, 0, 3, 0, 0, 0, 0, 9, 0, 1, 1, 0, 0, 0 };
    var c_row = try composition_c.addRow(allocator_comp);
    composition_c.setRow(c_row, &data_c);

    var multi_iter_1 = try composition_a.getIterator(
        allocator_long,
        .{ a_comp, b_comp },
    );
    var view_access_a = try multi_iter_1.getAccess(A, a_comp);
    var view_access_b = try multi_iter_1.getAccess(B, b_comp);
    defer multi_iter_1.deinit(allocator_long);

    var idx: usize = 0;
    while (multi_iter_1.next()) |view| : (idx += 1) {
        var component_a = view_access_a.get(&view);
        var component_b = view_access_b.get(&view);
        component_a.x += 25;
        component_b.x = false;
    }

    var multi_iter_2 = try composition_a.getIterator(
        allocator_long,
        .{ a_comp, b_comp },
    );
    var view_access_b_2 = try multi_iter_2.getConstAccess(B, b_comp);
    defer multi_iter_2.deinit(allocator_long);

    idx = 0;
    while (multi_iter_2.next()) |view| : (idx += 1) {
        var component_b = view_access_b_2.get(&view);
        try std.testing.expectEqual(component_b.x, false);
    }

    std.debug.print("composition_store\n    long: {}B\n    comp: {}B\n", .{
        arena_long.queryCapacity(),
        arena_comp.queryCapacity(),
    });
}
