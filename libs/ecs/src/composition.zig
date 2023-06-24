const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");

const assert = common.assert;
const err = common.err;
const Error = common.Error;
const EntityId = common.EntityId;

const component_registry = @import("component_registry.zig");
const Component = component_registry.Component;

pub const Composition = struct {
    columns: []Column,
    len: u32 = 0,
    entity_size: u32 = 0,
    capacity: u32 = 0,

    pub const Column = struct {
        component: Component,
        data: [*]u8,

        pub fn order(context: void, a: Component, b: Column) std.math.Order {
            _ = context;
            return Component.order({}, a, b.component);
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        components: []const Component,
    ) !Composition {
        var columns = try allocator.alloc(Column, components.len);
        for (components, 0..) |_, component_idx| {
            columns[component_idx] = Column{
                .component = components[component_idx],
                .data = @ptrCast([*]u8, try allocator.alloc(u8, 0)),
            };
        }
        return Composition{
            .columns = columns,
            .len = 0,
            .entity_size = Composition.getComponentsSize(components),
            .capacity = 0,
        };
    }

    fn getComponentsSize(components: []const Component) u32 {
        var total_entity_size: u32 = 0;
        for (components) |component| {
            total_entity_size += component.type_size;
        }
        return total_entity_size;
    }

    pub fn deinit(self: *Composition, allocator: std.mem.Allocator) void {
        for (self.columns) |column| {
            allocator.free(column.data[0 .. self.capacity * self.entity_size]);
        }
        allocator.free(self.columns);
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
        for (self.columns) |*column| {
            const component = column.component;
            var old_buffer = column.data[0 .. self.capacity * component.type_size];
            var new_buffer = try allocator.alloc(u8, new_capacity * component.type_size);
            @memcpy(new_buffer[0..old_buffer.len], old_buffer);
            allocator.free(old_buffer);
            column.data = @ptrCast([*]u8, new_buffer);
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
        for (self.columns) |column| {
            const component = column.component;
            const component_buffer = column.data[0 .. self.capacity * component.type_size];
            @memcpy(
                component_buffer[row..][0..component.type_size],
                component_buffer[self.len * component.type_size ..][0..component.type_size],
            );
        }
    }

    pub fn getIterator(
        self: *Composition,
        allocator: std.mem.Allocator,
        components: anytype,
    ) !ComponentIterator {
        return try ComponentIterator.init(self, components, allocator);
    }

    pub const ComponentIterator = struct {
        composition: *Composition,
        view_columns: []ViewColumn,
        out_cache: [][]u8,
        idx: usize = 0,

        pub const ViewColumn = struct {
            component: Component,
            data: []u8,
        };

        pub fn init(composition: *Composition, components: anytype, allocator: std.mem.Allocator) !ComponentIterator {
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
            const view_columns = try allocator.alloc(ViewColumn, component_count);

            inline for (0..component_count) |idx| {
                const component = components[idx];
                view_columns[idx] = ViewColumn{
                    .component = component,
                    .data = try composition.getComponentBuffer(components[idx]),
                };
            }

            return ComponentIterator{
                .composition = composition,
                .view_columns = view_columns,
                .out_cache = try allocator.alloc([]u8, component_count),
                .idx = 0,
            };
        }

        pub fn deinit(self: *ComponentIterator, allocator: std.mem.Allocator) void {
            allocator.free(self.out_cache);
            allocator.free(self.view_columns);
        }

        pub fn next(self: *ComponentIterator) ?RowComponents {
            if (self.done()) {
                return null;
            }

            const idx = self.idx;
            self.idx += 1;

            var out = self.out_cache;
            for (self.view_columns, 0..) |*vc, buffer_idx| {
                const component = vc.component;
                out[buffer_idx] = vc.data[(idx * component.type_size)..][0..component.type_size];
            }

            return RowComponents{
                .composition = self.composition,
                .row = idx,
                .components = out,
            };
        }

        pub fn getAccess(
            self: *ComponentIterator,
            comptime T: type,
            component: Component,
        ) !ComponentAccess(T, false) {
            return ComponentAccess(T, false){
                .component_idx = try self.getComponentOrder(component),
            };
        }

        pub fn getConstAccess(
            self: *const ComponentIterator,
            comptime T: type,
            component: Component,
        ) !ComponentAccess(T, true) {
            return ComponentAccess(T, true){
                .component_idx = try self.getComponentOrder(component),
            };
        }

        fn getComponentOrder(
            self: *const ComponentIterator,
            component: Component,
        ) !usize {
            for (self.view_columns, 0..) |vc, idx| {
                if (vc.component.id == component.id) {
                    return idx;
                }
            }
            return Error.ComponentNotFound;
        }

        pub fn done(self: *const ComponentIterator) bool {
            return self.idx >= self.composition.len;
        }
    };

    pub fn setRow(self: *Composition, row: u32, data: []const u8) void {
        var data_offset: u32 = 0;
        for (self.columns) |column| {
            const component = column.component;
            var component_buffer = column.data[0 .. self.capacity * component.type_size];
            @memcpy(
                component_buffer[(row * component.type_size)..][0..component.type_size],
                data[data_offset..][0..component.type_size],
            );
            data_offset += component.type_size;
        }
    }

    pub fn getRow(self: *const Composition, row: usize, output: []u8) void {
        var data_offset: u32 = 0;
        for (self.columns) |column| {
            const component = column.component;
            var component_buffer = column.data[0 .. self.capacity * component.type_size];
            @memcpy(
                output[data_offset..][0..component.type_size],
                component_buffer[(row * component.type_size)..][0..component.type_size],
            );
            data_offset += component.type_size;
        }
    }

    pub fn getComponent(self: *const Composition, row: usize, component: Component) ![]u8 {
        return (try self.getComponentBuffer(component))[row..][0..component.type_size];
    }

    pub fn getComponentBuffer(self: *const Composition, component: Component) ![]u8 {
        if (self.getComponentOrder(component)) |component_idx| {
            return self.columns[component_idx].data[0 .. self.capacity * component.type_size];
        } else {
            return Error.ComponentNotFound;
        }
    }

    pub fn hasComponent(self: *const Composition, component: Component) bool {
        return self.getComponentOrder(component) != null;
    }

    pub fn getComponentOrder(self: *const Composition, component: Component) ?u32 {
        return if (std.sort.binarySearch(
            Column,
            component,
            self.columns,
            {},
            Column.order,
        )) |component_idx| {
            return @intCast(u32, component_idx);
        } else {
            return null;
        };
    }
};

pub const RowComponents = struct {
    composition: *Composition,
    row: usize,
    components: [][]u8,

    pub fn getComponentRaw(self: *const RowComponents, idx: usize) []u8 {
        return self.components[idx];
    }
};

pub fn ComponentAccess(comptime T: type, comptime readonly: bool) type {
    return struct {
        const Self = @This();
        component_idx: usize,

        pub const get = if (readonly) getConst else getMut;

        fn getMut(self: *const Self, view: *const RowComponents) *align(1) T {
            return &std.mem.bytesAsSlice(
                T,
                view.getComponentRaw(self.component_idx),
            )[0];
        }

        fn getConst(self: *const Self, view: *const RowComponents) *align(1) const T {
            return self.getMut(view);
        }
    };
}

pub const access_id = ComponentAccess(EntityId, true){
    .component_idx = 0,
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
    var view = try comp.getIterator(allocator, .{components[0]});
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 4, 3, 6 },
        view.next().?.components[0],
    );
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 4, 8, 2 },
        view.next().?.components[0],
    );
    try testing.expect(view.done() == false);
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 5, 3, 2 },
        view.next().?.components[0],
    );
    try testing.expect(view.done() == true);
    try testing.expect(view.next() == null);

    comp.removeRow(row1);
    comp.removeRow(row2);
    try testing.expectEqual(comp.len, 1);
    view = try comp.getIterator(allocator, .{components[0]});
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 5, 3, 2 },
        view.next().?.components[0],
    );
    try testing.expect(view.done() == true);
    try testing.expect(view.next() == null);

    // std.debug.print("add_remove_iterator: memory usage: {}B\n", .{arena.queryCapacity()});
}
