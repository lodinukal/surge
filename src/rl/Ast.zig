const std = @import("std");
const lexemes = @import("lexemes.zig");
const lexer = @import("lexer.zig");

pub const ExpressionIndex = enum(usize) { none = std.math.maxInt(usize), _ };
pub const StatementIndex = enum(usize) { none = std.math.maxInt(usize), _ };
pub const TypeIndex = enum(usize) { none = std.math.maxInt(usize), _ };
pub const CaseClauseIndex = enum(usize) { none = std.math.maxInt(usize), _ };
pub const IdentifierIndex = enum(usize) { none = std.math.maxInt(usize), _ };
pub const FieldIndex = enum(usize) { none = std.math.maxInt(usize), _ };
pub const RefIndex = enum(usize) { none = std.math.maxInt(usize), _ };

pub const AnyIndex = enum(usize) {
    none = std.math.maxInt(usize),
    _,

    pub inline fn from(any: anytype) AnyIndex {
        return switch (@TypeOf(any)) {
            ExpressionIndex,
            StatementIndex,
            TypeIndex,
            CaseClauseIndex,
            IdentifierIndex,
            FieldIndex,
            RefIndex,
            => @enumFromInt(@intFromEnum(any)),
            else => @compileError("Invalid index type"),
        };
    }

    pub inline fn to(self: AnyIndex, comptime T: type) T {
        return switch (T) {
            ExpressionIndex,
            StatementIndex,
            TypeIndex,
            CaseClauseIndex,
            IdentifierIndex,
            FieldIndex,
            RefIndex,
            => @enumFromInt(@intFromEnum(self)),
            else => @compileError("Invalid index type"),
        };
    }
};

pub const Any = union(enum) {
    none: void,
    expression: Expression,
    statement: Statement,
    type: Type,
    case_clause: CaseClause,
    identifier: Identifier,
    field: Field,
    ref: RefIndex,
};

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
    _,
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
    rl,
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
    expressions: RefIndex, // std.ArrayList(ExpressionIndex),
};

pub const UnaryExpression = struct {
    operation: lexemes.OperatorKind,
    operand: ExpressionIndex,
};

pub const BinaryExpression = struct {
    operation: lexemes.OperatorKind,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
};

pub const TernaryExpression = struct {
    operation: lexemes.KeywordKind,
    on_true: ExpressionIndex,
    condition: ExpressionIndex,
    on_false: ExpressionIndex,

    pub inline fn isRuntime(self: TernaryExpression) bool {
        return self.operation == .@"if";
    }
};

pub const CastExpression = struct {
    operation: lexemes.KeywordKind,
    type: TypeIndex,
    expression: ExpressionIndex,
};

pub const SelectorExpression = struct {
    operand: ?ExpressionIndex,
    field: IdentifierIndex,
};

pub const CallExpression = struct {
    operand: ExpressionIndex,
    arguments: RefIndex, // std.ArrayList(FieldIndex),
};

pub const UnwrapExpression = struct {
    operand: ExpressionIndex,
    item: ?IdentifierIndex = null,
};

pub const ProcedureExpression = struct {
    type: TypeIndex,
    where_clauses: ?ExpressionIndex = null,
    body: ?StatementIndex = null,
};

pub const TypeExpression = struct {
    type: TypeIndex,
};

pub const IndexExpression = struct {
    operand: ExpressionIndex,
    lhs: ?ExpressionIndex,
    rhs: ?ExpressionIndex,
};

pub const SliceExpression = struct {
    operand: ExpressionIndex,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
};

pub const LiteralExpression = struct {
    kind: lexemes.LiteralKind,
    value: []const u8,
};

pub const CompoundLiteralExpression = struct {
    type: ?TypeIndex = null,
    fields: RefIndex, // std.ArrayList(FieldIndex),
};

pub const IdentifierExpression = struct {
    identifier: IdentifierIndex,
};

pub const ContextExpression = struct {};
pub const UndefinedExpression = struct {};

pub const ProcedureGroupExpression = struct {
    expressions: RefIndex, // std.ArrayList(ExpressionIndex),
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
    name: []const u8,
    collection: []const u8,
    pathname: []const u8,
    using: bool,
    location: lexer.Location,
};

pub const ExpressionStatement = struct {
    expression: ExpressionIndex,
};

