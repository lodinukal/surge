const std = @import("std");
const lexemes = @import("lexemes.zig");
const lexer = @import("lexer.zig");

pub const ExpressionKind = enum(u8) {
    tuple = 0,
    unary = 1, // <op> operand
    binary = 2, // lhs <op> rhs
    ternary = 3, // lhs <if|when> cond else rhs
    cast = 4, // auto_cast operand, cast(T)operand, transmute(T)operand
    selector = 5, // base.field or .enumerator
    call = 6, // operand(..args)
    unwrap = 7, // operand.(T) or operand.?
    procedure = 8, // proc() {}
    type = 9, // T
    index = 10, // x[n], x[:], x[n:], x[:n], x[a:b], x[a,b]
    slice = 11, // []T
    literal = 12, // int, float, codepoint, string
    compound_literal = 13, // T{...}
    identifier = 14, // ident
    context = 15, // context
    undefined = 16, // ---
    procedure_group = 17, // proc{...}
};

pub const StatementKind = enum(u8) {
    empty = 0,
    block = 1,
    import = 2, // import
    expression = 3,
    assignment = 4, // =, +=, -=, *=, /=, %=, %%=, &=, |=, ~=, &~=, <<=, >>=, &&=, ||=
    declaration = 5,
    @"if" = 6,
    when = 7,
    @"return" = 8,
    @"for" = 9,
    @"switch" = 10,
    @"defer" = 11,
    branch = 12, // break, continue, fallthrough
    foreign_block = 13, // foreign <name>
    foreign_import = 14, // foreign import
    using = 15, // using <name>
    package = 16, // package <ident>
};

pub const ProcedureKind = enum(u8) {
    concrete,
    generic,
};

pub const StructKind = enum(u8) {
    concrete,
    generic,
};

pub const UnionKind = enum(u8) {
    concrete,
    generic,
};

pub const TypeKind = enum(u8) {
    builtin = 0, // b{8,16,32,64}, f{16,32,64}(le|be), (i|u)8, (i|u){16,32,64,128}(le|be),
    procedure = 1, // proc
    pointer = 2, // ^T
    multi_pointer = 3, // [^]T
    slice = 4, // []T
    array = 5, // [N]T or [?]T
    dynamic_array = 6, // [dynamic]T
    bit_set = 7, // bit_set[T] or bit_set[T; U]
    typeid = 8, // typeid
    map = 9, // map[K]V
    matrix = 10, // matrix[R,C]T
    distinct = 11, // distinct T
    @"enum" = 12, // enum
    @"struct" = 13, // struct
    @"union" = 14, // union
    poly = 15, // $T or $T/$U
    expression = 16, // Expression which evaluates to a Type*
};

pub const BuiltinTypeKind = enum(u8) {
    sint = 0, // i8,i{16,32,64,128}(le|be)
    uint = 1, // u8,u{16,32,64,128}(le|be)
    float = 2, // f{16,32,64}(le|be)
    bool = 3, // b{8,16,32,64}
    string = 4, // string
    cstring = 5, // cstring
    pointer = 6, // rawptr
    uintptr = 7, // uintptr
};

pub const Endianess = enum(u8) {
    na,
    little,
    big,
};

pub const BlockFlags = packed struct {
    bounds_check: bool = false,
    type_assert: bool = false,
};

pub const ProcedureFlags = packed struct {
    diverging: bool = false,
    optional_ok: bool = false,
    optional_allocation_error: bool = false,
    bounds_check: bool = false,
    type_assert: bool = false,
    force_inline: bool = false,
};

pub const StructFlags = packed struct {
    @"packed": bool = false,
    uncopyable: bool = false,
    @"union": bool = false,
};

pub const UnionFlags = packed struct {
    no_nil: bool = false,
    shared_nil: bool = false,
    maybe: bool = false,
};

pub const FieldFlags = packed struct {
    using: bool = false,
    any_int: bool = false,
    c_vararg: bool = false,
    no_alias: bool = false,
    subtype: bool = false,
    @"const": bool = false,
};

