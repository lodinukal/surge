const std = @import("std");
const lexemes = @import("lexemes.zig");
const lexer = @import("lexer.zig");

pub const ExpressionIndex = usize;
pub const StatementIndex = usize;
pub const TypeIndex = usize;
pub const CaseClauseIndex = usize;
pub const IdentifierIndex = usize;
pub const FieldIndex = usize;

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
    expressions: std.ArrayList(ExpressionIndex),
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
    arguments: std.ArrayList(FieldIndex),
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
    fields: std.ArrayList(FieldIndex),
};

pub const IdentifierExpression = struct {
    identifier: IdentifierIndex,
};

pub const ContextExpression = struct {};
pub const UndefinedExpression = struct {};

pub const ProcedureGroupExpression = struct {
    expressions: std.ArrayList(ExpressionIndex),
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
    expression: ExpressionIndex,
};

pub const BlockStatement = struct {
    flags: BlockFlags,
    statements: std.ArrayList(StatementIndex),
    label: ?IdentifierIndex,
};

pub const AssignmentStatement = struct {
    assignment: lexemes.AssignmentKind,
    lhs: ExpressionIndex,
    rhs: ExpressionIndex,
};

pub const DeclarationStatement = struct {
    type: ?TypeIndex = null,
    names: std.ArrayList(IdentifierIndex),
    values: ?ExpressionIndex = null,
    attributes: std.ArrayList(FieldIndex),
    using: bool,
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
    clauses: std.ArrayList(CaseClauseIndex),
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
    attributes: std.ArrayList(FieldIndex),
};

pub const ForeignImportStatement = struct {
    name: []const u8,
    sources: std.ArrayList([]const u8),
    attributes: std.ArrayList(FieldIndex),
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
    params: std.ArrayList(FieldIndex),
    results: std.ArrayList(FieldIndex),
};

pub const PointerType = struct {
    type: TypeIndex,
};

pub const MultiPointerType = struct {
    type: TypeIndex,
};

pub const SliceType = struct {
    type: TypeIndex,
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
    fields: std.ArrayList(FieldIndex),
};

pub const ExpressionType = struct {
    expression: ExpressionIndex,
};

pub const StructType = struct {
    kind: StructKind,
    flags: StructFlags,
    @"align": ?ExpressionIndex,
    fields: std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,

    parameters: ?std.ArrayList(FieldIndex) = null,
};

pub const UnionType = struct {
    kind: UnionKind,
    flags: UnionFlags,
    @"align": ?ExpressionIndex,
    variants: std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,

    parameters: ?std.ArrayList(FieldIndex) = null,
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
    attributes: std.ArrayList(FieldIndex),
};

pub const CaseClause = struct {
    expression: ?ExpressionIndex = null,
    statements: std.ArrayList(StatementIndex),
};

const Tree = @This();
const Context = @import("Context.zig");

allocator: std.mem.Allocator = undefined,
context: ?*const Context = null,

source: lexer.Source = undefined,

imports: std.ArrayList(StatementIndex) = undefined,

tokens: std.ArrayList(lexer.Token) = undefined,
statements: std.ArrayList(StatementIndex) = undefined,

all_expressions: std.ArrayList(Expression) = undefined,
all_statements: std.ArrayList(Statement) = undefined,
all_types: std.ArrayList(Type) = undefined,
all_case_clauses: std.ArrayList(CaseClause) = undefined,
all_identifiers: std.ArrayList(Identifier) = undefined,
all_fields: std.ArrayList(Field) = undefined,

pub fn init(tree: *Tree, allocator: std.mem.Allocator, name: []const u8, context: ?*const Context) !void {
    tree.* = Tree{
        .allocator = allocator,
        .context = context,
        .source = lexer.Source{
            .name = name,
            .code = "",
        },
        .imports = std.ArrayList(StatementIndex).init(allocator),

        .tokens = std.ArrayList(lexer.Token).init(allocator),
        .statements = std.ArrayList(StatementIndex).init(allocator),

        .all_expressions = std.ArrayList(Expression).init(allocator),
        .all_statements = std.ArrayList(Statement).init(allocator),
        .all_types = std.ArrayList(Type).init(allocator),
        .all_case_clauses = std.ArrayList(CaseClause).init(allocator),
        .all_identifiers = std.ArrayList(Identifier).init(allocator),
        .all_fields = std.ArrayList(Field).init(allocator),
    };
}

