const std = @import("std");

const Composition = @import("composition.zig").Composition;

// intended to be created once
// very inefficient
// TODO: Optimise
const ComponentTree = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(Node),
    component_id_count: u32 = 1,
    type_components_registry: std.AutoHashMapUnmanaged(usize, Component),

    const Node = struct {
        component: Component,
        parent_idx: u32,
        archetyped: ?*Composition,
        children: std.ArrayListUnmanaged(u32),
    };

    pub fn init(allocator: std.mem.Allocator) !ComponentTree {
        var self = ComponentTree{
            .allocator = allocator,
            .nodes = std.ArrayListUnmanaged(Node){},
            .type_components_registry = std.AutoHashMapUnmanaged(usize, Component){},
        };
        try self.nodes.append(self.allocator, Node{
            .component = IdComponent,
            .parent_idx = 0,
            .archetyped = null,
            .children = std.ArrayListUnmanaged(u32){},
        });
        return self;
    }

    pub fn deinit(self: *ComponentTree) void {
        self.nodes.deinit(self.allocator);
        self.type_components_registry.deinit(self.allocator);
    }

    pub fn registerTypeComponent(self: *ComponentTree, comptime T: type) !Component {
        const id = typeUnique(T);

        var gop = try self.type_components_registry.getOrPut(self.allocator, id);
        if (!gop.found_existing) {
            gop.value_ptr.* = self.registerComponent(@sizeOf(T));
        }
        return gop.value_ptr.*;
    }

    fn typeUnique(comptime T: type) usize {
        _ = T;
        return @ptrToInt(&struct {
            const x: u32 = 0;
        }.x);
    }

    pub fn registerComponent(self: *ComponentTree, size: u32) Component {
        defer self.component_id_count += 1;
        return Component{
            .id = self.component_id_count,
            .type_size = size,
        };
    }

    fn sortComponents(context: @TypeOf({}), a: Component, b: Component) bool {
        _ = context;
        return a.id < b.id;
    }

    // will allocate
    pub fn buildCompositionPath(
        self: *ComponentTree,
        components: []Component,
        composition: *Composition,
    ) !u32 {
        std.sort.pdq(Component, components, {}, sortComponents);
        // always will be the id node
        var parent_node: *Node = &self.nodes.items[0];
        var parent_node_idx: usize = 0;
        for (components) |component| {
            // iterate through the nodes as much as possible
            var found = false;
            for (parent_node.children.items, 0..) |child_pidx, child_idx| {
                var node: *Node = &self.nodes.items[child_pidx];
                if (node.component.id == component.id) {
                    parent_node_idx = child_idx;
                    parent_node = node;
                    found = true;
                    break;
                }
            }

            // if we didn't find one, create a new node
            if (!found) {
                try self.nodes.append(self.allocator, Node{
                    .component = component,
                    .parent_idx = @intCast(u32, parent_node_idx),
                    .archetyped = null,
                    .children = std.ArrayListUnmanaged(u32){},
                });
                parent_node_idx = self.nodes.items.len - 1;
                try parent_node.children.append(
                    self.allocator,
                    @intCast(u32, parent_node_idx),
                );
                parent_node = &self.nodes.items[parent_node_idx];
            }
        }
        parent_node.archetyped = composition;

        return @intCast(u32, parent_node_idx);
    }

    pub fn followCompositionPath(
        self: *ComponentTree,
        components: []Component,
    ) !?*Composition {
        std.sort.pdq(Component, components, {}, sortComponents);
        var parent_node: *Node = &self.nodes.items[0];
        for (components) |component| {
            var found = false;
            for (parent_node.children.items) |child_pidx| {
                var node: *Node = &self.nodes.items[child_pidx];
                if (node.component.id == component.id) {
                    parent_node = node;
                    found = true;
                    break;
                }
            }
            if (!found) {
                return null;
            }
        }
        return parent_node.archetyped;
    }

    fn _print(self: *ComponentTree, nodes: std.ArrayListUnmanaged(u32), level: u32) void {
        for (nodes.items) |node_idx| {
            var node: Node = self.nodes.items[node_idx];
            for (0..level) |_| {
                std.debug.print("  ", .{});
            }
            const node_post = if (node.archetyped != null) " (archetyped)" else "";
            std.debug.print("node: {}{s}\n", .{ node.component.id, node_post });
            self._print(node.children, level + 1);
        }
    }

    pub fn print(self: *ComponentTree) void {
        std.debug.print("ComponentTree:\n", .{});
        self._print(self.nodes.items[0].children, 0);
    }
};

const EntityId = u32;
const IdComponent = Component{
    .id = 0,
    .type_size = @sizeOf(EntityId),
};

pub const Component = packed struct(u64) {
    id: u32,
    type_size: u32,
};

test "composition_tree" {
    var buffer_a = [_]u8{0} ** 1024;
    var buffer_b = [_]u8{0} ** (1024 * 4);

    var scratch_buffer_a = std.heap.FixedBufferAllocator.init(&buffer_a);
    var scratch_buffer_b = std.heap.FixedBufferAllocator.init(&buffer_b);

    var arena_long = std.heap.ArenaAllocator.init(scratch_buffer_a.allocator());
    var arena_comp = std.heap.ArenaAllocator.init(scratch_buffer_b.allocator());

    var allocator_long = arena_long.allocator();
    var allocator_comp = arena_comp.allocator();

    var tree = try ComponentTree.init(allocator_long);
    defer tree.deinit();

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

    const a_comp = try tree.registerTypeComponent(A);
    const b_comp = try tree.registerTypeComponent(B);
    const c_comp = try tree.registerTypeComponent(C);
    var d_comp = try tree.registerTypeComponent(D);
    d_comp.type_size = 6;

    const ensure_cap = 100;

    // compositions
    var composition_path_a = [_]Component{ a_comp, b_comp };
    var composition_a = try Composition.init(allocator_comp, &composition_path_a);
    try composition_a.ensureCapacity(allocator_comp, ensure_cap);
    _ = try tree.buildCompositionPath(&composition_path_a, &composition_a);
    var composition_path_b = [_]Component{ a_comp, c_comp, b_comp };
    var composition_b = try Composition.init(allocator_comp, &composition_path_b);
    try composition_b.ensureCapacity(allocator_comp, ensure_cap);
    _ = try tree.buildCompositionPath(&composition_path_b, &composition_b);
    var composition_path_c = [_]Component{ a_comp, c_comp, d_comp };
    var composition_c = try Composition.init(allocator_comp, &composition_path_c);
    try composition_c.ensureCapacity(allocator_comp, ensure_cap);
    _ = try tree.buildCompositionPath(&composition_path_c, &composition_c);

    tree.print();

    std.debug.print("composition_tree\n    long: {}B\n    comp: {}B\n", .{
        arena_long.queryCapacity(),
        arena_comp.queryCapacity(),
    });

    // entities
    var data_a = [_]u8{ 1, 1, 0, 0, 1 };
    var a_slot_comp = try tree.followCompositionPath(&composition_path_a);
    var a_row = try a_slot_comp.?.addRow(allocator_comp);
    a_slot_comp.?.setRow(a_row, &data_a);

    var view = try a_slot_comp.?.getComponentIterator(a_comp);
    while (view.next()) |row| {
        std.debug.print("a: {}\n", .{std.mem.bytesAsSlice(A, row.data)[0]});
    }

    std.debug.print("{any}\n", .{composition_c.components[2]});
}