pub const CallingConvention = enum(u8) {
    invalid,
    rlth,
    contextless,
    cdecl,
    stdcall,
    fastcall,
    none,
    naked,
    win64,
    sysv,
    system,
};

// Expressions
pub const Expression = union(ExpressionKind) {
    tuple: TupleExpression,
    unary: UnaryExpression,
    binary: BinaryExpression,
    ternary: TernaryExpression,
    cast: CastExpression,
    selector: SelectorExpression,
    call: CallExpression,
    unwrap: UnwrapExpression,
    procedure: ProcedureExpression,
    type: TypeExpression,
    index: IndexExpression,
    slice: SliceExpression,
    literal: LiteralExpression,
    compound_literal: CompoundLiteralExpression,
    identifier: IdentifierExpression,
    context: ContextExpression,
    undefined: UndefinedExpression,
    procedure_group: ProcedureGroupExpression,
};

pub const TupleExpression = struct {
    expressions: std.ArrayList(*Expression),
};

pub const UnaryExpression = struct {
    operation: lexemes.OperatorKind,
    operand: *Expression,
};

pub const BinaryExpression = struct {
    operation: lexemes.OperatorKind,
    lhs: *Expression,
    rhs: *Expression,
};

pub const TernaryExpression = struct {
    operation: lexemes.KeywordKind,
    on_true: *Expression,
    condition: *Expression,
    on_false: *Expression,

    pub inline fn isRuntime(self: TernaryExpression) bool {
        return self.operation == .@"if";
    }
};

pub const CastExpression = struct {
    operation: lexemes.KeywordKind,
    type: *Type,
    expression: *Expression,
};

pub const SelectorExpression = struct {
    operand: ?*Expression,
    field: *Identifier,
};

pub const CallExpression = struct {
    operand: *Expression,
    arguments: std.ArrayList(*Field),
};

pub const UnwrapExpression = struct {
    operand: *Expression,
    item: ?*Identifier = null,
};

pub const ProcedureExpression = struct {
    type: *ProcedureType,
    where_clauses: ?*TupleExpression = null,
    body: ?*BlockStatement = null,
};

pub const TypeExpression = struct {
    type: *Type,
};

pub const IndexExpression = struct {
    operand: *Expression,
    lhs: ?*Expression,
    rhs: ?*Expression,
};

pub const SliceExpression = struct {
    operand: *Expression,
    lhs: *Expression,
    rhs: *Expression,
};

pub const LiteralExpression = struct {
    kind: lexemes.LiteralKind,
    value: []const u8,
};

pub const CompoundLiteralExpression = struct {
    type: ?*Type = null,
    fields: std.ArrayList(*Field),
};

pub const IdentifierExpression = struct {
    identifier: *Identifier,
};

pub const ContextExpression = struct {};
pub const UndefinedExpression = struct {};

pub const ProcedureGroupExpression = struct {
    expressions: std.ArrayList(*Expression),
};

// Statements
pub const Statement = union(StatementKind) {
    empty: EmptyStatement,
    block: BlockStatement,
    import: ImportStatement,
    expression: ExpressionStatement,
    assignment: AssignmentStatement,
    declaration: DeclarationStatement,
    @"if": IfStatement,
    when: WhenStatement,
    @"return": ReturnStatement,
    @"for": ForStatement,
    @"switch": SwitchStatement,
    @"defer": DeferStatement,
    branch: BranchStatement,
    foreign_block: ForeignBlockStatement,
    foreign_import: ForeignImportStatement,
    using: UsingStatement,
    package: PackageStatement,
};

pub const EmptyStatement = struct {};

pub const ImportStatement = struct {
    name: ?[]const u8,
    collection: []const u8,
    pathname: []const u8,
    using: bool,
    location: lexer.Location,
};

pub const ExpressionStatement = struct {
    expression: *Expression,
};

pub const BlockStatement = struct {
    flags: BlockFlags,
    statements: std.ArrayList(*Statement),
    label: ?*Identifier,
};

pub const AssignmentStatement = struct {
    assignment: lexemes.AssignmentKind,
    lhs: *TupleExpression,
    rhs: *TupleExpression,
};

