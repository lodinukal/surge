const std = @import("std");

const Ast = @import("Ast.zig");
const Build = @import("project.zig").Build;
const Package = @import("project.zig").Package;
const Context = @import("Context.zig");

const Ir = @import("Ir.zig");

/// We have to perform a few passes
///  scan:
///  scanPackages: obtain all symbols within the packages (starting from the root package)
///  scanProcs: obtain all symbols within procs
///  scanBlocks: descend procs and obtain all symbols within blocks
///
///  resolveSymbols: we should have all the symbols now, so we can resolve them
///                  (this means we can do things like type specialisation with generics)
///  typeInference: infer the types of the ambiguous expressions
///  typeCheck: check all the types
///  (extraChecks: dsls like the shader language will need extra checks, making sure we use proper )
const Passes = @This();

pub const SourcedAnyIndex = struct {
    ast: *Ast = undefined,
    any_index: Ast.AnyIndex = .none,
};

pub const ScopeIndex = enum(usize) { none = std.math.maxInt(usize), _ };

pub const Scope = struct {
    tag: Tag,
    passes: *Passes,
    index: ScopeIndex,

    /// symbols that are in this scope
    symbols: std.StringArrayHashMapUnmanaged(ScopeSymbol) = .{},
    /// imports can be placed anywhere and are scoped, so we need to keep track of them
    used_imports: std.ArrayListUnmanaged(Using) = .{},
    /// scopes don't change position, so after each pass we can reset this scope_index
    /// and continue from there
    scope_water_level: usize = 0,
    children: std.ArrayListUnmanaged(ScopeIndex) = .{},

    pub const ScopeSymbol = union(enum) {
        package: ScopeIndex,
        symbol: SourcedAnyIndex,
    };

    pub const Using = struct {
        ast: *Ast,
        scope_index: ScopeIndex,
    };

    pub const Tag = union(TagType) {
        package: PackageScope,
        proc: void,
        block: void,
    };

    pub const PackageScope = struct {
        package: *const Package,
    };

    pub const TagType = enum {
        /// can see all symbols no matter the order in the same package
        package,
        /// can see symbols in the parent scope and only symbols that are declared before
        /// the current statement
        proc,
        /// same as proc, but also has variables in the current block and parent blocks
        block,
    };

    pub fn putUsing(self: *Scope, allocator: std.mem.Allocator, using: Using) !void {
        try self.used_imports.append(allocator, using);
    }

    pub fn putSymbol(
        self: *Scope,
        allocator: std.mem.Allocator,
        name: []const u8,
        symbol: ScopeSymbol,
    ) !void {
        try self.symbols.put(allocator, name, symbol);
    }

    pub fn findSymbol(self: Scope, name: []const u8, from: *Ast) ?*ScopeSymbol {
        if (self.symbols.getPtr(name)) |symbol| {
            return symbol;
        }
        for (self.used_imports.items) |used_import_scope_index| {
            const scope = self.passes.getScope(used_import_scope_index.scope_index);
            // `using`s don't propagate across files (a file has its own ast)
            if (used_import_scope_index.ast != from) {
                continue;
            }
            if (scope.findSymbol(name, from)) |symbol| {
                return symbol;
            }
        }
        return null;
    }

    pub fn nextChild(self: *Scope, allocator: std.mem.Allocator, tag: Tag) !ScopeIndex {
        // this might get invalidated if we append to the array
        // so we have to store the id before we append
        const self_index = self.index;
        const passes = self.passes;
        var moving_self = self;
        if (self.children.items.len < self.scope_water_level + 1) {
            const new = try self.passes.newScope(tag);
            // we're invalidated from here on
            moving_self = passes.getScope(self_index);
            try moving_self.children.append(allocator, new);
        }
        moving_self.scope_water_level += 1;
        return moving_self.children.items[moving_self.scope_water_level - 1];
    }

    /// returns the index of the child at the given index
    pub fn getChild(self: *Scope, index: ScopeIndex) ?usize {
        return std.mem.indexOfScalar(ScopeIndex, self.children.items, index);
    }

    pub fn reset(self: *Scope) void {
        self.scope_water_level = 0;
        for (self.children.items) |child| {
            self.passes.getScope(child).reset();
        }
    }

    pub fn deinit(self: *Scope, allocator: std.mem.Allocator) void {
        self.symbols.deinit(allocator);
        self.used_imports.deinit(allocator);
        self.children.deinit(allocator);
        switch (self.tag) {
            .package => {},
            .proc => {},
            .block => {},
        }
    }
};

allocator: std.mem.Allocator,
build: *const Build,
scopes: std.ArrayListUnmanaged(Scope) = .{},

pub fn init(allocator: std.mem.Allocator, build: *const Build) Passes {
    return .{
        .allocator = allocator,
        .build = build,
    };
}

pub fn deinit(self: *Passes) void {
    for (self.scopes.items) |*scope| {
        scope.deinit(self.allocator);
    }
    self.scopes.deinit(self.allocator);
}

