const std = @import("std");

const composition_ns = @import("composition.zig");
const Composition = composition_ns.Composition;

const component_registry = @import("component_registry.zig");
const ComponentRegistry = component_registry.ComponentRegistry;
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

    pub fn addComposition(
        self: *CompositionStorage,
        registry: *ComponentRegistry,
        components: anytype,
    ) !CompositionReference {
        const translated = try registry.registerTypeComponentTuple(components);
        return try self.addRawComposition(translated);
    }

    pub fn getComposition(
        self: *const CompositionStorage,
        registry: *ComponentRegistry,
        components: anytype,
    ) !?CompositionReference {
        const translated = try registry.registerTypeComponentTuple(components);
        return try self.getRawComposition(translated);
    }

    pub fn addRawComposition(
        self: *CompositionStorage,
        components: []const Component,
    ) !CompositionReference {
        const components_hash = CompositionStorage.getComponentsHash(components);

        var gop = try self.map.getOrPut(self.allocator, components_hash);
        if (gop.found_existing) {} else {
            const composition = try self.allocator.create(Composition);
            const use_slice = try std.mem.concat(
                self.allocator,
                Component,
                &[2][]const Component{ &base_slice, components },
            );
            composition.* = try Composition.init(self.allocator, use_slice);
            gop.value_ptr.* = composition;
        }

        return CompositionReference{
            .hash = components_hash,
            .idx = @intCast(u16, gop.index),
            .composition = gop.value_ptr.*.?,
        };
    }

    pub fn getRawComposition(
        self: *const CompositionStorage,
        components: []Component,
    ) !?CompositionReference {
        const components_hash = CompositionStorage.getComponentsHash(components);

        var gop = try self.map.get(self.allocator, components_hash);
        if (gop.found_existing) {
            return CompositionReference{
                .hash = components_hash,
                .idx = @intCast(u16, self.map.getIndex(components_hash).?),
                .composition = gop.value_ptr,
            };
        } else {
            return null;
        }
    }

    pub const CompositionReference = struct {
        hash: u64,
        idx: u16,
        composition: *Composition,
    };
};
