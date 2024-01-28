const std = @import("std");

const Ast = @import("Ast.zig");
const Build = @import("project.zig").Build;
const Package = @import("project.zig").Package;
const Context = @import("Context.zig");

const Ir = @import("Ir.zig");

const Scanner = @This();

pub const Error = error{
    NotFound,
    InvalidCall,
    AlreadyExists,
    Invalid,
    InvalidFieldAccess,
    InvalidArrowAccess,
    InvalidIndexAccess,
    InvalidDeref,
    InvalidUnwrap,
    Skip,
} || std.mem.Allocator.Error;

pub const Scope = struct {
    pub const Item = union(enum) {
        /// used for the declarations within a package
        item: struct {
            index: Ast.AnyIndex,
            ast: *Ast,
        },
        /// used for the package namespaces
        package_scope: *Scope,
    };
    parent: ?*Scope = null,
    child_index: ?usize = null,
    children: std.ArrayListUnmanaged(*Scope) = .{},
    scanner: *Scanner,
    decls: std.StringArrayHashMapUnmanaged(Item) = .{},
    using_scopes: std.ArrayListUnmanaged(*Scope) = .{},
    count: usize = 0,

    pub fn resolve(self: *Scope, name: []const u8) ?Item {
        var scope: ?*Scope = self;
        while (scope) |has_scope| {
            if (has_scope.decls.get(name)) |found| {
                return found;
            }
            for (has_scope.using_scopes.items) |using_scope| {
                if (using_scope.resolve(name)) |found| {
                    return found;
                }
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
            self.scanner.context.err(
                "Symbol already exists: {s}",
                .{name},
            );
            return error.AlreadyExists;
        }
        try self.decls.put(allocator, name, item);
    }

    pub fn childScope(
        self: *Scope,
        index: usize,
    ) !*Scope {
        if (self.children.items.len > index) {
            return self.children.items[index];
        }
        const new = try self.scanner.newScope(false);
        new.parent = self;
        new.child_index = index;
        try self.children.insert(self.scanner.context.allocator, index, new);
        return new;
    }

    pub fn nextChildScope(
        self: *Scope,
    ) !*Scope {
        const ret = try self.childScope(self.count);
        self.count += 1;
        return ret;
    }

    pub fn reset(
        self: *Scope,
    ) void {
        self.count = 0;
        for (self.children.items) |child| {
            child.reset();
        }
    }

    pub fn log(
        self: *const Scope,
        comptime msg: []const u8,
        args: anytype,
    ) void {
        var indent: usize = 0;
        var scope: ?*const Scope = self;
        while (scope) |has_scope| {
            indent += 1;
            scope = has_scope.parent;
            std.debug.print(" ->", .{});
        }
        std.debug.print(msg, args);
    }
};

context: *const Context = undefined,
build: *Build = undefined,
ir: Ir = undefined,
/// we can have many unresolved items for a single name
scope_pool: std.heap.MemoryPoolExtra(Scope, .{}) = undefined,
package_scopes: std.StringHashMapUnmanaged(*Scope) = .{},
// specialisations: std.AutoHashMapUnmanaged(Ast.Type) = .{},
current: ?*Scope = null,
pass: Pass = .gather_types,

pub const Pass = enum {
    gather_types,
    check_types,
};

pub fn init(
    self: *Scanner,
    context: *const Context,
    build: *Build,
) !void {
    self.context = context;
    self.build = build;
    self.scope_pool = std.heap.MemoryPool(Scope).init(self.context.allocator);
    self.current = null;
}

pub fn deinit(
    self: *Scanner,
) void {
    self.scope_pool.deinit();
    self.package_scopes.deinit(self.context.allocator);
}

pub fn scanRoot(
    self: *Scanner,
) !void {
    if (self.build.project.packages.items.len < 1) return;
    const first_package = self.build.project.packages.items[0];
    try self.scanPackageRoot(first_package.pathname, &first_package, false);
}

fn scanPackageRoot(
    self: *Scanner,
    name: []const u8,
    package: *const Package,
    using: bool,
) !void {
    const old_current = self.current;
    const import_scope = try self.newScope(true);
    if (old_current) |old| {
        if (using) {
            try old.using_scopes.append(self.context.allocator, import_scope);
        } else {
            try old.put(self.context.allocator, name, .{
                .package_scope = import_scope,
            });
        }
    }
    try self.package_scopes.put(self.context.allocator, name, import_scope);
    self.current = import_scope;
    for (package.asts.items) |*ast| {
        for (ast.statements.items) |statement| {
            try self.scan(self.current.?, ast, Ast.AnyIndex.from(statement));
        }
    }
    self.current.?.reset();
    self.current = old_current;
}

fn scan(
    self: *Scanner,
    scope: *Scope,
    ast: *Ast,
    this: Ast.AnyIndex,
) Error!void {
    switch (ast.getAny(this).*) {
        .statement => |stmt| {
            switch (stmt) {
                .block => |block| {
                    const this_scope = try scope.nextChildScope();
                    self.current = this_scope;
                    const statements = try ast.refToList(block.statements);
                    for (statements) |found_statement| {
                        try self.scan(this_scope, ast, found_statement);
                    }
                    this_scope.reset();
                    self.current = scope.parent;
                },
                .declaration => |decl| try self.resolveDeclarationStatement(scope, ast, decl),
                .import => |import_statement| try self.resolveImportStatement(ast, import_statement),
                else => |x| {
                    std.debug.panic("scan: {s}\n", .{@tagName(x)});
                },
            }
        },
        .expression => |expr| switch (expr) {
            .type => |ty_expr| {
                const got_ty = ast.getTypeConst(ty_expr.type).*;
                switch (got_ty.derived) {
                    inline .@"enum", .@"struct", .@"union" => |e| {
                        @compileLog(@TypeOf(e));
                    },
                    .pointer => |pointer| {
                        const pointer_ty = ast.getTypeConst(pointer.type).*;
                        if (pointer_ty.derived == .expression) {
                            scope.resolve()
                        }
                    },
                }
                std.debug.panic("scan: {s}\n", .{@tagName(got_ty.derived)});
            },
            else => |x| {
                std.debug.panic("scan: {s}\n", .{@tagName(x)});
            },
        },
        else => |x| {
            std.debug.panic("scan: {s}\n", .{@tagName(x)});
        },
    }
    scope.log("break statement :)\n", .{});
}

fn resolveDeclarationStatement(
    self: *Scanner,
    scope: *Scope,
    ast: *Ast,
    decl: Ast.DeclarationStatement,
) !void {
    const rhs_tuple_expression_ref = ast.getExpressionConst(decl.values).tuple.expressions;
    const rhs_values = try ast.refToList(rhs_tuple_expression_ref);
    for (try ast.refToList(decl.names), 0..) |name, i| {
        const contents = ast.getAny(name).identifier.contents;
        try scope.put(self.context.allocator, contents, .{
            .item = .{
                .ast = ast,
                .index = rhs_values[i],
            },
        });
        scope.log("put: {s} {*}\n", .{
            contents,
            ast.getExpressionConst(rhs_values[i].to(Ast.ExpressionIndex)),
        });
        try self.scan(scope, ast, rhs_values[i]);
        // std.debug.print("put: {s} {*}\n", .{ contents, ast.getExpressionConst(rhs_values[i].to(Ast.ExpressionIndex)) });
        // try self.scan(scope, ast, rhs_values[i]);
        // try self.resolveExpression(
        //     scope,
        //     ast,
        //     ast.getExpressionConst(rhs_values[i].to(Ast.ExpressionIndex)).*,
        //     null,
        // );
    }
    if (decl.type) |ty| {
        _ = ty; // autofix
        // if (ty_node.derived != .builtin) {
        // const resolved_ty = (try scope.resolveExpressionType(ast, ast.getType(ty).*)).?;
        // scope.log("decl type {}\n", .{resolved_ty});
        // }
    }
}

fn resolveImportStatement(
    self: *Scanner,
    ast: *Ast,
    import: Ast.ImportStatement,
) !void {
    const source = try self.build.resolveFullPathname(
        self.context.allocator,
        ast.source.directory,
        import.collection,
        import.pathname,
    );
    const found_package = self.build.findPackage(source) catch {
        self.context.err(
            "Could not find package: {s} ({s})",
            .{ import.pathname, source },
        );
        return error.NotFound;
    };
    try self.scanPackageRoot(source, found_package, import.using);
}

fn newScope(
    self: *Scanner,
    skip_parent: bool,
) !*Scope {
    const scope = try self.scope_pool.create();
    scope.* = .{
        .parent = if (skip_parent) null else self.current,
        .scanner = self,
        .decls = .{},
        .using_scopes = .{},
    };
    return scope;
}

/// call after everything has been scanned
pub fn putIr(self: *Scanner, ir: *Ir) !void {
    var it = self.package_scopes.iterator();
    while (it.next()) |package| {
        const name = package.key_ptr.*;
        std.debug.print("package: {s}\n", .{name});

        const package_scope = try ir.putPackageScope();
        const package_scope_node = &ir.get(package_scope).tag.package_scope;
        _ = package_scope_node; // autofix

        var decl_iterator = package.value_ptr.*.decls.iterator();
        while (decl_iterator.next()) |decl| {
            const decl_name = decl.key_ptr.*;

            switch (decl.value_ptr.*) {
                .item => |index| {
                    const ast = index.ast;
                    const item = ast.getAny(index.index);
                    // try package_scope_node.put(
                    //     self.context.allocator,
                    // );
                    std.debug.print("got {s}: {s}\n", .{ decl_name, @tagName(item.*.expression) });
                },
                else => {},
            }
        }
    }
}