pub const BlockStatement = struct {
    flags: BlockFlags,
    statements: RefIndex, // std.ArrayList(StatementIndex),
    label: ?IdentifierIndex,
};

pub const AssignmentStatement = struct {
    assignment: lexemes.AssignmentKind,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
};

pub const DeclarationStatement = struct {
    type: ?TypeIndex = null,
    names: RefIndex, // std.ArrayList(IdentifierIndex),
    values: ExpressionIndex,
    attributes: RefIndex, // std.ArrayList(FieldIndex),
    using: bool,
    constant: bool,
};

pub const IfStatement = struct {
    init: ?StatementIndex = null,
    condition: ExpressionIndex,
    body: StatementIndex,
    elif: ?StatementIndex = null,
    label: ?IdentifierIndex,
};

pub const WhenStatement = struct {
    condition: ExpressionIndex,
    body: StatementIndex,
    elif: ?StatementIndex = null,
};

pub const ReturnStatement = struct {
    expression: ExpressionIndex,
};

pub const ForStatement = struct {
    init: ?StatementIndex,
    condition: ?ExpressionIndex,
    body: StatementIndex,
    post: ?StatementIndex = null,
    label: ?IdentifierIndex,
};

pub const SwitchStatement = struct {
    init: ?StatementIndex,
    condition: ?ExpressionIndex,
    clauses: RefIndex, // std.ArrayList(CaseClauseIndex),
    label: ?IdentifierIndex,
};

pub const DeferStatement = struct {
    statement: StatementIndex,
};

pub const BranchStatement = struct {
    branch: lexemes.KeywordKind,
    label: ?IdentifierIndex,
};

pub const ForeignBlockStatement = struct {
    name: ?IdentifierIndex = null,
    body: StatementIndex,
    attributes: RefIndex, // std.ArrayList(FieldIndex),
};

pub const ForeignImportStatement = struct {
    name: []const u8,
    sources: std.ArrayList([]const u8),
    attributes: RefIndex, // std.ArrayList(FieldIndex),
};

pub const UsingStatement = struct {
    list: ExpressionIndex,
};

pub const PackageStatement = struct {
    name: []const u8,
    location: lexer.Location,
};

// Types
pub const Type = struct {
    poly: bool = false,
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
    } = undefined,
};

pub const BuiltinType = struct {
    identifier: []const u8,
    kind: BuiltinTypeKind,
    size: u16,
    alignof: u16,
    endianess: Endianess,
};

pub const IdentifierType = struct {
    identifier: IdentifierIndex,
};

pub const ProcedureType = struct {
    kind: ProcedureKind,
    flags: ProcedureFlags,
    convention: CallingConvention,
    params: RefIndex, // std.ArrayList(FieldIndex),
    results: RefIndex, // std.ArrayList(FieldIndex),
};

pub const PointerType = struct {
    type: TypeIndex,
    is_const: bool = false,
};

pub const MultiPointerType = struct {
    type: TypeIndex,
    is_const: bool = false,
};

pub const SliceType = struct {
    type: TypeIndex,
    is_const: bool = false,
};

pub const ArrayType = struct {
    type: TypeIndex,
    count: ?ExpressionIndex,
};

pub const DynamicArrayType = struct {
    type: TypeIndex,
};

pub const BitSetType = struct {
    underlying: ?TypeIndex,
    expression: ExpressionIndex,
};

pub const TypeidType = struct {
    specialisation: ?TypeIndex,
};

pub const MapType = struct {
    key: TypeIndex,
    value: TypeIndex,
};

pub const MatrixType = struct {
    rows: ExpressionIndex,
    columns: ExpressionIndex,
    type: TypeIndex,
};

pub const DistinctType = struct {
    type: TypeIndex,
};

pub const EnumType = struct {
    type: ?TypeIndex = null,
    fields: RefIndex, // std.ArrayList(FieldIndex),
};

pub const ExpressionType = struct {
    expression: ExpressionIndex,
};

pub const StructType = struct {
    kind: StructKind,
    flags: StructFlags,
    @"align": ?ExpressionIndex,
    fields: RefIndex, // std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,

    parameters: ?RefIndex = null, // std.ArrayList(FieldIndex) = null,
};

