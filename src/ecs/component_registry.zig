const std = @import("std");

const proj_common = @import("../core/common.zig");
const common = @import("common.zig");

const assert = proj_common.assert;
const err = proj_common.err;

const Error = common.Error;

pub const ComponentRegistry = struct {
    allocator: std.mem.Allocator,
    component_id_count: u32 = 1,
    type_components_registry: std.AutoHashMapUnmanaged(usize, Component),

    pub fn init(allocator: std.mem.Allocator) ComponentRegistry {
        return ComponentRegistry{
            .allocator = allocator,
            .type_components_registry = std.AutoHashMapUnmanaged(usize, Component){},
        };
    }

    pub fn deinit(self: *ComponentRegistry) void {
        self.type_components_registry.deinit(self.allocator);
    }

    pub fn registerTypeComponentTuple(self: *ComponentRegistry, comptime components: anytype) ![]Component {
        const Components = comptime @TypeOf(components);
        const component_count = comptime @typeInfo(Components).Struct.fields.len;
        var components_return = try self.allocator.alloc(Component, component_count);

        inline for (components, 0..) |ComponentType, component_idx| {
            components_return[component_idx] = try self.registerTypeComponent(ComponentType);
        }

        return components_return;
    }

    pub fn registerTypeComponent(self: *ComponentRegistry, comptime T: type) !Component {
        const id = typeUnique(T);

        var gop = try self.type_components_registry.getOrPut(self.allocator, id);
        if (!gop.found_existing) {
            gop.value_ptr.* = self.registerComponent(@sizeOf(T));
        }
        return gop.value_ptr.*;
    }

    fn typeUnique(comptime T: type) usize {
        _ = T;
        return @intFromPtr(&struct {
            const x: u32 = 0;
        }.x);
    }

    pub fn registerComponent(self: *ComponentRegistry, size: u32) Component {
        defer self.component_id_count += 1;
        return Component{
            .id = self.component_id_count,
            .type_size = size,
        };
    }
};

pub const id_component = Component{
    .id = 0,
    .type_size = @sizeOf(common.EntityId),
};

pub const Component = packed struct(u64) {
    id: u32,
    type_size: u32,

    pub fn hash(self: Component) u64 {
        return self.id;
    }

    pub fn order(context: void, a: Component, b: Component) std.math.Order {
        _ = context;
        if (a.id < b.id) {
            return .lt;
        } else if (a.id > b.id) {
            return .gt;
        } else {
            return .eq;
        }
    }

    pub fn lessThan(context: void, a: Component, b: Component) bool {
        _ = context;
        return a.id < b.id;
    }
};
