const std = @import("std");
const testing = std.testing;

const proj_common = @import("../core/common.zig");
const common = @import("common.zig");

const assert = proj_common.assert;
const err = proj_common.err;
const Error = common.Error;
const EntityId = common.EntityId;

const component_registry = @import("component_registry.zig");
const Component = component_registry.Component;

pub const Composition = struct {
    columns: []Column,
    components: []const Component,
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
            .components = components,
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

    pub fn ensureEmpty(self: *Composition, allocator: std.mem.Allocator, extra: u32) !void {
        try self.ensureCapacity(allocator, self.len + extra);
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

    pub fn copyRow(self: *Composition, allocator: std.mem.Allocator, dst: *Composition, row: u32) !u32 {
        try dst.ensureEmpty(allocator, 1);
        var dst_row = try dst.addRow(allocator);
        var data_offset: u32 = 0;
        for (self.columns) |column| {
            const component = column.component;
            var component_buffer = column.data[0 .. self.capacity * component.type_size];
            if (dst.getComponentOrder(component)) |column_idx| {
                var dst_component_buffer = dst.columns[column_idx].data[0 .. dst.capacity * component.type_size];
                @memcpy(
                    dst_component_buffer[(dst_row * component.type_size)..][0..component.type_size],
                    component_buffer[(row * component.type_size)..][0..component.type_size],
                );
            }
            data_offset += component.type_size;
        }
        return dst_row;
    }

    pub fn addRow(self: *Composition, allocator: std.mem.Allocator) !u32 {
        try self.ensureCapacity(allocator, self.len + 1);
        var row = self.len;
        self.len += 1;
        return row;
    }

    // swap removal
    pub fn removeRow(self: *Composition, row: u32) ?u32 {
        self.len -= 1;
        // if this already out of bounds, then we don't need to do anything
        // or, if its a 0 size entity, then we don't need to do anything
        if (self.entity_size == 0 or row >= self.len) {
            return null;
        }
        // swaps with the last row for each component
        for (self.columns) |column| {
            const component = column.component;
            const component_buffer = column.data[0 .. self.capacity * component.type_size];
            @memcpy(
                component_buffer[(row * component.type_size)..][0..component.type_size],
                component_buffer[self.len * component.type_size ..][0..component.type_size],
            );
        }

        return self.len;
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

    pub fn setComponent(
        self: *Composition,
        comptime ComponentType: type,
        component: Component,
        row: u32,
        value: ComponentType,
    ) !void {
        (try self.sliceComponent(
            ComponentType,
            component,
        ))[row] = value;
    }

    pub fn setComponentRaw(
        self: *Composition,
        component: Component,
        row: u32,
        value: []const u8,
    ) !void {
        @memcpy((try self.sliceComponent(
            u8,
            component,
        ))[row * component.type_size ..][0..component.type_size], value);
    }

    pub fn getComponent(
        self: *const Composition,
        comptime ComponentType: type,
        component: Component,
        row: u32,
    ) !*align(1) ComponentType {
        return &(try self.sliceComponent(
            ComponentType,
            component,
        ))[row];
    }

    pub fn getComponentRaw(
        self: *const Composition,
        component: Component,
        row: u32,
    ) ![]align(1) const u8 {
        return (try self.sliceComponent(
            u8,
            component,
        ))[row * component.type_size ..][0..component.type_size];
    }

    pub fn sliceComponent(self: *const Composition, comptime T: type, component: Component) ![]align(1) T {
        return std.mem.bytesAsSlice(T, try self.getComponentBuffer(component));
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