pub const UnionType = struct {
    kind: UnionKind,
    flags: UnionFlags,
    @"align": ?ExpressionIndex,
    variants: RefIndex, // std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,

    parameters: ?RefIndex = null, // std.ArrayList(FieldIndex) = null,
};

pub const PolyType = struct {
    type: TypeIndex,
    specialisation: ?TypeIndex,
};

pub const Identifier = struct {
    contents: []const u8,
    poly: bool,
    token: u32,
};

pub const Field = struct {
    name: ?IdentifierIndex = null,
    type: ?TypeIndex = null,
    value: ?ExpressionIndex = null,
    tag: ?[]const u8 = null,
    flags: FieldFlags,
    attributes: RefIndex, // std.ArrayList(FieldIndex),
};

pub const CaseClause = struct {
    expression: ?ExpressionIndex = null,
    statements: RefIndex, // std.ArrayList(StatementIndex),
};

const Ast = @This();

allocator: std.mem.Allocator = undefined,

source: lexer.Source = undefined,

imports: std.ArrayListUnmanaged(StatementIndex) = undefined,

tokens: std.ArrayListUnmanaged(lexer.Token) = undefined,
statements: std.ArrayListUnmanaged(StatementIndex) = undefined,

all: std.ArrayListUnmanaged(Any) = undefined,
refs: std.ArrayListUnmanaged(AnyIndex) = undefined,

pub fn init(allocator: std.mem.Allocator, name: []const u8) !Ast {
    var self: Ast = .{
        .allocator = allocator,
        .source = lexer.Source{
            .name = name,
            .directory = std.fs.path.dirname(name) orelse "",
            .code = "",
        },
        .imports = std.ArrayListUnmanaged(StatementIndex){},

        .tokens = std.ArrayListUnmanaged(lexer.Token){},
        .statements = std.ArrayListUnmanaged(StatementIndex){},

        .all = std.ArrayListUnmanaged(Any){},
        .refs = std.ArrayListUnmanaged(AnyIndex){},
    };

    try self.refs.append(self.allocator, .none);

    return self;
}

pub fn deinit(self: *Ast) void {
    self.all.deinit(self.allocator);
    self.refs.deinit(self.allocator);

    self.tokens.deinit(self.allocator);
    self.statements.deinit(self.allocator);
    self.imports.deinit(self.allocator);
}

pub fn clone(self: *const Ast, allocator: std.mem.Allocator) !Ast {
    return .{
        .allocator = allocator,
        .source = lexer.Source{
            .name = try allocator.dupe(u8, self.source.name),
            .directory = try allocator.dupe(u8, self.source.directory),
            .code = "",
        },
        .imports = try self.imports.clone(allocator),

        .tokens = try self.tokens.clone(allocator),
        .statements = try self.statements.clone(allocator),

        .all = try self.all.clone(allocator),
        .refs = try self.refs.clone(allocator),
    };
}

pub fn getAny(self: *Ast, index: AnyIndex) *Any {
    return &self.all.items[@intFromEnum(index)];
}

pub fn createRef(self: *Ast, items: []const AnyIndex) !RefIndex {
    const start = self.refs.items.len;
    try self.refs.ensureUnusedCapacity(self.allocator, items.len + 1);
    for (items) |item| {
        self.refs.appendAssumeCapacity(item);
    }
    self.refs.appendAssumeCapacity(.none);
    return @enumFromInt(start);
}

pub fn refToList(self: *Ast, index: RefIndex) ![]const AnyIndex {
    if (index == .none) return &.{};
    return std.mem.sliceTo(self.refs.items[@intFromEnum(index)..], .none);
}

fn createExpression(self: *Ast, e: Expression) !ExpressionIndex {
    const index = self.all.items.len;
    const set = try self.all.addOne(self.allocator);
    set.* = .{ .expression = e };
    return @enumFromInt(index);
}

pub fn getExpression(self: *Ast, index: ExpressionIndex) *Expression {
    return &self.all.items[@intFromEnum(index)].expression;
}

pub fn getExpressionConst(self: *const Ast, index: ExpressionIndex) *const Expression {
    return &self.all.items[@intFromEnum(index)].expression;
}

fn createStatement(self: *Ast, s: Statement) !StatementIndex {
    const index = self.all.items.len;
    const set = try self.all.addOne(self.allocator);
    set.* = .{ .statement = s };
    return @enumFromInt(index);
}

