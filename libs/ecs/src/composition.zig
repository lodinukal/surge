const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");

const assert = common.assert;
const err = common.err;
const Error = common.Error;

const component_tree = @import("component_tree.zig");
const Component = component_tree.Component;

pub const Composition = struct {
    components: []Component,
    data: [][*]u8,
    len: u32 = 0,
    entity_size: u32 = 0,
    capacity: u32 = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        components: []Component,
    ) !Composition {
        var data = try allocator.alloc([*]u8, components.len);
        for (components, 0..) |_, component_idx| {
            data[component_idx] = @ptrCast([*]u8, try allocator.alloc(u8, 0));
        }
        return Composition{
            .components = components,
            .data = data,
            .len = 0,
            .entity_size = Composition.getComponentsSize(components),
            .capacity = 0,
        };
    }

    fn getComponentsSize(components: []Component) u32 {
        var total_entity_size: u32 = 0;
        for (components) |component| {
            total_entity_size += component.type_size;
        }
        return total_entity_size;
    }

    pub fn deinit(self: *Composition, allocator: std.mem.Allocator) void {
        for (self.data) |field| {
            allocator.free(field[0 .. self.capacity * self.entity_size]);
        }
        allocator.free(self.data);
    }

    pub fn ensureCapacity(self: *Composition, allocator: std.mem.Allocator, new_capacity: u32) !void {
        // Don't need to do anything if it's a 0 size entity
        if (self.entity_size == 0) {
            return;
        }
        // We have enough space
        if (new_capacity <= self.capacity) {
            return;
        }
        for (self.components, 0..) |component, component_idx| {
            var old_buffer = self.data[component_idx][0 .. self.capacity * component.type_size];
            var new_buffer = try allocator.alloc(u8, new_capacity * component.type_size);
            @memcpy(new_buffer[0..old_buffer.len], old_buffer);
            allocator.free(old_buffer);
            self.data[component_idx] = @ptrCast([*]u8, new_buffer);
        }
        self.capacity = new_capacity;
    }

    pub fn addRow(self: *Composition, allocator: std.mem.Allocator) !u32 {
        try self.ensureCapacity(allocator, self.len + 1);
        var row = self.len;
        self.len += 1;
        return row;
    }

    // swap removal
    pub fn removeRow(self: *Composition, row: u32) void {
        self.len -= 1;
        // if this already out of bounds, then we don't need to do anything
        // or, if its a 0 size entity, then we don't need to do anything
        if (self.entity_size == 0 or row >= self.len) {
            return;
        }
        // swaps with the last row for each component
        for (self.components, 0..) |component, component_idx| {
            const component_buffer = self.data[component_idx][0 .. self.capacity * component.type_size];
            @memcpy(
                component_buffer[row..][0..component.type_size],
                component_buffer[self.len * component.type_size ..][0..component.type_size],
            );
        }
    }

    pub fn getMultiComponentIterator(
        self: *Composition,
        allocator: std.mem.Allocator,
        components: anytype,
    ) !MultiComponentIterator {
        return try MultiComponentIterator.init(self, components, allocator);
    }

    pub const MultiComponentIterator = struct {
        composition: *Composition,
        iterators: []Composition.ComponentIterator,
        out_cache: [][]u8,
        idx: usize = 0,

        pub fn init(composition: *Composition, components: anytype, allocator: std.mem.Allocator) !MultiComponentIterator {
            // check if the composition has all the components
            inline for (components) |find_component| {
                if (!composition.hasComponent(find_component)) {
                    err("{*} does not have component(id: {})", .{
                        composition,
                        find_component.id,
                    });
                    return Error.ComponentNotFound;
                }
            }

            const Components = comptime @TypeOf(components);
            const component_count = comptime @typeInfo(Components).Struct.fields.len;
            const iterator_data = try allocator.alloc(Composition.ComponentIterator, component_count);

            inline for (0..component_count) |idx| {
                iterator_data[idx] = try composition.getComponentIterator(components[idx]);
            }

            return MultiComponentIterator{
                .composition = composition,
                .iterators = iterator_data,
                .out_cache = try allocator.alloc([]u8, component_count),
                .idx = 0,
            };
        }

        pub fn deinit(self: *MultiComponentIterator, allocator: std.mem.Allocator) void {
            allocator.free(self.iterators);
        }

        pub fn next(self: *MultiComponentIterator) ?[][]u8 {
            if (self.done()) {
                return null;
            }

            var out = self.out_cache;
            for (self.iterators, 0..) |*it, iterator_idx| {
                var component = it.next(false).?.data;
                out[iterator_idx] = component;
            }

            return out;
        }

        pub fn done(self: *MultiComponentIterator) bool {
            for (self.iterators) |it| {
                if (it.done()) {
                    return true;
                }
            }
            return false;
        }
    };

    pub fn getComponentIterator(self: *Composition, component: Component) !ComponentIterator {
        return ComponentIterator.init(self, component);
    }

    pub const ComponentIterator = struct {
        composition: *Composition,
        buffer: []u8,
        index: u32,
        component: Component,

        pub fn init(composition: *Composition, component: Component) !ComponentIterator {
            return ComponentIterator{
                .composition = composition,
                .buffer = try composition.getComponentBuffer(component),
                .index = 0,
                .component = component,
            };
        }

        fn RowComponentPair(comptime readonly: bool) type {
            return struct {
                row: u32,
                data: if (readonly) []const u8 else []u8,
            };
        }

        pub fn next(self: *ComponentIterator, comptime readonly: bool) ?RowComponentPair(readonly) {
            if (self.done()) {
                return null;
            }
            const pair = RowComponentPair(readonly){
                .row = self.index,
                .data = self.buffer[(self.index * self.component.type_size)..][0..self.component.type_size],
            };
            self.index += 1;
            return pair;
        }

        pub fn done(self: *const ComponentIterator) bool {
            return self.index >= self.composition.len;
        }
    };

    pub fn setRow(self: *Composition, row: u32, data: []u8) void {
        var data_offset: u32 = 0;
        for (self.components, 0..) |component, component_idx| {
            var component_buffer = self.data[component_idx][0 .. self.capacity * component.type_size];
            @memcpy(
                component_buffer[(row * component.type_size)..][0..component.type_size],
                data[data_offset..][0..component.type_size],
            );
            data_offset += component.type_size;
        }
    }

    pub fn getRow(self: *const Composition, row: u32, output: []u8) void {
        var data_offset: u32 = 0;
        for (self.components, 0..) |component, component_idx| {
            var component_buffer = self.data[component_idx][0 .. self.capacity * component.type_size];
            @memcpy(
                output[data_offset..][0..component.type_size],
                component_buffer[(row * component.type_size)..][0..component.type_size],
            );
            data_offset += component.type_size;
        }
    }

    pub fn getComponent(self: *const Composition, row: u32, component: Component) ![]u8 {
        return (try self.getComponentBuffer(component))[row..][0..component.type_size];
    }

    pub fn getComponentBuffer(self: *const Composition, component: Component) ![]u8 {
        if (self.getComponentOrder(component)) |component_idx| {
            return self.data[component_idx][0 .. self.capacity * component.type_size];
        } else {
            return Error.ComponentNotFound;
        }
    }

    pub fn hasComponent(self: *const Composition, component: Component) bool {
        return self.getComponentOrder(component) != null;
    }

    pub fn getComponentOrder(self: *const Composition, component: Component) ?u32 {
        return if (std.sort.binarySearch(
            Component,
            component,
            self.components,
            {},
            Component.order,
        )) |component_idx| {
            return @intCast(u32, component_idx);
        } else {
            return null;
        };
    }
};

