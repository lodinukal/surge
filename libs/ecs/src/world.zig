const std = @import("std");

const common = @import("common.zig");

const assert = common.assert;
const err = common.err;
const Error = common.Error;
const ScratchSpace = common.ScratchSpace;

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

    // SLOW: DO NOT USE
    pub fn addComponentWithComposition(self: *World, entity: EntityId, comptime T: type, value: T) !void {
        const ref: *EntityReference = try self.getEntityReference(entity);
        const current_composition: *Composition = try self.getCompositionFromIndex(ref.composition_idx);

        // 1. creating new composition
        const add_component = try self.registry.registerTypeComponent(T);
        // from 1 to skip the entity id component
        var scratch = (ScratchSpace(256){}).init();
        var new_components = try std.mem.concat(scratch.allocator(), Component, &[_][]const Component{
            current_composition.components[1..current_composition.components.len],
            &[_]Component{add_component},
        });

        // 2. transfering entity to new composition
        const dst_composition_ref = try self.composition_storage.addRawComposition(
            new_components,
        );
        _ = try self.transferEntity(dst_composition_ref, entity);
        try self.setComponent(entity, T, value);
    }

    // SLOW: DO NOT USE
    pub fn removeComponentWithComposition(self: *World, entity: EntityId, comptime T: type) !void {
        const ref: *EntityReference = try self.getEntityReference(entity);
        const current_composition: *Composition = try self.getCompositionFromIndex(ref.composition_idx);
        const remove_component = try self.registry.registerTypeComponent(T);

        // 1. check
        if (!current_composition.hasComponent(remove_component)) {
            return Error.ComponentNotFound;
        }

        // 2. creating new composition
        var scratch = (ScratchSpace(256){}).init();
        var new_components = scratch.allocator().alloc(Component, current_composition.components.len - 2);
        var idx: u32 = 0;
        // from 1 to skip the entity id component
        for (current_composition.components[1..]) |component| {
            if (component.id != remove_component.id) {
                new_components[idx] = component;
                idx += 1;
            }
        }
        const dst_composition_ref = try self.composition_storage.addRawComposition(
            new_components,
        );

        // 3. transfering entity to new composition
        _ = try self.transferEntity(dst_composition_ref, entity);
    }

    pub fn setComponent(self: *World, entity: EntityId, comptime T: type, value: T) !void {
        const ref: *EntityReference = try self.getEntityReference(entity);
        const self_composition: *Composition = try self.getCompositionFromIndex(ref.composition_idx);

        try self.setComponentByRow(
            ref.row_idx,
            T,
            value,
            self_composition,
        );
    }

    pub fn setComponentRaw(self: *World, entity: EntityId, t_component: Component, value: []const u8) !void {
        const ref: *EntityReference = try self.getEntityReference(entity);
        const self_composition: *Composition = try self.getCompositionFromIndex(ref.composition_idx);

        try World.setComponentByRowRaw(
            ref.row_idx,
            t_component,
            value,
            self_composition,
        );
    }

    fn setComponentByRow(
        self: *World,
        row_idx: u32,
        comptime T: type,
        value: T,
        self_composition: *Composition,
    ) !void {
        const t_component = try self.registry.registerTypeComponent(T);

        try World.setComponentByRowRaw(
            row_idx,
            t_component,
            std.mem.asBytes(&value),
            self_composition,
        );
    }

    fn setComponentByRowRaw(
        row_idx: u32,
        t_component: Component,
        value: []const u8,
        self_composition: *Composition,
    ) !void {
        try self_composition.setComponentRaw(
            t_component,
            row_idx,
            value,
        );
    }

    pub fn transferEntity(self: *World, dst: CompositionStorage.CompositionReference, entity: EntityId) !u32 {
        const entity_ref = try self.getEntityReference(entity);
        const src_composition = try self.getCompositionFromIndex(entity_ref.composition_idx);

        const last_removed = src_composition.removeRow(entity_ref.row_idx);
        if (last_removed) |last| {
            const last_entity = try src_composition.getComponent(
                EntityId,
                id_component,
                last,
            );
            (try self.getEntityReference(last_entity.*)).row_idx = entity_ref.row_idx;
        }

        const dst_composition = dst.composition;
        const dst_row = try src_composition.copyRow(
            self.allocator,
            dst_composition,
            entity_ref.row_idx,
        );
        entity_ref.row_idx = dst_row;
        entity_ref.composition_idx = dst.idx;

        try dst_composition.setComponent(
            EntityId,
            id_component,
            dst_row,
            entity,
        );

        return dst_row;
    }

    pub fn getEntityReference(self: *World, entity: EntityId) !*EntityReference {
        return &self.entities.items[entity];
    }

    fn getCompositionFromIndex(self: *World, composition_idx: u16) !*Composition {
        return self.composition_storage.map.entries.get(composition_idx).value.?;
    }
};

const EntityReference = packed struct(u48) {
    composition_idx: u16,
    row_idx: u32,
};