pub fn getScope(self: *const Passes, index: ScopeIndex) *Scope {
    return &self.scopes.items[@intFromEnum(index)];
}

pub fn newScope(self: *Passes, tag: Scope.Tag) !ScopeIndex {
    const index: ScopeIndex = @enumFromInt(self.scopes.items.len);
    try self.scopes.append(self.allocator, Scope{
        .passes = self,
        .tag = tag,
        .index = index,
    });
    return index;
}

// passes
pub fn scan(self: *Passes) !void {
    try self.scanPackages();
}

/// this goes through all the packages contained in build and gets any symbols
pub fn scanPackages(self: *Passes) !void {
    for (self.build.project.packages.items) |package| {
        const package_scope_index = try self.newScope(.{
            .package = .{
                .package = &package,
            },
        });
        // std.debug.print("scanning package {s}\n", .{package.pathname});
        try self.scanPackage(package_scope_index);
        const package_scope = self.getScope(package_scope_index);
        package_scope.reset();
    }
}

fn scanPackage(self: *Passes, scope: ScopeIndex) !void {
    // go through all the asts (separate source files)
    for (self.getScope(scope).tag.package.package.asts.items) |*ast| {
        // and get all the top level statements (we only want imports and declarations)
        for (ast.statements.items) |ast_statement_index| {
            switch (ast.getStatementConst(ast_statement_index).*) {
                .import => |import| {
                    if (!import.using) {
                        try self.getScope(scope).putSymbol(self.allocator, import.name, .{
                            .package = scope,
                        });
                        // std.debug.print("   put package {s}\n", .{import.name});
                    } else {
                        try self.getScope(scope).putUsing(self.allocator, .{
                            .ast = ast,
                            .scope_index = scope,
                        });
                        // std.debug.print("   put using {s}\n", .{import.name});
                    }
                },
                .declaration => |declaration| {
                    const rhs_tuple_expression_ref = ast.getExpressionConst(
                        declaration.values,
                    ).tuple.expressions;
                    const rhs_values = try ast.refToList(rhs_tuple_expression_ref);
                    const lhs_values = try ast.refToList(declaration.names);
                    for (lhs_values, rhs_values) |ast_name_index, ast_value_index| {
                        const declaration_name = ast.getIdentifierConst(
                            ast_name_index.to(Ast.IdentifierIndex),
                        ).*.contents;
                        try self.getScope(scope).putSymbol(self.allocator, declaration_name, .{
                            .symbol = .{
                                .ast = ast,
                                .any_index = ast_value_index,
                            },
                        });
                        switch (ast.getAny(ast_value_index).expression) {
                            .procedure => |procedure_expression| {
                                try self.scanProcedure(scope, ast, procedure_expression);
                            },
                            else => {},
                        }
                        // std.debug.print("   put symbol {s} as {s}\n", .{
                        //     declaration_name,
                        //     @tagName(ast.getAny(ast_value_index).expression),
                        // });
                    }
                },
                else => {
                    // we deal with everything else in later passes
                },
            }
        }
    }
}

fn scanProcedure(
    self: *Passes,
    scope: ScopeIndex,
    ast: *Ast,
    procedure_expression: Ast.ProcedureExpression,
) !void {
    const procedure_scope_index = try self.getScope(scope).nextChild(self.allocator, .proc);

    // foreign procedures
    if (procedure_expression.body) |ast_procedure_body_index| {
        // we only add it to the scope if it has a body,
        // otherwise it's just a declaration (meaning it wont spread symbols)
        // a proc would need the symbols from the type

        const procedure_type_expression = ast.getTypeConst(procedure_expression.type).*;
        const ast_procedure_type = procedure_type_expression.derived.procedure;

        const ast_params_any_index_list = try ast.refToList(ast_procedure_type.params);
        const ast_results_any_index_list = try ast.refToList(ast_procedure_type.results);

        for (ast_params_any_index_list) |ast_param_any_index| {
            const field = ast.getAny(ast_param_any_index).field;
            if (field.name) |ast_field_name_identifier_index| {
                const field_name = ast.getIdentifierConst(
                    ast_field_name_identifier_index,
                ).*.contents;
                try self.getScope(procedure_scope_index).putSymbol(self.allocator, field_name, .{
                    .symbol = .{
                        .ast = ast,
                        .any_index = ast_param_any_index,
                    },
                });
            }
        }

        for (ast_results_any_index_list) |ast_result_any_index| {
            _ = ast_result_any_index; // autofix

        }

        const ast_procedure_body = ast.getStatementConst(ast_procedure_body_index);
        try self.scanBlock(procedure_scope_index, ast, ast_procedure_body.block);
    }
}

/// puts it into the current scope
fn scanBlock(
    self: *Passes,
    scope: ScopeIndex,
    ast: *Ast,
    block: Ast.BlockStatement,
) !void {
    _ = self; // autofix
    _ = scope; // autofix
    _ = ast; // autofix
    _ = block; // autofix
}