pub const DeclarationStatement = struct {
    type: ?*Type = null,
    names: std.ArrayList(*Identifier),
    values: ?*TupleExpression = null,
    attributes: std.ArrayList(*Field),
    using: bool,
};

pub const IfStatement = struct {
    init: ?*Statement = null,
    condition: *Expression,
    body: *BlockStatement,
    elif: ?*BlockStatement = null,
    label: ?*Identifier,
};

pub const WhenStatement = struct {
    condition: *Expression,
    body: *BlockStatement,
    elif: ?*BlockStatement = null,
};

pub const ReturnStatement = struct {
    expression: *TupleExpression,
};

pub const ForStatement = struct {
    init: ?*Statement,
    condition: ?*Expression,
    body: *BlockStatement,
    post: ?*Statement = null,
    label: ?*Identifier,
};

pub const SwitchStatement = struct {
    init: ?*Statement,
    condition: ?*Expression,
    clauses: std.ArrayList(*CaseClause),
    label: ?*Identifier,
};

pub const DeferStatement = struct {
    statement: *Statement,
};

pub const BranchStatement = struct {
    branch: lexemes.KeywordKind,
    label: ?*Identifier,
};

pub const ForeignBlockStatement = struct {
    name: ?*Identifier = null,
    body: *BlockStatement,
    attributes: std.ArrayList(*Field),
};

pub const ForeignImportStatement = struct {
    name: []const u8,
    sources: std.ArrayList([]const u8),
    attributes: std.ArrayList(*Field),
};

pub const UsingStatement = struct {
    list: *TupleExpression,
};

pub const PackageStatement = struct {
    name: []const u8,
    location: lexer.Location,
};

// Types
pub const Type = struct {
    poly: bool,
    derived: union(TypeKind) {
        builtin: BuiltinType,
        // identifier: IdentifierType,
        procedure: ProcedureType,
        pointer: PointerType,
        multi_pointer: MultiPointerType,
        slice: SliceType,
        array: ArrayType,
        dynamic_array: DynamicArrayType,
        bit_set: BitSetType,
        typeid: TypeidType,
        map: MapType,
        matrix: MatrixType,
        distinct: DistinctType,
        @"enum": EnumType,
        @"struct": StructType,
        @"union": UnionType,
        poly: PolyType,
        expression: ExpressionType,
    },
};

pub const BuiltinType = struct {
    identifier: []const u8,
    kind: BuiltinTypeKind,
    size: u16,
    alignof: u16,
    endianess: Endianess,
};

pub const IdentifierType = struct {
    identifier: *Identifier,
};

pub const ProcedureType = struct {
    kind: ProcedureKind,
    flags: ProcedureFlags,
    convention: CallingConvention,
    params: std.ArrayList(*Field),
    results: std.ArrayList(*Field),
};

pub const PointerType = struct {
    type: *Type,
};

pub const MultiPointerType = struct {
    type: *Type,
};

pub const SliceType = struct {
    type: *Type,
};

pub const ArrayType = struct {
    type: *Type,
    count: ?*Expression,
};

pub const DynamicArrayType = struct {
    type: *Type,
};

pub const BitSetType = struct {
    underlying: ?*Type,
    expression: *Expression,
};

pub const TypeidType = struct {
    specialisation: ?*Type,
};

pub const MapType = struct {
    key: *Type,
    value: *Type,
};

pub const MatrixType = struct {
    rows: *Expression,
    columns: *Expression,
    type: *Type,
};

pub const DistinctType = struct {
    type: *Type,
};

pub const EnumType = struct {
    type: ?*Type = null,
    fields: std.ArrayList(*Field),
};

pub const ExpressionType = struct {
    expression: *Expression,
};

pub const StructType = struct {
    kind: StructKind,
    flags: StructFlags,
    @"align": ?*Expression,
    fields: std.ArrayList(*Field),
    where_clauses: ?*TupleExpression,

    parameters: ?std.ArrayList(*Field) = null,
};

pub const UnionType = struct {
    kind: UnionKind,
    flags: UnionFlags,
    @"align": ?*Expression,
    variants: std.ArrayList(*Field),
    where_clauses: ?*TupleExpression,

    parameters: ?std.ArrayList(*Field) = null,
};