pub fn deinit(self: *Tree) void {
    self.all_expressions.deinit();
    self.all_statements.deinit();
    self.all_types.deinit();
    self.all_case_clauses.deinit();
    self.all_identifiers.deinit();
    self.all_fields.deinit();

    self.tokens.deinit();
    self.statements.deinit();
    self.imports.deinit();
}

fn createExpression(self: *Tree, e: Expression) !ExpressionIndex {
    const index = self.all_expressions.items.len;
    const set = try self.all_expressions.addOne();
    set.* = e;
    return index;
}

pub fn getExpression(self: *Tree, index: ExpressionIndex) *Expression {
    return &self.all_expressions.items[index];
}

pub fn getExpressionConst(self: *const Tree, index: ExpressionIndex) *const Expression {
    return &self.all_expressions.items[index];
}

fn createStatement(self: *Tree, s: Statement) !StatementIndex {
    const index = self.all_statements.items.len;
    const set = try self.all_statements.addOne();
    set.* = s;
    return index;
}

pub fn getStatement(self: *Tree, index: StatementIndex) *Statement {
    return &self.all_statements.items[index];
}

pub fn getStatementConst(self: *const Tree, index: StatementIndex) *const Statement {
    return &self.all_statements.items[index];
}

fn createType(self: *Tree, t: Type) !TypeIndex {
    const index = self.all_types.items.len;
    const set = try self.all_types.addOne();
    set.* = t;
    return index;
}

pub fn getType(self: *Tree, index: TypeIndex) *Type {
    return &self.all_types.items[index];
}

pub fn getTypeConst(self: *const Tree, index: TypeIndex) *const Type {
    return &self.all_types.items[index];
}

/// consumes `expressions`
pub fn newTupleExpression(self: *Tree, expressions: std.ArrayList(ExpressionIndex)) !ExpressionIndex {
    return try self.createExpression(.{ .tuple = .{
        .expressions = expressions,
    } });
}

pub fn newUnaryExpression(
    self: *Tree,
    operation: lexemes.OperatorKind,
    operand: ExpressionIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .unary = .{
        .operation = operation,
        .operand = operand,
    } });
}

pub fn newBinaryExpression(
    self: *Tree,
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
    self: *Tree,
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
    self: *Tree,
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
    self: *Tree,
    operand: ?ExpressionIndex,
    field: IdentifierIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .selector = .{
        .operand = operand,
        .field = field,
    } });
}

pub fn newCallExpression(
    self: *Tree,
    operand: ExpressionIndex,
    arguments: std.ArrayList(FieldIndex),
) !ExpressionIndex {
    return try self.createExpression(.{ .call = .{
        .operand = operand,
        .arguments = arguments,
    } });
}

pub fn newUnwrapExpression(
    self: *Tree,
    operand: ExpressionIndex,
    item: ?IdentifierIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .unwrap = .{
        .operand = operand,
        .item = item,
    } });
}

pub fn newProcedureExpression(
    self: *Tree,
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

pub fn newTypeExpression(self: *Tree, ty: TypeIndex) !ExpressionIndex {
    return try self.createExpression(.{ .type = .{
        .type = ty,
    } });
}

pub fn newIndexExpression(
    self: *Tree,
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
    self: *Tree,
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
    self: *Tree,
    kind: lexemes.LiteralKind,
    value: []const u8,
) !ExpressionIndex {
    return try self.createExpression(.{ .literal = .{
        .kind = kind,
        .value = value,
    } });
}

pub fn newCompoundLiteralExpression(
    self: *Tree,
    ty: ?TypeIndex,
    fields: std.ArrayList(FieldIndex),
) !ExpressionIndex {
    return try self.createExpression(.{ .compound_literal = .{
        .type = ty,
        .fields = fields,
    } });
}

pub fn newIdentifierExpression(
    self: *Tree,
    identifier: IdentifierIndex,
) !ExpressionIndex {
    return try self.createExpression(.{ .identifier = .{
        .identifier = identifier,
    } });
}

pub fn newContextExpression(self: *Tree) !ExpressionIndex {
    return try self.createExpression(.context);
}

pub fn newUndefinedExpression(self: *Tree) !ExpressionIndex {
    return try self.createExpression(.undefined);
}

pub fn newProcedureGroupExpression(
    self: *Tree,
    expressions: std.ArrayList(ExpressionIndex),
) !ExpressionIndex {
    return try self.createExpression(.{ .procedure_group = .{
        .expressions = expressions,
    } });
}

pub fn newEmptyStatement(self: *Tree) !StatementIndex {
    return try self.createStatement(.empty);
}

pub fn newImportStatement(
    self: *Tree,
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
    self: *Tree,
    expression: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .expression = .{
        .expression = expression,
    } });
}