pub fn getStatement(self: *Ast, index: StatementIndex) *Statement {
    return &self.all.items[@intFromEnum(index)].statement;
}

pub fn getStatementConst(self: *const Ast, index: StatementIndex) *const Statement {
    return &self.all.items[@intFromEnum(index)].statement;
}

fn createType(self: *Ast, t: Type) !TypeIndex {
    const index = self.all.items.len;
    const set = try self.all.addOne(self.allocator);
    set.* = .{ .type = t };
    return @enumFromInt(index);
}

pub fn cloneType(self: *Ast, index: TypeIndex) !TypeIndex {
    const t = self.all.items[@intFromEnum(index)].type;
    return try self.createType(t);
}

pub fn getType(self: *Ast, index: TypeIndex) *Type {
    return &self.all.items[@intFromEnum(index)].type;
}

pub fn getTypeConst(self: *const Ast, index: TypeIndex) *const Type {
    return &self.all.items[@intFromEnum(index)].type;
}

// std.ArrayList(ExpressionIndex)
/// consumes `expressions`
pub fn newTupleExpression(self: *Ast, expressions: RefIndex) !ExpressionIndex {
    return try self.createExpression(.{ .tuple = .{
        .expressions = expressions,
    } });
}

pub fn newUnaryExpression(
    self: *Ast,
    operation: lexemes.OperatorKind,
    operand: ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .unary = .{
        .operation = operation,
        .operand = operand,
    } });
}

pub fn newBinaryExpression(
    self: *Ast,
    operation: lexemes.OperatorKind,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .binary = .{
        .operation = operation,
        .lhs = lhs,
        .rhs = rhs,
    } });
}

pub fn newTernaryExpression(
    self: *Ast,
    operation: lexemes.KeywordKind,
    on_true: ExpressionIndex,
    condition: ExpressionIndex,
    on_false: ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .ternary = .{
        .operation = operation,
        .on_true = on_true,
        .condition = condition,
        .on_false = on_false,
    } });
}

pub fn newCastExpression(
    self: *Ast,
    operation: lexemes.KeywordKind,
    ty: TypeIndex,
    expression: ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .cast = .{
        .operation = operation,
        .type = ty,
        .expression = expression,
    } });
}

pub fn newSelectorExpression(
    self: *Ast,
    operand: ?ExpressionIndex,
    field: IdentifierIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .selector = .{
        .operand = operand,
        .field = field,
    } });
}

pub fn newCallExpression(
    self: *Ast,
    operand: ExpressionIndex,
    arguments: RefIndex, // std.ArrayList(FieldIndex),
) !ExpressionIndex {
    return try self.createExpression(.{ .call = .{
        .operand = operand,
        .arguments = arguments,
    } });
}

pub fn newUnwrapExpression(
    self: *Ast,
    operand: ExpressionIndex,
    item: ?IdentifierIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .unwrap = .{
        .operand = operand,
        .item = item,
    } });
}

pub fn newProcedureExpression(
    self: *Ast,
    ty: TypeIndex,
    where_clauses: ?ExpressionIndex,
    body: ?StatementIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .procedure = .{
        .type = ty,
        .where_clauses = where_clauses,
        .body = body,
    } });
}

pub fn newTypeExpression(self: *Ast, ty: TypeIndex) !ExpressionIndex {
    return try self.createExpression(.{ .type = .{
        .type = ty,
    } });
}

pub fn newIndexExpression(
    self: *Ast,
    operand: ExpressionIndex,
    lhs: ?ExpressionIndex,
    rhs: ?ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .index = .{
        .operand = operand,
        .lhs = lhs,
        .rhs = rhs,
    } });
}

pub fn newSliceExpression(
    self: *Ast,
    operand: ExpressionIndex,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .slice = .{
        .operand = operand,
        .lhs = lhs,
        .rhs = rhs,
    } });
}

pub fn newLiteralExpression(
    self: *Ast,
    kind: lexemes.LiteralKind,
    value: []const u8,
) !ExpressionIndex {
    return try self.createExpression(.{ .literal = .{
        .kind = kind,
        .value = value,
    } });
}

pub fn newCompoundLiteralExpression(
    self: *Ast,
    ty: ?TypeIndex,
    fields: RefIndex, // std.ArrayList(FieldIndex),
) !ExpressionIndex {
    return try self.createExpression(.{ .compound_literal = .{
        .type = ty,
        .fields = fields,
    } });
}