test "add_remove_iterator" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var components = [_]Component{
        Component{ .id = 0, .type_size = 3 },
        Component{ .id = 1, .type_size = 2 },
        Component{ .id = 2, .type_size = 1 },
    };

    var comp = try Composition.init(allocator, &components);
    defer comp.deinit(allocator);

    var row1 = try comp.addRow(allocator);
    var row_emplace_data1 = [_]u8{ 4, 3, 6, 4, 1, 1 };
    comp.setRow(row1, &row_emplace_data1);

    var row2 = try comp.addRow(allocator);
    var row_emplace_data2 = [_]u8{ 4, 8, 2, 0, 0, 44 };
    comp.setRow(row2, &row_emplace_data2);

    var row3 = try comp.addRow(allocator);
    var row_emplace_data3 = [_]u8{ 5, 3, 2, 2, 1, 2 };
    comp.setRow(row3, &row_emplace_data3);

    // three components
    try testing.expectEqual(comp.len, 3);
    var view = try comp.getComponentIterator(components[0]);
    try testing.expectEqualSlices(u8, &[_]u8{ 4, 3, 6 }, view.next(true).?.data);
    try testing.expectEqualSlices(u8, &[_]u8{ 4, 8, 2 }, view.next(true).?.data);
    try testing.expect(view.done() == false);
    try testing.expectEqualSlices(u8, &[_]u8{ 5, 3, 2 }, view.next(true).?.data);
    try testing.expect(view.done() == true);
    try testing.expect(view.next(true) == null);

    comp.removeRow(row1);
    comp.removeRow(row2);
    try testing.expectEqual(comp.len, 1);
    view = try comp.getComponentIterator(components[0]);
    try testing.expectEqualSlices(u8, &[_]u8{ 5, 3, 2 }, view.next(true).?.data);
    try testing.expect(view.done() == true);
    try testing.expect(view.next(true) == null);

    // std.debug.print("add_remove_iterator: memory usage: {}B\n", .{arena.queryCapacity()});
}

test "zero_size" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var components = [_]Component{
        Component{ .id = 0, .type_size = 0 },
        Component{ .id = 1, .type_size = 0 },
        Component{ .id = 2, .type_size = 0 },
    };

    var comp = try Composition.init(allocator, &components);
    defer comp.deinit(allocator);

    for (0..3) |_| {
        _ = try comp.addRow(allocator);
    }

    var data_0 = comp.data[0][0..comp.capacity];
    var data_1 = comp.data[1][0..comp.capacity];
    var data_2 = comp.data[2][0..comp.capacity];
    try testing.expectEqual(comp.data.len, 3);
    try testing.expectEqual(data_0.len, 0);
    try testing.expectEqual(data_1.len, 0);
    try testing.expectEqual(data_2.len, 0);

    // std.debug.print("zero_size: memory usage: {}B\n", .{arena.queryCapacity()});
}