pub fn newBlockStatement(
    self: *Tree,
    flags: BlockFlags,
    statements: std.ArrayList(StatementIndex),
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .block = .{
        .flags = flags,
        .statements = statements,
        .label = label,
    } });
}

pub fn newAssignmentStatement(
    self: *Tree,
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
    self: *Tree,
    ty: ?TypeIndex,
    names: std.ArrayList(IdentifierIndex),
    values: ?ExpressionIndex,
    attributes: std.ArrayList(FieldIndex),
    using: bool,
) !StatementIndex {
    return try self.createStatement(.{ .declaration = .{
        .type = ty,
        .names = names,
        .values = values,
        .attributes = attributes,
        .using = using,
    } });
}

pub fn newIfStatement(
    self: *Tree,
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
    self: *Tree,
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
    self: *Tree,
    expression: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"return" = .{
        .expression = expression,
    } });
}

pub fn newForStatement(
    self: *Tree,
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
    self: *Tree,
    _init: ?StatementIndex,
    condition: ?ExpressionIndex,
    clauses: std.ArrayList(CaseClauseIndex),
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
    self: *Tree,
    statement: StatementIndex,
) !StatementIndex {
    return try self.createStatement(.{ .@"defer" = .{
        .statement = statement,
    } });
}

pub fn newBranchStatement(
    self: *Tree,
    branch: lexemes.KeywordKind,
    label: ?IdentifierIndex,
) !StatementIndex {
    return try self.createStatement(.{ .branch = .{
        .branch = branch,
        .label = label,
    } });
}

pub fn newForeignBlockStatement(
    self: *Tree,
    name: ?IdentifierIndex,
    body: StatementIndex,
    attributes: std.ArrayList(FieldIndex),
) !StatementIndex {
    return try self.createStatement(.{ .foreign_block = .{
        .name = name,
        .body = body,
        .attributes = attributes,
    } });
}

pub fn newForeignImportStatement(
    self: *Tree,
    name: []const u8,
    sources: std.ArrayList([]const u8),
    attributes: std.ArrayList(FieldIndex),
) !StatementIndex {
    return try self.createStatement(.{ .foreign_import = .{
        .name = name,
        .sources = sources,
        .attributes = attributes,
    } });
}

pub fn newUsingStatement(
    self: *Tree,
    list: ExpressionIndex,
) !StatementIndex {
    return try self.createStatement(.{ .using = .{
        .list = list,
    } });
}

pub fn newPackageStatement(
    self: *Tree,
    name: []const u8,
) !StatementIndex {
    return try self.createStatement(.{ .package = .{
        .name = name,
        .location = self.tokens.getLast().location,
    } });
}

pub fn newIdentifier(
    self: *Tree,
    contents: []const u8,
    poly: bool,
) !IdentifierIndex {
    const index = self.all_identifiers.items.len;
    const set = try self.all_identifiers.addOne();
    set.* = Identifier{
        .contents = contents,
        .poly = poly,
        .token = @intCast(self.tokens.items.len - 1),
    };
    return index;
}

pub fn getIdentifier(self: *Tree, index: IdentifierIndex) *Identifier {
    return &self.all_identifiers.items[index];
}

pub fn getIdentifierConst(self: *const Tree, index: IdentifierIndex) *const Identifier {
    return &self.all_identifiers.items[index];
}

pub fn newCaseClause(
    self: *Tree,
    expression: ?ExpressionIndex,
    statements: std.ArrayList(StatementIndex),
) !CaseClauseIndex {
    const index = self.all_case_clauses.items.len;
    const set = try self.all_case_clauses.addOne();
    set.* = CaseClause{
        .expression = expression,
        .statements = statements,
    };
    return index;
}

pub fn getCaseClause(self: *Tree, index: CaseClauseIndex) *CaseClause {
    return &self.all_case_clauses.items[index];
}

pub fn getCaseClauseConst(self: *const Tree, index: CaseClauseIndex) *const CaseClause {
    return &self.all_case_clauses.items[index];
}