pub fn newIdentifierExpression(
    self: *Ast,
    identifier: IdentifierIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .identifier = .{
        .identifier = identifier,
    } });
}

pub fn newContextExpression(self: *Ast) !ExpressionIndex {
    return try self.createExpression(.context);
}

pub fn newUndefinedExpression(self: *Ast) !ExpressionIndex {
    return try self.createExpression(.undefined);
}

pub fn newProcedureGroupExpression(
    self: *Ast,
    expressions: RefIndex, // std.ArrayList(ExpressionIndex),
) !ExpressionIndex {
    return try self.createExpression(.{ .procedure_group = .{
        .expressions = expressions,
    } });
}

pub fn newEmptyStatement(self: *Ast) !StatementIndex {
    return try self.createStatement(.empty);
}

pub fn newImportStatement(
    self: *Ast,
    name: []const u8,
    collection: []const u8,
    pathname: []const u8,
    using: bool,
) !StatementIndex {
    return try self.createStatement(.{ .import = .{
        .name = name,
        .collection = collection,
        .pathname = pathname,
        .using = using,
        .location = self.tokens.getLast().location,
    } });
}

pub fn newExpressionStatement(
    self: *Ast,
    expression: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .expression = .{
        .expression = expression,
    } });
}

pub fn newBlockStatement(
    self: *Ast,
    flags: BlockFlags,
    statements: RefIndex, // std.ArrayList(StatementIndex),
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .block = .{
        .flags = flags,
        .statements = statements,
        .label = label,
    } });
}

pub fn newAssignmentStatement(
    self: *Ast,
    assignment: lexemes.AssignmentKind,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .assignment = .{
        .assignment = assignment,
        .lhs = lhs,
        .rhs = rhs,
    } });
}

pub fn newDeclarationStatement(
    self: *Ast,
    ty: ?TypeIndex,
    names: RefIndex, // std.ArrayList(IdentifierIndex),
    values: ExpressionIndex,
    attributes: RefIndex, // std.ArrayList(FieldIndex),
    using: bool,
    constant: bool,
) !StatementIndex {
    return try self.createStatement(.{ .declaration = .{
        .type = ty,
        .names = names,
        .values = values,
        .attributes = attributes,
        .using = using,
        .constant = constant,
    } });
}

pub fn newIfStatement(
    self: *Ast,
    _init: ?StatementIndex,
    condition: ExpressionIndex,
    body: StatementIndex,
    elif: ?StatementIndex,
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"if" = .{
        .init = _init,
        .condition = condition,
        .body = body,
        .elif = elif,
        .label = label,
    } });
}

pub fn newWhenStatement(
    self: *Ast,
    condition: ExpressionIndex,
    body: StatementIndex,
    elif: ?StatementIndex,
) !StatementIndex {
    return try self.createStatement(.{ .when = .{
        .condition = condition,
        .body = body,
        .elif = elif,
    } });
}

pub fn newReturnStatement(
    self: *Ast,
    expression: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"return" = .{
        .expression = expression,
    } });
}

pub fn newForStatement(
    self: *Ast,
    _init: ?StatementIndex,
    condition: ?ExpressionIndex,
    body: StatementIndex,
    post: ?StatementIndex,
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"for" = .{
        .init = _init,
        .condition = condition,
        .body = body,
        .post = post,
        .label = label,
    } });
}

pub fn newSwitchStatement(
    self: *Ast,
    _init: ?StatementIndex,
    condition: ?ExpressionIndex,
    clauses: RefIndex, // std.ArrayList(CaseClauseIndex),
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"switch" = .{
        .init = _init,
        .condition = condition,
        .clauses = clauses,
        .label = label,
    } });
}

pub fn newDeferStatement(
    self: *Ast,
    statement: StatementIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"defer" = .{
        .statement = statement,
    } });
}

pub fn newBranchStatement(
    self: *Ast,
    branch: lexemes.KeywordKind,
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .branch = .{
        .branch = branch,
        .label = label,
    } });
}

