const std = @import("std");

const common = @import("common.zig");

const assert = common.assert;
const err = common.err;
const Error = common.Error;

const component_registry = @import("component_registry.zig");
const composition_storage = @import("composition_storage.zig");
const composition = @import("composition.zig");

const EntityId = common.EntityId;
const ComponentRegistry = component_registry.ComponentRegistry;
const Component = component_registry.Component;
const id_component = component_registry.id_component;
const CompositionStorage = composition_storage.CompositionStorage;
const Composition = composition.Composition;

pub const World = struct {
    allocator: std.mem.Allocator,
    registry: ComponentRegistry,
    composition_storage: CompositionStorage,
    entities: std.ArrayListUnmanaged(EntityReference),

    const base_slice = [_]Component{id_component};

    pub fn init(allocator: std.mem.Allocator) !World {
        var self = World{
            .allocator = allocator,
            .registry = ComponentRegistry.init(allocator),
            .composition_storage = try CompositionStorage.init(allocator),
            .entities = std.ArrayListUnmanaged(EntityReference){},
        };
        _ = try self.addRawComposition(&[_]Component{});
        return self;
    }

    pub fn deinit(self: *World) void {
        self.registry.deinit();
        self.composition_storage.deinit();
        self.entities.deinit(self.allocator);
    }

    // registry functions
    pub inline fn registerTypeComponentTuple(
        self: *World,
        comptime components: anytype,
    ) ![]Component {
        try self.registry.registerTypeComponentTuple(type, components);
    }

    pub inline fn registerTypeComponent(self: *World, comptime T: type) !Component {
        return try self.registry.registerTypeComponent(T);
    }

    pub inline fn registerComponent(self: *World, size: u32) Component {
        return self.registry.registerComponent(size);
    }

    // storage functions
    pub inline fn addComposition(
        self: *World,
        comptime components: anytype,
    ) !CompositionStorage.CompositionReference {
        return try self.composition_storage.addComposition(
            &self.registry,
            components,
        );
    }

    pub inline fn getComposition(
        self: *World,
        comptime components: anytype,
    ) !?CompositionStorage.CompositionReference {
        return try self.composition_storage.getComposition(
            &self.registry,
            components,
        );
    }

    pub inline fn addRawComposition(
        self: *World,
        components: []const Component,
    ) !CompositionStorage.CompositionReference {
        return try self.composition_storage.addRawComposition(components);
    }

    pub inline fn getRawComposition(
        self: *World,
        components: []const Component,
    ) !?CompositionStorage.CompositionReference {
        return try self.composition_storage.getRawComposition(components);
    }

    // composition functions
    pub fn addEntity(self: *World) !EntityId {
        return (try self.addManyEntities(1))[0];
    }

    pub fn addManyEntities(self: *World, comptime count: u32) ![count]EntityId {
        const null_composition: *Composition = try self.getCompositionFromIndex(0);

        var result = [_]u32{0} ** count;

        var entity_id = self.entities.items.len;
        try null_composition.ensureEmpty(self.allocator, count);
        inline for (0..count) |idx| {
            const row_idx = try null_composition.addRow(self.allocator);

            const ref = try self.entities.addOne(self.allocator);
            ref.composition_idx = 0;
            ref.row_idx = row_idx;

            const eid = @intCast(EntityId, entity_id);
            result[idx] = eid;

            try null_composition.setComponent(EntityId, id_component, row_idx, eid);
            entity_id += 1;
        }

        return result;
    }

    // TODO: Abstract this logic into a `transferEntity` function to open avenues for optimization

    pub fn setComponent(self: *World, entity: EntityId, comptime ComponentType: type, value: ComponentType) !void {
        const ref: *EntityReference = &self.entities.items[entity];
        const current_composition: *Composition = try self.getCompositionFromIndex(ref.composition_idx);

        const last_removed = current_composition.removeRow(ref.row_idx);
        if (last_removed) |last| {
            const last_entity_index = (try current_composition.sliceComponent(
                EntityId,
                id_component,
            ))[last];
            self.entities.items[last_entity_index].row_idx = ref.row_idx;
        }

        var scratch = [_]u8{0} ** 256;
        var fba = std.heap.FixedBufferAllocator.init(&scratch);
        const scratch_alloc = fba.allocator();
        const add_component = try self.registry.registerTypeComponent(ComponentType);
        // from 1 to skip the entity id component
        var new_components = try std.mem.concat(scratch_alloc, Component, &[_][]const Component{
            current_composition.components[1..current_composition.components.len],
            &[_]Component{add_component},
        });

        const next_composition_ref = try self.composition_storage.addRawComposition(
            new_components,
        );
        const next_composition = next_composition_ref.composition;
        const next_row = try current_composition.copyRow(
            self.allocator,
            next_composition,
            ref.row_idx,
        );
        ref.row_idx = next_row;
        ref.composition_idx = next_composition_ref.idx;

        try next_composition.setComponent(
            EntityId,
            id_component,
            next_row,
            entity,
        );

        try next_composition.setComponent(
            ComponentType,
            add_component,
            next_row,
            value,
        );
    }

    pub fn removeComponent(self: *World, entity: EntityId, comptime ComponentType: type) !void {
        const ref: *EntityReference = &self.entities.items[entity];
        const current_composition: *Composition = try self.getCompositionFromIndex(ref.composition_idx);

        const last_removed = current_composition.removeRow(ref.row_idx);
        if (last_removed) |last| {
            const last_entity_index = (try current_composition.sliceComponent(
                EntityId,
                id_component,
            ))[last];
            self.entities.items[last_entity_index].row_idx = ref.row_idx;
        }

        var scratch = [_]u8{0} ** 256;
        var fba = std.heap.FixedBufferAllocator.init(&scratch);
        const scratch_alloc = fba.allocator();
        const remove_component = try self.registry.registerTypeComponent(ComponentType);
        // from 1 to skip the entity id component
        var new_components = try scratch_alloc.alloc(Component, current_composition.components.len - 1);
        var idx: u32 = 0;
        for (current_composition.components) |component| {
            if (component.id != remove_component.id) {
                new_components[idx] = component;
                idx += 1;
            }
        }

        const next_composition_ref = try self.composition_storage.addRawComposition(
            new_components,
        );
        const next_composition = next_composition_ref.composition;
        const next_row = try current_composition.copyRow(
            self.allocator,
            next_composition,
            ref.row_idx,
        );
        ref.row_idx = next_row;
        ref.composition_idx = next_composition_ref.idx;

        try next_composition.setComponent(
            EntityId,
            id_component,
            next_row,
            entity,
        );
    }

    fn getCompositionFromIndex(self: *World, composition_idx: u16) !*Composition {
        return self.composition_storage.map.entries.get(composition_idx).value.?;
    }
};

const EntityReference = packed struct(u48) {
    composition_idx: u16,
    row_idx: u32,
};