pub const PolyType = struct {
    type: *Type,
    specialisation: ?*Type,
};

pub const Identifier = struct {
    contents: []const u8,
    poly: bool,
    token: u32,
};

pub const Field = struct {
    name: ?*Identifier = null,
    type: ?*Type = null,
    value: ?*Expression = null,
    tag: ?[]const u8 = null,
    flags: FieldFlags,
};

pub const CaseClause = struct {
    expression: ?*TupleExpression = null,
    statements: std.ArrayList(*Statement),
};

/// this will not clean up it's memory
/// use an arena or something to clean up
pub const Tree = struct {
    allocator: std.mem.Allocator = undefined,

    source: lexer.Source = undefined,
    statements: std.ArrayList(*Statement) = undefined,
    imports: std.ArrayList(*ImportStatement) = undefined,
    tokens: std.ArrayList(lexer.Token) = undefined,

    pub fn init(tree: *Tree, allocator: std.mem.Allocator, name: []const u8) !void {
        tree.* = Tree{
            .allocator = allocator,
            .source = lexer.Source{
                .name = name,
                .code = "",
            },
            .statements = std.ArrayList(*Statement).init(allocator),
            .imports = std.ArrayList(*ImportStatement).init(allocator),
            .tokens = std.ArrayList(lexer.Token).init(allocator),
        };
    }

    pub fn deinit(self: *Tree) void {
        _ = self; // autofix
    }

    /// consumes `expressions`
    pub fn newTupleExpression(self: *Tree, expressions: std.ArrayList(*Expression)) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .tuple = .{
            .expressions = expressions,
        } };
        return e;
    }

    pub fn newUnaryExpression(
        self: *Tree,
        operation: lexemes.OperatorKind,
        operand: *Expression,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .unary = .{
            .operation = operation,
            .operand = operand,
        } };
        return e;
    }

    pub fn newBinaryExpression(
        self: *Tree,
        operation: lexemes.OperatorKind,
        lhs: *Expression,
        rhs: *Expression,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .binary = .{
            .operation = operation,
            .lhs = lhs,
            .rhs = rhs,
        } };
        return e;
    }

    pub fn newTernaryExpression(
        self: *Tree,
        operation: lexemes.KeywordKind,
        on_true: *Expression,
        condition: *Expression,
        on_false: *Expression,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .ternary = .{
            .operation = operation,
            .on_true = on_true,
            .condition = condition,
            .on_false = on_false,
        } };
        return e;
    }

    pub fn newCastExpression(
        self: *Tree,
        operation: lexemes.KeywordKind,
        ty: *Type,
        expression: *Expression,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .cast = .{
            .operation = operation,
            .type = ty,
            .expression = expression,
        } };
        return e;
    }

    pub fn newSelectorExpression(
        self: *Tree,
        operand: ?*Expression,
        field: *Identifier,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .selector = .{
            .operand = operand,
            .field = field,
        } };
        return e;
    }

    pub fn newCallExpression(
        self: *Tree,
        operand: *Expression,
        arguments: std.ArrayList(*Field),
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .call = .{
            .operand = operand,
            .arguments = arguments,
        } };
        return e;
    }

    pub fn newUnwrapExpression(
        self: *Tree,
        operand: *Expression,
        item: ?*Identifier,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .unwrap = .{
            .operand = operand,
            .item = item,
        } };
        return e;
    }

    pub fn newProcedureExpression(
        self: *Tree,
        ty: *ProcedureType,
        where_clauses: ?*TupleExpression,
        body: ?*BlockStatement,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .procedure = .{
            .type = ty,
            .where_clauses = where_clauses,
            .body = body,
        } };
        return e;
    }

    pub fn newTypeExpression(self: *Tree, ty: *Type) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .type = .{
            .type = ty,
        } };
        return e;
    }

    pub fn newIndexExpression(
        self: *Tree,
        operand: *Expression,
        lhs: ?*Expression,
        rhs: ?*Expression,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .index = .{
            .operand = operand,
            .lhs = lhs,
            .rhs = rhs,
        } };
        return e;
    }

    pub fn newSliceExpression(
        self: *Tree,
        operand: *Expression,
        lhs: *Expression,
        rhs: *Expression,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .slice = .{
            .operand = operand,
            .lhs = lhs,
            .rhs = rhs,
        } };
        return e;
    }

    pub fn newLiteralExpression(
        self: *Tree,
        kind: lexemes.LiteralKind,
        value: []const u8,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .literal = .{
            .kind = kind,
            .value = value,
        } };
        return e;
    }

    pub fn newCompoundLiteralExpression(
        self: *Tree,
        ty: ?*Type,
        fields: std.ArrayList(*Field),
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .compound_literal = .{
            .type = ty,
            .fields = fields,
        } };
        return e;
    }

    pub fn newIdentifierExpression(
        self: *Tree,
        identifier: *Identifier,
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .identifier = .{
            .identifier = identifier,
        } };
        return e;
    }

    pub fn newContextExpression(self: *Tree) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression.context;
        return e;
    }

    pub fn newUndefinedExpression(self: *Tree) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression.undefined;
        return e;
    }

    pub fn newProcedureGroupExpression(
        self: *Tree,
        expressions: std.ArrayList(*Expression),
    ) !*Expression {
        const e = try self.allocator.create(Expression);
        e.* = Expression{ .procedure_group = .{
            .expressions = expressions,
        } };
        return e;
    }

    pub fn newEmptyStatement(self: *Tree) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement.empty;
        return s;
    }

    pub fn newImportStatement(
        self: *Tree,
        name: []const u8,
        collection: []const u8,
        pathname: []const u8,
        using: bool,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .import = .{
            .name = name,
            .collection = collection,
            .pathname = pathname,
            .using = using,
            .location = self.tokens.getLast().location,
        } };
        return s;
    }

    pub fn newExpressionStatement(
        self: *Tree,
        expression: *Expression,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .expression = .{
            .expression = expression,
        } };
        return s;
    }

    pub fn newBlockStatement(
        self: *Tree,
        flags: BlockFlags,
        statements: std.ArrayList(*Statement),
        label: ?*Identifier,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .block = .{
            .flags = flags,
            .statements = statements,
            .label = label,
        } };
        return s;
    }

    pub fn newAssignmentStatement(
        self: *Tree,
        assignment: lexemes.AssignmentKind,
        lhs: *TupleExpression,
        rhs: *TupleExpression,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .assignment = .{
            .assignment = assignment,
            .lhs = lhs,
            .rhs = rhs,
        } };
        return s;
    }

    pub fn newDeclarationStatement(
        self: *Tree,
        ty: ?*Type,
        names: std.ArrayList(*Identifier),
        values: ?*TupleExpression,
        attributes: std.ArrayList(*Field),
        using: bool,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .declaration = .{
            .type = ty,
            .names = names,
            .values = values,
            .attributes = attributes,
            .using = using,
        } };
        return s;
    }

    pub fn newIfStatement(
        self: *Tree,
        _init: ?*Statement,
        condition: *Expression,
        body: *BlockStatement,
        elif: ?*BlockStatement,
        label: ?*Identifier,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .@"if" = .{
            .init = _init,
            .condition = condition,
            .body = body,
            .elif = elif,
            .label = label,
        } };
        return s;
    }

    pub fn newWhenStatement(
        self: *Tree,
        condition: *Expression,
        body: *BlockStatement,
        elif: ?*BlockStatement,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .when = .{
            .condition = condition,
            .body = body,
            .elif = elif,
        } };
        return s;
    }

    pub fn newReturnStatement(
        self: *Tree,
        expression: *TupleExpression,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .@"return" = .{
            .expression = expression,
        } };
        return s;
    }

    pub fn newForStatement(
        self: *Tree,
        _init: ?*Statement,
        condition: ?*Expression,
        body: *BlockStatement,
        post: ?*Statement,
        label: ?*Identifier,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .@"for" = .{
            .init = _init,
            .condition = condition,
            .body = body,
            .post = post,
            .label = label,
        } };
        return s;
    }

    pub fn newSwitchStatement(
        self: *Tree,
        _init: ?*Statement,
        condition: ?*Expression,
        clauses: std.ArrayList(*CaseClause),
        label: ?*Identifier,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .@"switch" = .{
            .init = _init,
            .condition = condition,
            .clauses = clauses,
            .label = label,
        } };
        return s;
    }

    pub fn newDeferStatement(
        self: *Tree,
        statement: *Statement,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .@"defer" = .{
            .statement = statement,
        } };
        return s;
    }

    pub fn newBranchStatement(
        self: *Tree,
        branch: lexemes.KeywordKind,
        label: ?*Identifier,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .branch = .{
            .branch = branch,
            .label = label,
        } };
        return s;
    }

    pub fn newForeignBlockStatement(
        self: *Tree,
        name: ?*Identifier,
        body: *BlockStatement,
        attributes: std.ArrayList(*Field),
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .foreign_block = .{
            .name = name,
            .body = body,
            .attributes = attributes,
        } };
        return s;
    }

    pub fn newForeignImportStatement(
        self: *Tree,
        name: []const u8,
        sources: std.ArrayList([]const u8),
        attributes: std.ArrayList(*Field),
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .foreign_import = .{
            .name = name,
            .sources = sources,
            .attributes = attributes,
        } };
        return s;
    }

    pub fn newUsingStatement(
        self: *Tree,
        list: *TupleExpression,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .using = .{
            .list = list,
        } };
        return s;
    }

    pub fn newPackageStatement(
        self: *Tree,
        name: []const u8,
    ) !*Statement {
        const s = try self.allocator.create(Statement);
        s.* = Statement{ .package = .{
            .name = name,
            .location = self.tokens.getLast().location,
        } };
        return s;
    }

    pub fn newIdentifier(
        self: *Tree,
        contents: []const u8,
        poly: bool,
    ) !*Identifier {
        const i = try self.allocator.create(Identifier);
        i.* = Identifier{
            .contents = contents,
            .poly = poly,
            .token = @intCast(self.tokens.items.len - 1),
        };
        return i;
    }

    pub fn newCaseClause(
        self: *Tree,
        expression: ?*TupleExpression,
        statements: std.ArrayList(*Statement),
    ) !*CaseClause {
        const c = try self.allocator.create(CaseClause);
        c.* = CaseClause{
            .expression = expression,
            .statements = statements,
        };
        return c;
    }

    pub fn newType(
        self: *Tree,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = undefined;
        t.poly = false;
        return t;
    }

    pub fn newPointerType(
        self: *Tree,
        value_type: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .pointer = .{
                .type = value_type,
            },
        };
        return t;
    }

    pub fn newMultiPointerType(
        self: *Tree,
        value_type: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .multi_pointer = .{
                .type = value_type,
            },
        };
        return t;
    }

    pub fn newSliceType(
        self: *Tree,
        value_type: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .slice = .{
                .type = value_type,
            },
        };
        return t;
    }

    pub fn newArrayType(
        self: *Tree,
        value_type: *Type,
        count: ?*Expression,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .array = .{
                .type = value_type,
                .count = count,
            },
        };
        return t;
    }

    pub fn newDynamicArrayType(
        self: *Tree,
        value_type: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .dynamic_array = .{
                .type = value_type,
            },
        };
        return t;
    }

    pub fn newBitSetType(
        self: *Tree,
        underlying: ?*Type,
        expression: *Expression,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .bit_set = .{
                .underlying = underlying,
                .expression = expression,
            },
        };
        return t;
    }

    pub fn newTypeidType(
        self: *Tree,
        specialisation: ?*Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .typeid = .{
                .specialisation = specialisation,
            },
        };
        return t;
    }

    pub fn newMapType(
        self: *Tree,
        key: *Type,
        value: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .map = .{
                .key = key,
                .value = value,
            },
        };
        return t;
    }

    pub fn newMatrixType(
        self: *Tree,
        rows: *Expression,
        columns: *Expression,
        value_type: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .matrix = .{
                .rows = rows,
                .columns = columns,
                .type = value_type,
            },
        };
        return t;
    }

    pub fn newDistinctType(
        self: *Tree,
        value_type: *Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .distinct = .{
                .type = value_type,
            },
        };
        return t;
    }

    pub fn newEnumType(
        self: *Tree,
        value_type: ?*Type,
        fields: std.ArrayList(*Field),
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .@"enum" = .{
                .type = value_type,
                .fields = fields,
            },
        };
        return t;
    }

    pub fn newConcreteStructType(
        self: *Tree,
        flags: StructFlags,
        @"align": ?*Expression,
        fields: std.ArrayList(*Field),
        where_clauses: ?*TupleExpression,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .@"struct" = .{
                .kind = StructKind.concrete,
                .flags = flags,
                .@"align" = @"align",
                .fields = fields,
                .where_clauses = where_clauses,
            },
        };
        return t;
    }

    pub fn newGenericStructType(
        self: *Tree,
        flags: StructFlags,
        @"align": ?*Expression,
        fields: std.ArrayList(*Field),
        where_clauses: ?*TupleExpression,
        parameters: std.ArrayList(*Field),
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .@"struct" = .{
                .kind = StructKind.generic,
                .flags = flags,
                .@"align" = @"align",
                .fields = fields,
                .where_clauses = where_clauses,
                .parameters = parameters,
            },
        };
        return t;
    }

    pub fn newConcreteUnionType(
        self: *Tree,
        flags: UnionFlags,
        @"align": ?*Expression,
        variants: std.ArrayList(*Field),
        where_clauses: ?*TupleExpression,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .@"union" = .{
                .kind = UnionKind.concrete,
                .flags = flags,
                .@"align" = @"align",
                .variants = variants,
                .where_clauses = where_clauses,
            },
        };
        return t;
    }

    pub fn newGenericUnionType(
        self: *Tree,
        flags: UnionFlags,
        @"align": ?*Expression,
        variants: std.ArrayList(*Field),
        where_clauses: ?*TupleExpression,
        parameters: std.ArrayList(*Field),
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .@"union" = .{
                .kind = UnionKind.generic,
                .flags = flags,
                .@"align" = @"align",
                .variants = variants,
                .where_clauses = where_clauses,
                .parameters = parameters,
            },
        };
        return t;
    }

    pub fn newPolyType(
        self: *Tree,
        base_type: *Type,
        specialisation: ?*Type,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .poly = .{
                .type = base_type,
                .specialisation = specialisation,
            },
        };
        return t;
    }

    pub fn newExpressionType(
        self: *Tree,
        expression: *Expression,
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .expression = .{
                .expression = expression,
            },
        };
        return t;
    }

    pub fn newConcreteProcedureType(
        self: *Tree,
        flags: ProcedureFlags,
        convention: CallingConvention,
        params: std.ArrayList(*Field),
        results: std.ArrayList(*Field),
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .procedure = .{
                .kind = ProcedureKind.concrete,
                .flags = flags,
                .convention = convention,
                .params = params,
                .results = results,
            },
        };
        return t;
    }

    pub fn newGenericProcedureType(
        self: *Tree,
        flags: ProcedureFlags,
        convention: CallingConvention,
        params: std.ArrayList(*Field),
        results: std.ArrayList(*Field),
    ) !*Type {
        const t = try self.allocator.create(Type);
        t.derived = .{
            .procedure = .{
                .kind = ProcedureKind.generic,
                .flags = flags,
                .convention = convention,
                .params = params,
                .results = results,
            },
        };
        return t;
    }

    pub fn newField(
        self: *Tree,
        value_type: ?*Type,
        name: ?*Identifier,
        value: ?*Expression,
        tag: ?[]const u8,
        flags: FieldFlags,
    ) !*Field {
        const f = try self.allocator.create(Field);
        f.* = Field{
            .name = name,
            .type = value_type,
            .value = value,
            .tag = tag,
            .flags = flags,
        };
        return f;
    }

    pub fn recordToken(self: *Tree, token: lexer.Token) !void {
        try self.tokens.append(token);
    }
};

test {
    std.testing.refAllDecls(@This());
}