pub fn newForeignBlockStatement(
    self: *Ast,
    name: ?IdentifierIndex,
    body: StatementIndex,
    attributes: RefIndex, // std.ArrayList(FieldIndex),
) !StatementIndex {
    return try self.createStatement(.{ .foreign_block = .{
        .name = name,
        .body = body,
        .attributes = attributes,
    } });
}

pub fn newForeignImportStatement(
    self: *Ast,
    name: []const u8,
    sources: std.ArrayList([]const u8),
    attributes: RefIndex, // std.ArrayList(FieldIndex),
) !StatementIndex {
    return try self.createStatement(.{ .foreign_import = .{
        .name = name,
        .sources = sources,
        .attributes = attributes,
    } });
}

pub fn newUsingStatement(
    self: *Ast,
    list: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .using = .{
        .list = list,
    } });
}

pub fn newPackageStatement(
    self: *Ast,
    name: []const u8,
) !StatementIndex {
    return try self.createStatement(.{ .package = .{
        .name = name,
        .location = self.tokens.getLast().location,
    } });
}

pub fn newIdentifier(
    self: *Ast,
    contents: []const u8,
    poly: bool,
) !IdentifierIndex {
    const index = self.all.items.len;
    const set = try self.all.addOne(self.allocator);
    set.* = .{ .identifier = Identifier{
        .contents = contents,
        .poly = poly,
        .token = @intCast(self.tokens.items.len - 1),
    } };
    return @enumFromInt(index);
}

pub fn getIdentifier(self: *Ast, index: IdentifierIndex) *Identifier {
    return &self.all.items[@intFromEnum(index)].identifier;
}

pub fn getIdentifierConst(self: *const Ast, index: IdentifierIndex) *const Identifier {
    return &self.all.items[@intFromEnum(index)].identifier;
}

pub fn newCaseClause(
    self: *Ast,
    expression: ?ExpressionIndex,
    statements: RefIndex, // std.ArrayList(StatementIndex),
) !CaseClauseIndex {
    const index = self.all.items.len;
    const set = try self.all.addOne(self.allocator);
    set.* = .{ .case_clause = CaseClause{
        .expression = expression,
        .statements = statements,
    } };
    return @enumFromInt(index);
}

pub fn getCaseClause(self: *Ast, index: CaseClauseIndex) *CaseClause {
    return &self.all.items[@intFromEnum(index)].case_clause;
}

pub fn getCaseClauseConst(self: *const Ast, index: CaseClauseIndex) *const CaseClause {
    return &self.all.items[@intFromEnum(index)].case_clause;
}

pub fn newType(
    self: *Ast,
) !TypeIndex {
    return try self.createType(.{});
}

pub fn newBuiltinType(
    self: *Ast,
    identifier: []const u8,
    kind: BuiltinTypeKind,
    size: u16,
    alignof: u16,
    endianess: Endianess,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .builtin = .{
        .identifier = identifier,
        .kind = kind,
        .size = size,
        .alignof = alignof,
        .endianess = endianess,
    } } });
}

pub fn newPointerType(
    self: *Ast,
    ty: TypeIndex,
    is_const: bool,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .pointer = .{ .type = ty, .is_const = is_const } } });
}

pub fn newMultiPointerType(
    self: *Ast,
    ty: TypeIndex,
    is_const: bool,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .multi_pointer = .{ .type = ty, .is_const = is_const } } });
}

pub fn newSliceType(
    self: *Ast,
    ty: TypeIndex,
    is_const: bool,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .slice = .{ .type = ty, .is_const = is_const } } });
}

pub fn newArrayType(
    self: *Ast,
    ty: TypeIndex,
    count: ?ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .array = .{ .type = ty, .count = count } } });
}

pub fn newDynamicArrayType(
    self: *Ast,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .dynamic_array = .{ .type = ty } } });
}

pub fn newBitSetType(
    self: *Ast,
    underlying: ?TypeIndex,
    expression: ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .bit_set = .{ .underlying = underlying, .expression = expression } } });
}

pub fn newTypeidType(
    self: *Ast,
    specialisation: ?TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .typeid = .{ .specialisation = specialisation } } });
}

pub fn newMapType(
    self: *Ast,
    key: TypeIndex,
    value: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .map = .{ .key = key, .value = value } } });
}

pub fn newMatrixType(
    self: *Ast,
    rows: ExpressionIndex,
    columns: ExpressionIndex,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .matrix = .{ .rows = rows, .columns = columns, .type = ty } } });
}

