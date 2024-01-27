const std = @import("std");

const Tree = @import("Tree.zig");
const Build = @import("project.zig").Build;
const Package = @import("project.zig").Package;
const Context = @import("Context.zig");

const Typechecker = @This();

pub const Error = error{
    SymbolNotFound,
    InvalidCall,
    AlreadyExists,
} || std.mem.Allocator.Error;

pub const Scope = struct {
    pub const Item = struct {
        item: Tree.AnyIndex,
        tree: *Tree,
    };
    parent: ?*Scope = null,
    typechecker: *Typechecker,
    decls: std.StringArrayHashMapUnmanaged(Item) = .{},

    pub fn resolve(self: *Scope, name: []const u8) ?Item {
        var scope: ?*Scope = self;
        while (scope) |has_scope| {
            if (has_scope.decls.get(name)) |found| {
                return found;
            }
            scope = has_scope.parent;
        }
        return null;
    }

    pub fn put(
        self: *Scope,
        allocator: std.mem.Allocator,
        name: []const u8,
        item: Item,
    ) Error!void {
        if (self.resolve(name)) |_| {
            self.typechecker.context.err(
                "Symbol already exists: {s}",
                .{name},
            );
            return error.AlreadyExists;
        }
        try self.decls.put(allocator, name, item);
    }
};

context: *const Context = undefined,
build: *Build = undefined,
global: Scope = undefined,
scope_pool: std.heap.MemoryPool(Scope) = undefined,
current: ?*Scope = null,

pub fn init(
    self: *Typechecker,
    context: *const Context,
    build: *Build,
) !void {
    self.context = context;
    self.build = build;
    self.scope_pool = std.heap.MemoryPool(Scope).init(self.context.allocator);
    self.global = Scope{
        .parent = null,
        .decls = std.StringArrayHashMapUnmanaged(Scope.Item){},
        .typechecker = self,
    };
    self.current = &self.global;
}

pub fn deinit(
    self: *Typechecker,
) void {
    self.scope_pool.deinit();
}

pub fn scanPackageRoot(
    self: *Typechecker,
    package: *const Package,
) !void {
    for (package.trees.items) |*tree| {
        for (tree.statements.items) |statement| {
            try self.scan(&self.global, tree, Tree.AnyIndex.from(statement));
        }
    }
}

fn scan(
    self: *Typechecker,
    scope: *Scope,
    tree: *Tree,
    this: Tree.AnyIndex,
) !void {
    switch (tree.getAny(this).*) {
        .statement => |stmt| {
            switch (stmt) {
                .block => |block| {
                    const this_scope = try self.newScope();
                    self.current = this_scope;
                    const statements = try tree.refToList(block.statements);
                    for (statements) |found_statement| {
                        try self.scan(this_scope, tree, found_statement);
                    }
                    self.current = scope.parent;
                },
                .declaration => |decl| {
                    const rhs_tuple_expression_ref = tree.getExpressionConst(decl.values).tuple.expressions;
                    const rhs_values = try tree.refToList(rhs_tuple_expression_ref);
                    for (try tree.refToList(decl.names), 0..) |name, i| {
                        const contents = tree.getAny(name).identifier.contents;
                        try scope.put(self.context.allocator, contents, .{
                            .item = rhs_values[i],
                            .tree = tree,
                        });
                        std.debug.print("put: {s} {*}\n", .{ contents, tree.getExpressionConst(rhs_values[i].to(Tree.ExpressionIndex)) });
                    }
                    if (decl.type) |ty| {
                        const ty_node = tree.getType(ty);
                        // if (ty_node.derived != .builtin) {
                        switch (ty_node.derived) {
                            .expression => |exp| {
                                try self.scan(scope, tree, Tree.AnyIndex.from(exp.expression));
                            },
                            else => {},
                        }
                        // }
                    }
                },
                .import => |import_statement| {
                    var buf = std.mem.zeroes([512]u8);
                    var fba = std.heap.FixedBufferAllocator.init(&buf);

                    const source = try self.build.resolveFullPathname(
                        fba.allocator(),
                        tree.source.directory,
                        import_statement.collection,
                        import_statement.pathname,
                    );
                    const found_package = self.build.findPackage(source) catch {
                        self.context.err(
                            "Could not find package: {s} ({s})",
                            .{ import_statement.pathname, source },
                        );
                        return error.SymbolNotFound;
                    };
                    const import_scope = if (!import_statement.using)
                        try self.newScope()
                    else
                        scope;
                    for (found_package.trees.items) |*subtree| {
                        for (subtree.statements.items) |sub_stmt| {
                            try self.scan(import_scope, subtree, Tree.AnyIndex.from(sub_stmt));
                        }
                    }
                },
                else => {},
            }
        },
        .expression => |*expr| {
            switch (expr.*) {
                .call => |*call| {
                    try self.resolveCallExpression(scope, tree, call);
                },
                else => {},
            }
        },
        else => {},
    }
}

fn resolveCallExpression(
    self: *Typechecker,
    scope: *Scope,
    tree: *Tree,
    call: *Tree.CallExpression,
) !void {
    const operand = tree.getExpressionConst(call.operand);
    switch (operand.*) {
        .identifier => |id| {
            // we can call these on:
            //    functions
            //    types (parapoly)
            const identifier_content = tree.getIdentifierConst(id.identifier).contents;
            const resolved_item = scope.resolve(identifier_content) orelse {
                self.context.err(
                    "Could not resolve symbol: {s}",
                    .{identifier_content},
                );
                return error.SymbolNotFound;
            };
            const resolved = resolved_item.tree.getAny(resolved_item.item);
            switch (resolved.*) {
                .expression => |expr| {
                    switch (expr) {
                        .procedure, .procedure_group => {
                            std.debug.print("procedure(group) {s}\n", .{identifier_content});
                        },
                        .literal => |lit| {
                            std.debug.print("literal {}\n", .{lit.kind});
                        },
                        .type => |ty| {
                            const type_got = resolved_item.tree.getType(ty.type);
                            if (type_got.poly) {
                                std.debug.print("poly type {}\n", .{type_got.derived});
                            } else {
                                std.debug.print("non-poly type {}\n", .{type_got.derived});
                            }
                        },
                        else => |t| {
                            self.context.err(
                                "Cannot call symbol: {s} ({s})",
                                .{ identifier_content, @tagName(t) },
                            );
                            return error.InvalidCall;
                        },
                    }
                },
                else => {
                    self.context.err(
                        "Cannot call symbol: {s}",
                        .{identifier_content},
                    );
                    return error.InvalidCall;
                },
            }
        },
        .type => |ty| {
            const type_got = tree.getType(ty.type);
            if (type_got.poly) {
                std.debug.print("poly type {}\n", .{type_got.derived});
            } else {
                std.debug.print("non-poly type {}\n", .{type_got.derived});
            }
        },
        else => {
            self.context.err(
                "Cannot call expression: {s}",
                .{@tagName(operand.*)},
            );
            return error.InvalidCall;
        },
    }
}

fn newScope(
    self: *Typechecker,
) !*Scope {
    const scope = try self.scope_pool.create();
    scope.parent = self.current;
    scope.typechecker = self;
    scope.decls = .{};
    return scope;
}