pub fn newType(
    self: *Tree,
) !TypeIndex {
    return try self.createType(.{});
}

pub fn newPointerType(
    self: *Tree,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .pointer = .{ .type = ty } } });
}

pub fn newMultiPointerType(
    self: *Tree,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .multi_pointer = .{ .type = ty } } });
}

pub fn newSliceType(
    self: *Tree,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .slice = .{ .type = ty } } });
}

pub fn newArrayType(
    self: *Tree,
    ty: TypeIndex,
    count: ?ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .array = .{ .type = ty, .count = count } } });
}

pub fn newDynamicArrayType(
    self: *Tree,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .dynamic_array = .{ .type = ty } } });
}

pub fn newBitSetType(
    self: *Tree,
    underlying: ?TypeIndex,
    expression: ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .bit_set = .{ .underlying = underlying, .expression = expression } } });
}

pub fn newTypeidType(
    self: *Tree,
    specialisation: ?TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .typeid = .{ .specialisation = specialisation } } });
}

pub fn newMapType(
    self: *Tree,
    key: TypeIndex,
    value: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .map = .{ .key = key, .value = value } } });
}

pub fn newMatrixType(
    self: *Tree,
    rows: ExpressionIndex,
    columns: ExpressionIndex,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .matrix = .{ .rows = rows, .columns = columns, .type = ty } } });
}

pub fn newDistinctType(
    self: *Tree,
    ty: TypeIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .distinct = .{ .type = ty } } });
}

pub fn newEnumType(
    self: *Tree,
    ty: ?TypeIndex,
    fields: std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"enum" = .{ .type = ty, .fields = fields } } });
}

pub fn newConcreteStructType(
    self: *Tree,
    flags: StructFlags,
    @"align": ?ExpressionIndex,
    fields: std.ArrayList(FieldIndex),
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
    self: *Tree,
    flags: StructFlags,
    @"align": ?ExpressionIndex,
    fields: std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,
    parameters: std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"struct" = .{
        .kind = StructKind.generic,
        .flags = flags,
        .@"align" = @"align",
        .fields = fields,
        .where_clauses = where_clauses,
        .parameters = parameters,
    } } });
}

pub fn newConcreteUnionType(
    self: *Tree,
    flags: UnionFlags,
    @"align": ?ExpressionIndex,
    variants: std.ArrayList(FieldIndex),
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
    self: *Tree,
    flags: UnionFlags,
    @"align": ?ExpressionIndex,
    variants: std.ArrayList(FieldIndex),
    where_clauses: ?ExpressionIndex,
    parameters: std.ArrayList(FieldIndex),
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .@"union" = .{
        .kind = UnionKind.generic,
        .flags = flags,
        .@"align" = @"align",
        .variants = variants,
        .where_clauses = where_clauses,
        .parameters = parameters,
    } } });
}

pub fn newPolyType(
    self: *Tree,
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
    self: *Tree,
    expression: ExpressionIndex,
) !TypeIndex {
    return try self.createType(.{ .derived = .{ .expression = .{
        .expression = expression,
    } } });
}

pub fn newConcreteProcedureType(
    self: *Tree,
    flags: ProcedureFlags,
    convention: CallingConvention,
    params: std.ArrayList(FieldIndex),
    results: std.ArrayList(FieldIndex),
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
    self: *Tree,
    flags: ProcedureFlags,
    convention: CallingConvention,
    params: std.ArrayList(FieldIndex),
    results: std.ArrayList(FieldIndex),
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
    self: *Tree,
    ty: ?TypeIndex,
    name: ?IdentifierIndex,
    value: ?ExpressionIndex,
    tag: ?[]const u8,
    flags: FieldFlags,
) !FieldIndex {
    const index = self.all_fields.items.len;
    const set = try self.all_fields.addOne();
    set.* = Field{
        .type = ty,
        .name = name,
        .value = value,
        .tag = tag,
        .flags = flags,
        .attributes = std.ArrayList(FieldIndex).init(self.allocator),
    };
    return index;
}

pub fn getField(self: *Tree, index: FieldIndex) *Field {
    return &self.all_fields.items[index];
}

pub fn getFieldConst(self: *const Tree, index: FieldIndex) *const Field {
    return &self.all_fields.items[index];
}

pub fn recordToken(self: *Tree, token: lexer.Token) !void {
    try self.tokens.append(token);
}

test {
    std.testing.refAllDecls(@This());
}