pub fn newDistinctType(
    self: *Ast,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .distinct = .{ .type = ty } } });
}

pub fn newEnumType(
    self: *Ast,
    ty: ?TypeIndex,
    fields: RefIndex, // std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"enum" = .{ .type = ty, .fields = fields } } });
}

pub fn newConcreteStructType(
    self: *Ast,
    flags: StructFlags,
    @"align": ?ExpressionIndex,
    fields: RefIndex, // std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"struct" = .{
        .kind = StructKind.concrete,
        .flags = flags,
        .@"align" = @"align",
        .fields = fields,
        .where_clauses = where_clauses,
    } } });
}

pub fn newGenericStructType(
    self: *Ast,
    flags: StructFlags,
    @"align": ?ExpressionIndex,
    fields: RefIndex, // std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,
    parameters: RefIndex, // std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"struct" = .{
        .kind = StructKind.generic,
        .flags = flags,
        .@"align" = @"align",
        .fields = fields,
        .where_clauses = where_clauses,
        .parameters = parameters,
    } }, .poly = true });
}

pub fn newConcreteUnionType(
    self: *Ast,
    flags: UnionFlags,
    @"align": ?ExpressionIndex,
    variants: RefIndex, // std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"union" = .{
        .kind = UnionKind.concrete,
        .flags = flags,
        .@"align" = @"align",
        .variants = variants,
        .where_clauses = where_clauses,
    } } });
}

pub fn newGenericUnionType(
    self: *Ast,
    flags: UnionFlags,
    @"align": ?ExpressionIndex,
    variants: RefIndex, // std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,
    parameters: RefIndex, // std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"union" = .{
        .kind = UnionKind.generic,
        .flags = flags,
        .@"align" = @"align",
        .variants = variants,
        .where_clauses = where_clauses,
        .parameters = parameters,
    } }, .poly = true });
}

pub fn newPolyType(
    self: *Ast,
    base_type: TypeIndex,
    specialisation: ?TypeIndex,
) !TypeIndex {
    return try self.createType(.{
        .derived = .{ .poly = .{
            .type = base_type,
            .specialisation = specialisation,
        } },
    });
}

pub fn newExpressionType(
    self: *Ast,
    expression: ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .expression = .{
        .expression = expression,
    } } });
}

pub fn newConcreteProcedureType(
    self: *Ast,
    flags: ProcedureFlags,
    convention: CallingConvention,
    params: RefIndex, // std.ArrayList(FieldIndex),
    results: RefIndex, // std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .procedure = .{
        .kind = ProcedureKind.concrete,
        .flags = flags,
        .convention = convention,
        .params = params,
        .results = results,
    } } });
}

pub fn newGenericProcedureType(
    self: *Ast,
    flags: ProcedureFlags,
    convention: CallingConvention,
    params: RefIndex, // std.ArrayList(FieldIndex),
    results: RefIndex, // std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .procedure = .{
        .kind = ProcedureKind.generic,
        .flags = flags,
        .convention = convention,
        .params = params,
        .results = results,
    } } });
}

pub fn newField(
    self: *Ast,
    ty: ?TypeIndex,
    name: ?IdentifierIndex,
    value: ?ExpressionIndex,
    tag: ?[]const u8,
    flags: FieldFlags,
) !FieldIndex {
    const index = self.all.items.len;
    const set = try self.all.addOne(self.allocator);
    set.* = .{
        .field = Field{
            .type = ty,
            .name = name,
            .value = value,
            .tag = tag,
            .flags = flags,
            .attributes = RefIndex.none, // std.ArrayList(FieldIndex).init(self.allocator),
        },
    };
    return @enumFromInt(index);
}

pub fn getField(self: *Ast, index: FieldIndex) *Field {
    return &self.all.items[@intFromEnum(index)].field;
}

pub fn getFieldConst(self: *const Ast, index: FieldIndex) *const Field {
    return &self.all.items[@intFromEnum(index)].field;
}

pub fn recordToken(self: *Ast, token: lexer.Token) !void {
    try self.tokens.append(self.allocator, token);
}

pub fn addImport(self: *Ast, statement: StatementIndex) !void {
    try self.imports.append(self.allocator, statement);
}

test {
    std.testing.refAllDecls(@This());
}
