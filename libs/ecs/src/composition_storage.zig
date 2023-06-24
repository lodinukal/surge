const std = @import("std");

const composition_ns = @import("composition.zig");
const Composition = composition_ns.Composition;

const component_registry = @import("component_registry.zig");
const Component = component_registry.Component;
const id_component = component_registry.id_component;

const common = @import("common.zig");

const assert = common.assert;
const err = common.err;
const Error = common.Error;
const EntityId = common.EntityId;

// intended to be created once and then used for the lifetime of the program
pub const CompositionStorage = struct {
    allocator: std.mem.Allocator,
    map: std.AutoArrayHashMapUnmanaged(u64, ?*Composition),

    component_id_count: u32 = 1,

    const base_slice = [_]Component{id_component};

    pub fn init(allocator: std.mem.Allocator) !CompositionStorage {
        var self = CompositionStorage{
            .allocator = allocator,
            .map = std.AutoArrayHashMapUnmanaged(u64, ?*Composition){},
        };
        _ = try self.addComposition(&base_slice);
        return self;
    }

    pub fn getComponentsHash(components: []const Component) u64 {
        var hash = std.hash.Wyhash.init(0);
        for (components) |component| {
            hash.update(std.mem.asBytes(&component.hash()));
        }
        return hash.final();
    }

    pub fn deinit(self: *CompositionStorage) void {
        var map_iterator = self.map.iterator();
        while (map_iterator.next()) |kv| {
            self.allocator.destroy(kv.value_ptr);
        }
        self.map.deinit(self.allocator);
    }

    // will allocate
    pub fn addComposition(
        self: *CompositionStorage,
        components: []const Component,
    ) !*Composition {
        const ordered_components = try self.allocator.dupe(Component, components);
        const components_hash = CompositionStorage.getComponentsHash(ordered_components);
        self.allocator.destroy(ordered_components);

        var gop = try self.map.getOrPut(self.allocator, components_hash);
        if (gop.found_existing) {
            return gop.value_ptr.*.?;
        } else {
            const composition = try self.allocator.create(Composition);
            const use_slice = try std.mem.concat(
                self.allocator,
                Component,
                &[2][]const Component{ &base_slice, components },
            );
            composition.* = try Composition.init(self.allocator, use_slice);
            gop.value_ptr.* = composition;
            return composition;
        }
    }

    pub fn getComposition(
        self: *const CompositionStorage,
        components: []Component,
    ) !?*Composition {
        const components_hash = CompositionStorage.getComponentsHash(components);

        var gop = try self.map.get(self.allocator, components_hash);
        if (gop.found_existing) {
            return gop.value_ptr;
        } else {
            return null;
        }
    }
};
