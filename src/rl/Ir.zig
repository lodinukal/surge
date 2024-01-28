const std = @import("std");
const lexemes = @import("lexemes.zig");
const lexer = @import("lexer.zig");

const Ast = @import("Ast.zig");

const Ir = @This();

pub const Error = error{};

pub const SourceTrackedLocation = struct {
    loc: lexer.Location = .{},
    source: []const u8 = "<none>",
};

pub const NodeIndex = enum(usize) { none = std.math.maxInt(usize), _ };

pub const Node = struct {
    start: SourceTrackedLocation,
    end: SourceTrackedLocation,
    tag: union(enum) {
        identifier: Identifier,
        expression: Expression,

        package_scope: PackageScope,
        block: Block,
        declaration: Declaration,
        // this is a procedure that is not bound to an identifier (just yet)
        anon_procedure: AnonymousProcedure,
        call: Call,
        field_access: Selector,
        ty: Type,
    },

    pub const Tag = enum {
        identifier,
        expression,

        package_scope,
        block,
        declaration,
        anon_procedure,
        call,
        field_access,
        ty,
    };

    pub inline fn string(n: Node) error{DifferentSources}![]const u8 {
        if (!std.mem.eql(u8, n.start.source, n.end.source)) {
            return error.DifferentSources;
        }
        return n.start.source[n.start.loc.offset..n.end.loc.offset];
    }

    /// Identifiers point to something
    pub const Identifier = NodeIndex;

    pub const Expression = struct {
        underlying: NodeIndex, // underlying node
        resolved_ty: ?NodeIndex, // should point to a resolved type node (once resolved)

        pub fn resolve(e: *Expression, i: *Ir) !*Expression {
            var buf = std.mem.zeroes([512]u8);
            var fba = std.heap.FixedBufferAllocator.init(&buf);

            var visited = std.AutoArrayHashMapUnmanaged(NodeIndex, void){};
            while (e.underlying.tag == .expression) {
                e.underlying = i.get(e.underlying).tag.expression.underlying;
                if (visited.get(e.underlying) != null) {
                    return error.CircularDependency;
                }
                visited.put(fba.allocator(), e.underlying, {});
            }
            if (e.resolved_ty != null) return e;
            const resolved = try i.get(e.underlying).resolve();
            const resolved_ty = try resolved.getType(i);
            e.resolved_ty = resolved_ty;
            return e;
        }
    };

    pub const PackageScope = std.StringArrayHashMapUnmanaged(NodeIndex);

    pub const Block = struct {
        statements: []NodeIndex,
        /// this is the node that this block evaluates to, if any
        /// used for x := { /*code*/ } expressions
        /// evals_to should be the declaration lhs
        evals_to: ?NodeIndex,

        pub fn resolve(b: *Block, i: *Ir) !*Block {
            for (b.statements) |stmt| {
                const resolved = try i.get(stmt).resolve();
                _ = try resolved.expectStatement();
            }
            return true;
        }
    };

    pub const Declaration = struct {
        // i1, i1, ..., iN : T (:|=) expr1, expr2, ... exprN;
        // following should be the same length
        lhs: []NodeIndex, // lhs identifiers
        rhs: []NodeIndex, // rhs expressions
        is_const: bool, // is this a const declaration?
        types: []?NodeIndex, // should point to a resolved type node (once resolved)
        resolved: bool = false,

        pub fn resolve(d: *Declaration, i: *Ir) !*Declaration {
            if (d.resolved) return d;
            var buf = std.mem.zeroes([512]u8);
            var fba = std.heap.FixedBufferAllocator.init(&buf);

            // we need this because a single rhs expression can have multiple
            // lhs identifiers, i.e x, y := get_pos();
            var computed_rhs = std.ArrayListUnmanaged(NodeIndex){};

            for (d.rhs) |rhs| {
                const got_rhs = try i.get(rhs).resolve();
                const got_rhs_ty = i.get(try got_rhs.getType());
                switch (got_rhs_ty.tag) {
                    .call => |call| {
                        _ = try call.resolve(i);
                        for (call.returns) |ret| {
                            computed_rhs.append(fba.allocator(), ret) catch
                                unreachable;
                        }
                    },
                    else => {
                        computed_rhs.append(fba.allocator(), rhs) catch
                            unreachable;
                    },
                }
            }

            if (computed_rhs.items.len < d.lhs.len) {
                return error.MismatchedDeclaration;
            }

            for (0..d.lhs.len) |index| {
                const rhs = computed_rhs.items[index];
                const lhs = d.lhs[index];
                const got_lhs = try i.get(lhs).resolve();
                const got_rhs = try i.get(rhs).resolve();

                const got_lhs_ty = try got_lhs.getType(i);
                const got_rhs_ty = try got_rhs.getType(i);

                // TODO: type check lhs and rhs
                std.debug.panic("TODO: type check lhs and rhs, {} {}", .{ got_lhs_ty, got_rhs_ty });
            }
        }

        pub fn getType(d: *Declaration, i: *Ir) !NodeIndex {
            if (d.ty) |ty| {
                return ty;
            }
            if (d.rhs.len == 0) {
                return error.MissingType;
            }
            return i.get(d.rhs[0]).getType(i);
        }
    };

    pub const AnonymousProcedure = struct {
        // proc (i1: T1, i2: T2, ... iN: TN) -> T { ... }
        // following should be the same length
        ty: NodeIndex, // type of procedure
        body: NodeIndex, // body of procedure

        pub fn resolve(ap: *AnonymousProcedure, i: *Ir) !*AnonymousProcedure {
            _ = try i.get(ap.ty).resolve();
            _ = try i.get(ap.body).resolve();
            return ap;
        }
    };

    pub const Call = struct {
        callee: NodeIndex, // callee
        args: []NodeIndex, // arguments
        returns: []NodeIndex, // return values

        pub fn resolve(c: *Call, i: *Ir) !*Call {
            _ = try i.get(c.callee).resolve();
            for (c.args) |arg|
                _ = try i.get(arg).resolve();
            for (c.returns) |ret|
                _ = try i.get(ret).resolve();
            return c;
        }
    };

    pub const Selector = struct {
        operand: NodeIndex, // operand
        field: []const u8, // field name

        pub fn resolve(fa: *Selector, i: *Ir) !*Selector {
            _ = fa; // autofix
            _ = i; // autofix
        }
    };

    pub const Type = union(TypeTag) {
        pub const TypeTag = enum {
            typeid,

            identifier,
            expression,

            builtin,
            structure,
            pointer,
            slice,
            array,
            procedure,
            @"union",
            enumeration,
        };
        typeid,
        identifier: Identifier,
        /// could be a type specialisation
        /// we need to resolve this to a type
        expression: NodeIndex,

        builtin: Ast.BuiltinType,
        structure: Structure,
        pointer: Pointer,
        slice: Slice,
        array: Array,
        procedure: Procedure,
        @"union": Union,
        enumeration: Enumeration,

        pub const Structure = struct {
            params: []Field, // type parameters
            fields: []Field,

            pub fn resolve(s: *Structure, i: *Ir) !*Structure {
                for (s.fields) |field| {
                    try i.get(field.ty.?).resolve(i);
                    if (field.value) |v| try i.get(v).resolve(i);
                }
                return s;
            }
        };

        pub const Pointer = struct {
            to: NodeIndex, // make sure this is resolved

            pub fn resolve(p: *Pointer, i: *Ir) !*Pointer {
                try i.get(p.to).resolve(i);
                return p;
            }
        };

        pub const Slice = struct {
            of: NodeIndex, // make sure this is resolved

            pub fn resolve(s: *Slice, i: *Ir) !*Slice {
                try i.get(s.of).resolve(i);
                return s;
            }
        };

        pub const Array = struct {
            of: NodeIndex, // make sure this is resolved
            size: NodeIndex, // make sure this is resolved

            pub fn resolve(a: *Array, i: *Ir) *Array {
                try i.get(a.of).resolve(i);
                const size = try i.get(a.size).resolve(i);
                _ = size;
                // TODO: check if the index is a constant
                // TODO: check if the index is an integer
                // TODO: check if the index is positive
                return a;
            }
        };

        pub const Procedure = struct {
            param_types: []Field, // make sure these are resolved
            return_types: []Field, // make sure these are resolved

            pub fn resolve(p: *Procedure, i: *Ir) !*Procedure {
                for (p.param_types) |param_type| {
                    try i.get(param_type).resolve(i);
                }
                for (p.return_types) |return_type| {
                    try i.get(return_type).resolve(i);
                }
                return true;
            }
        };

        pub const Union = struct {
            params: []Field, // type parameters
            variants: []Field,

            pub fn resolve(u: *Union, i: *Ir) *Union {
                for (u.variants) |variant| {
                    try i.get(variant.ty.?).resolve(i);
                    // TODO: don't let union variants have default values
                }
                return u;
            }
        };

        pub const Enumeration = struct {
            backing: ?NodeIndex, // make sure this is resolved
            fields: []Field,
            resolved: bool = false,

            pub fn resolve(e: *Enumeration, i: *Ir) !*Enumeration {
                if (e.resolved) return e;
                for (e.fields) |field| {
                    if (field.ty != null) {
                        // shouldn't be here
                        return error.InvalidEnumeration;
                    }
                    if (field.value != null) {
                        try i.get(field.value).resolve(i);
                    }
                }
                if (e.backing) {
                    if (i.get(e.backing).resolve()) return false;
                } else {
                    // TODO: get a backing type from the fields
                }
            }
        };

        pub const Field = struct {
            name: NodeIndex,
            ty: ?NodeIndex, // should point to a resolved type node (once resolved)
            value: ?NodeIndex, // should point to a resolved expression node (once resolved)
        };

        pub inline fn resolve(t: *Type, i: *Ir) !*Type {
            switch (t.*) {
                .identifier => {
                    return error.Expected;
                },
                .expression => |e| _ = try i.get(e).resolve(i),

                .builtin => {},
                .structure => |s| _ = try s.resolve(i),
                .pointer => |p| _ = try p.resolve(i),
                .slice => |s| _ = try s.resolve(i),
                .array => |a| _ = try a.resolve(i),
                .procedure => |p| _ = try p.resolve(i),
                .@"union" => |u| _ = try u.resolve(i),
                .enumeration => |e| _ = try e.resolve(i),
            }
            return t;
        }
    };

    pub inline fn resolve(n: *Node, i: *Ir) !*Node {
        return switch (n.tag) {
            .expression => |e| e.resolve(i),
            .declaration => |d| d.resolve(i),
            .anon_procedure => |ap| ap.resolve(i),
            .ty => |t| t.resolve(i),
            else => return error.Expected,
        };
    }

    pub fn expectStatement(n: *Node) !*Node {
        return switch (n.tag) {
            .declaration => n,
            else => return error.ExpectedStatement,
        };
    }

    pub fn getType(n: *Node) Error!NodeIndex {
        return switch (n.tag) {
            .declaration => |declaration| try declaration.getType(),
            .ty => typeid_node,
            else => error.ExpectedType,
        };
    }

    pub fn selector(n: *Node, i: *Ir, field: []const u8) Error!NodeIndex {
        switch (n.tag) {
            .identifier => |identifier| return try i.get(identifier).selector(i, field),
            .ty => |ty| switch (ty) {
                .enumeration => |e| {
                    for (e.fields) |f| {
                        if (std.mem.eql(u8, f.name, field)) {
                            return f.name;
                        }
                    }
                    return error.UnknownEnumItem;
                },
                .@"union", .structure => {
                    return error.AccessingNonField;
                },
                else => return error.Expected,
            },
            .expression => |expression| {
                const got = try i.get(expression).resolve(i);
                switch (got.tag) {
                    .ty => |ty| switch (ty) {},
                    .package_scope => |ps| {
                        if (ps.get(field)) |index| {
                            return index;
                        } else {
                            return error.UnknownPackageItem;
                        }
                    },
                    else => return error.ExpectedStructUni,
                }
            },
            else => return error.ExpectedIdentifier,
        }
    }

    pub fn unwrap(n: *Node) Error!NodeIndex {
        return switch (n.tag) {
            .identifier => |identifier| identifier,
            else => return error.ExpectedIdentifier,
        };
    }
};

allocator: std.mem.Allocator,
nodes: std.ArrayListUnmanaged(Node),
const unused_node: NodeIndex = @enumFromInt(0);
const typeid_node: NodeIndex = @enumFromInt(1);

pub fn init(allocator: std.mem.Allocator) !Ir {
    var self: Ir = .{
        .allocator = allocator,
        .nodes = std.ArrayListUnmanaged(Node){},
    };
    try self.nodes.ensureUnusedCapacity(allocator, 2);
    _ = try self.put(Node{ .start = .{}, .end = .{}, .tag = .{
        .identifier = .none,
    } });
    _ = try self.put(Node{
        .start = .{},
        .end = .{},
        .tag = .{ .ty = .typeid },
    });
    return self;
}

pub fn deinit(self: *Ir) void {
    self.nodes.deinit(self.allocator);
}

pub fn get(self: *Ir, index: NodeIndex) *Node {
    if (index == unused_node) unreachable;
    return &self.nodes.items[@intFromEnum(index)];
}

pub fn put(self: *Ir, node: Node) !NodeIndex {
    const added_node: NodeIndex = @enumFromInt(self.nodes.items.len);
    (try self.nodes.addOne(self.allocator)).* = node;
    return added_node;
}

pub fn putPackageScope(self: *Ir) !NodeIndex {
    return try self.put(.{
        .start = .{},
        .end = .{},
        .tag = .{ .package_scope = std.StringArrayHashMapUnmanaged(NodeIndex){} },
    });
}
