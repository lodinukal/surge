const std = @import("std");

const tokeniser = @import("tokeniser.zig");

pub const FunctionTags = packed struct(u4) {
    bounds_checked: bool = false,
    no_bounds_checked: bool = false,
    opt_ok: bool = false,
    opt_allocator_err: bool = false,
};

pub const FunctionInlining = enum {
    none,
    @"inline",
    no_online,
};

pub const NodeStateFlags = packed struct(u2) {
    bounds_checked: bool = false,
    no_bounds_checked: bool = false,
};

pub const Node = struct {
    pos: tokeniser.Token.Pos,
    end: tokeniser.Token.Pos,
    state_flags: NodeStateFlags,
    derived: AnyNode,
};

pub const CommentGroup = struct {
    node: Node,
    list: []tokeniser.Token,
};
pub const PackageKind = enum {
    normal,
    runtime,
    init,
};
pub const Package = struct {
    node: Node,
    kind: PackageKind,
    id: i32,
    name: []const u8,
    full_path: []const u8,
    files: std.StringArrayHashMap(File),
    user_data: ?*anyopaque,

    pub fn deinit(self: *Package) void {
        self.files.deinit();
    }
};
pub const File = struct {
    node: Node,
    id: i32,
    package: *Package,

    full_path: []const u8,
    source: []const u8,

    docs: *CommentGroup,
    package_declaration: *PackageDeclaration,
    package_token: tokeniser.Token,
    package_name: tokeniser.Token,

    declarations: std.ArrayList(*Statement),
    imports: std.ArrayList(*ImportDeclaration),
    directive_count: i32,

    comments: std.ArrayList(*CommentGroup),

    syntax_warning_count: i32,
    syntax_error_count: i32,

    pub fn deinit(self: *File) void {
        self.declarations.deinit();
        self.imports.deinit();
        self.comments.deinit();
    }
};

pub const Expression = struct {
    node: Node,
    expr: AnyExpression,

    pub fn unparen(self: *Expression) ?*Expression {
        var val: *Expression = self;
        while (true) {
            switch (val.expr) {
                .paren_expression => |pexp| val = pexp.expr,
                else => return val,
            }
        }
        return null;
    }

    pub fn stripOrReturn(self: *Expression) ?*Expression {
        var val: *Expression = self;
        while (true) {
            switch (val.expr) {
                inline .or_return_expression, .or_branch_expression, .paren_expression => |ore| val = ore.expr,
                else => return val,
            }
        }
        return null;
    }
};
pub const Statement = struct {
    node: Node,
    stmt: AnyStatement,
};
pub const Declaration = struct {
    statement: Statement,
};

pub const BadExpression = struct {
    expression: Expression,
};
pub const Identifier = struct {
    expression: Expression,
    name: []const u8,
};
pub const Implicit = struct {
    expression: Expression,
    token: tokeniser.Token,
};

pub const Undef = struct {
    expression: Expression,
    token_kind: tokeniser.Token.Kind,
};

pub const BasicLiteral = struct {
    expression: Expression,
    token: tokeniser.Token,
};
pub const BasicDirective = struct {
    expression: Expression,
    token: tokeniser.Token,
    name: []const u8,
};

pub const Ellipsis = struct {
    expression: Expression,
    token: tokeniser.Token,
    connected_expression: *Expression,
};

pub const FunctionLiteral = struct {
    expression: Expression,
    type: *FunctionType,
    body: *Statement,
    tags: FunctionTags,
    inlining: FunctionInlining,
    where_token: tokeniser.Token,
    where_clauses: []*Expression,
};

pub const CompLiteral = struct {
    expression: Expression,
    type: *Expression,
    open: tokeniser.Token.Pos,
    elems: []*Expression,
    close: tokeniser.Token.Pos,
    tag: *Expression,
};

pub const TagExpression = struct {
    expression: Expression,
    op: tokeniser.Token,
    name: []u8,
    expr: *Expression,
};

pub const UnaryExpression = struct {
    expression: Expression,
    op: tokeniser.Token,
    expr: *Expression,
};

pub const BinaryExpression = struct {
    expression: Expression,
    open: tokeniser.Token.Pos,
    expr: *Expression,
    close: tokeniser.Token.Pos,
};

pub const ParenExpression = struct {
    expression: Expression,
    open: tokeniser.Token.Pos,
    expr: *Expression,
    close: tokeniser.Token.Pos,
};

pub const SelectorExpression = struct {
    expression: Expression,
    expr: *Expression,
    op: tokeniser.Token,
    field: *Identifier,
};

pub const ImplicitSelectorExpression = struct {
    expression: Expression,
    field: *Identifier,
};

pub const SelectorCallExpression = struct {
    expression: Expression,
    expr: *Expression,
    call: *CallExpression,
    modified_call: bool,
};

pub const IndexExpression = struct {
    expression: Expression,
    expr: *Expression,
    open: tokeniser.Token.Pos,
    index: *Expression,
    close: tokeniser.Token.Pos,
};

pub const DerefExpression = struct {
    expression: Expression,
    expr: *Expression,
    op: tokeniser.Token,
};

pub const SliceExpression = struct {
    expression: Expression,
    expr: *Expression,
    open: tokeniser.Token.Pos,
    low: *Expression,
    interval: tokeniser.Token,
    high: *Expression,
    close: tokeniser.Token.Pos,
};

pub const CallExpression = struct {
    expression: Expression,
    inlining: FunctionInlining,
    expr: *Expression,
    open: tokeniser.Token.Pos,
    args: []*Expression,
    close: tokeniser.Token.Pos,
};

pub const FieldValue = struct {
    expression: Expression,
    field: *Expression,
    sep: tokeniser.Token,
    value: *Expression,
};

pub const TernaryIfExpression = struct {
    expression: Expression,
    x: *Expression,
    op1: tokeniser.Token,
    condition: *Expression,
    op2: tokeniser.Token,
    y: *Expression,
};

pub const OrElseExpression = struct {
    expression: Expression,
    x: *Expression,
    op: tokeniser.Token,
    y: *Expression,
};

pub const OrReturnExpression = struct {
    expression: Expression,
    expr: *Expression,
    op: tokeniser.Token,
};

pub const OrBranchExpression = struct {
    expression: Expression,
    expr: *Expression,
    token: tokeniser.Token,
    label: *Expression,
};

pub const TypeAssertion = struct {
    expression: Expression,
    expr: *Expression,
    dot: tokeniser.Token.Pos,
    open: tokeniser.Token.Pos,
    type: *Expression,
    close: tokeniser.Token.Pos,
};

pub const TypeCast = struct {
    expression: Expression,
    token: tokeniser.Token,
    open: tokeniser.Token.Pos,
    type: *Expression,
    close: tokeniser.Token.Pos,
    expr: *Expression,
};

pub const AutoCast = struct {
    expression: Expression,
    op: tokeniser.Token,
    expr: *Expression,
};

pub const BadStatement = struct {
    statement: Statement,
};
pub const EmptyStatement = struct {
    statement: Statement,
    semicolon: tokeniser.Token,
};
pub const ExpressionStatement = struct {
    statement: Statement,
    expr: *Expression,
};
pub const TagStatement = struct {
    statement: Statement,
    op: tokeniser.Token,
    name: []u8,
    stmt: *Statement,
};
pub const AssignStatement = struct {
    statement: Statement,
    left: *Expression,
    op: tokeniser.Token,
    right: *Expression,
};
pub const BlockStatement = struct {
    statement: Statement,
    open: tokeniser.Token.Pos,
    stmts: []*Statement,
    close: tokeniser.Token.Pos,
    uses_do: bool,
};
pub const IfStatement = struct {
    statement: Statement,
    label: *Expression,
    if_pos: tokeniser.Token.Pos,
    init: *Statement,
    condition: *Expression,
    body: *Statement,
    else_pos: tokeniser.Token.Pos,
    else_stmt: *Statement,
};
pub const WhenStatement = struct {
    statement: Statement,
    when_pos: tokeniser.Token.Pos,
    condition: *Expression,
    body: *Statement,
    else_stmt: *Statement,
};
pub const ReturnStatement = struct {
    statement: Statement,
    results: []*Expression,
};
pub const DeferStatement = struct {
    statement: Statement,
    stmt: *Statement,
};
pub const ForStatement = struct {
    statement: Statement,
    label: *Expression,
    for_pos: tokeniser.Token.Pos,
    init: *Statement,
    condition: *Expression,
    post: *Statement,
    body: *Statement,
};
pub const RangeStatement = struct {
    statement: Statement,
    label: *Expression,
    for_pos: tokeniser.Token.Pos,
    vals: []*Expression,
    in_pos: tokeniser.Token.Pos,
    expr: *Expression,
    body: *Statement,
    reverse: bool,
};
pub const InlineRangeStatement = struct {
    statement: Statement,
    label: *Expression,
    inline_pos: tokeniser.Token.Pos,
    for_pos: tokeniser.Token.Pos,
    val0: *Expression,
    val1: *Expression,
    in_pos: tokeniser.Token.Pos,
    expr: *Expression,
    body: *Statement,
};
pub const CaseClause = struct {
    statement: Statement,
    case_pos: tokeniser.Token.Pos,
    list: []*Expression,
    terminator: tokeniser.Token,
    body: []*Statement,
};
pub const SwitchStatement = struct {
    statement: Statement,
    label: *Expression,
    switch_pos: tokeniser.Token.Pos,
    init: *Statement,
    condition: *Expression,
    body: *Statement,
    partial: bool,
};
pub const TypeSwitchStatement = struct {
    statement: Statement,
    label: *Expression,
    switch_pos: tokeniser.Token.Pos,
    tag: *Expression,
    expr: *Expression,
    body: *Statement,
    partial: bool,
};
pub const BranchStatement = struct {
    statement: Statement,
    token: tokeniser.Token,
    label: *Expression,
};
pub const UsingStatement = struct {
    statement: Statement,
    list: []*Expression,
};

pub const BadDeclaration = struct {
    declaration: Declaration,
};
pub const ValueDeclaration = struct {
    declaration: Declaration,
    docs: *CommentGroup,
    attributes: std.ArrayList(*Attribute),
    names: []*Expression,
    type: *Expression,
    values: []*Expression,
    comment: *CommentGroup,
    is_using: bool,
    is_mutable: bool,

    pub fn deinit(self: *ValueDeclaration) void {
        self.attributes.deinit();
    }
};
pub const PackageDeclaration = struct {
    declaration: Declaration,
    docs: *CommentGroup,
    is_using: bool,
    import_token: tokeniser.Token,
    name: tokeniser.Token,
    relative_path: tokeniser.Token,
    full_path: []const u8,
    comment: *CommentGroup,
};
pub const ImportDeclaration = struct {
    declaration: Declaration,
    docs: *CommentGroup,
    is_using: bool,
    import_token: tokeniser.Token,
    name: tokeniser.Token,
    relative_path: tokeniser.Token,
    full_path: []const u8,
    comment: *CommentGroup,
};

pub const FieldFlag = enum {
    invalid,
    unknown,
    elipsis,
    using,
    no_alias,
    @"const",
    any_int,
    subtype,
    by_ptr,
    results,
    tags,
    default_paramters,
};
pub const FieldFlags = packed struct(u12) {
    invalid: bool = false,
    unknown: bool = false,
    elipsis: bool = false,
    using: bool = false,
    no_alias: bool = false,
    @"const": bool = false,
    any_int: bool = false,
    subtype: bool = false,
    by_ptr: bool = false,
    results: bool = false,
    tags: bool = false,
    default_paramters: bool = false,
};
pub const field_flag_strings = [@typeInfo(FieldFlag).Enum.fields.len][]const u8{
    "",
    "",
    "..",
    "using",
    "#noalias",
    "#const",
    "#any_int",
    "#subtype",
    "#by_ptr",
    "results",
    "field tag",
    "default parameters",
};

pub const struct_field_flags = FieldFlags{
    .using = true,
    .tags = true,
    .subtype = true,
};
pub const poly_params_field_flags = FieldFlags{
    .default_paramters = true,
};
pub const signature_field_flags = FieldFlags{
    .elipsis = true,
    .using = true,
    .no_alias = true,
    .@"const" = true,
    .any_int = true,
    .by_ptr = true,
    .default_paramters = true,
};
pub const signature_params_field_flags = blk: {
    const flags = signature_field_flags;
    break :blk flags;
};
pub const signature_results_field_flags = blk: {
    const flags = signature_field_flags;
    flags.results = true;
    break :blk flags;
};

pub const FunctionGroup = struct {
    expression: Expression,
    token: tokeniser.Token,
    open: tokeniser.Token.Pos,
    args: []*Expression,
    close: tokeniser.Token.Pos,
};

pub const Attribute = struct {
    node: Node,
    token_kind: tokeniser.Token.Kind,
    open: tokeniser.Token.Pos,
    elems: []*Expression,
    close: tokeniser.Token.Pos,
};

pub const Field = struct {
    node: Node,
    docs: *CommentGroup,
    names: []*Expression,
    type: *Expression,
    default_value: *Expression,
    tag: tokeniser.Token,
    flags: FieldFlags,
    comment: *CommentGroup,
};
pub const FieldList = struct {
    node: Node,
    open: tokeniser.Token.Pos,
    list: []*Field,
    close: tokeniser.Token.Pos,
};

pub const DistinctType = struct {
    expression: Expression,
    token_kind: tokeniser.Token.Kind,
    type: *Expression,
};
pub const PolymorphicType = struct {
    expression: Expression,
    dollar: tokeniser.Token,
    type: *Identifier,
    specialisation: *Expression,
};
pub const FunctionType = struct {
    expression: Expression,
    token: tokeniser.Token,
    params: *FieldList,
    arrow: tokeniser.Token.Pos,
    results: *FieldList,
    tags: FunctionTags,
    generic: bool,
    divering: bool,
};
pub const PointerType = struct {
    expression: Expression,
    tag: *Expression,
    pointer: tokeniser.Token,
    element: *Expression,
};
pub const MultiPointerType = struct {
    expression: Expression,
    open: tokeniser.Token.Pos,
    pointer: tokeniser.Token.Pos,
    close: tokeniser.Token.Pos,
    element: *Expression,
};
pub const ArrayType = struct {
    expression: Expression,
    open: tokeniser.Token.Pos,
    tag: *Expression,
    len: ?*Expression,
    close: tokeniser.Token.Pos,
    element: *Expression,
};
pub const DynamicArrayType = struct {
    expression: Expression,
    tag: *Expression,
    open: tokeniser.Token.Pos,
    dynamic_pos: tokeniser.Token.Pos,
    close: tokeniser.Token.Pos,
    element: *Expression,
};
pub const StructType = struct {
    expression: Expression,
    token_pos: tokeniser.Token.Pos,
    poly_params: *FieldList,
    alignment: *Expression,
    where_token: tokeniser.Token,
    where_clauses: []*Expression,
    is_packed: bool,
    is_raw_union: bool,
    is_no_copy: bool,
    fields: *FieldList,
    name_count: bool,
};
pub const UnionTypeKind = enum {
    normal,
    maybe,
    no_nil,
    shared_nil,
};
pub const UnionType = struct {
    expression: Expression,
    token_pos: tokeniser.Token.Pos,
    poly_params: *FieldList,
    alignment: *Expression,
    kind: UnionTypeKind,
    where_token: tokeniser.Token,
    where_clauses: []*Expression,
    variants: []*Expression,
};
pub const EnumType = struct {
    expression: Expression,
    token_pos: tokeniser.Token.Pos,
    base_type: *Expression,
    open: tokeniser.Token.Pos,
    fields: []*Expression,
    close: tokeniser.Token.Pos,
    is_using: bool,
};
pub const BitSetType = struct {
    expression: Expression,
    token_pos: tokeniser.Token.Pos,
    open: tokeniser.Token.Pos,
    element: *Expression,
    underlying: *Expression,
    close: tokeniser.Token.Pos,
};
pub const MapType = struct {
    expression: Expression,
    token_pos: tokeniser.Token.Pos,
    key: *Expression,
    value: *Expression,
};

pub const AnyNode = union {
    comment_group: *CommentGroup,

    bad_expression: *BadExpression,
    identifier: *Identifier,
    implicit: *Implicit,
    undef: *Undef,
    basic_literal: *BasicLiteral,
    basic_directive: *BasicDirective,
    ellipsis: *Ellipsis,
    function_literal: *FunctionLiteral,
    comp_literal: *CompLiteral,
    tag_expression: *TagExpression,
    unary_expression: *UnaryExpression,
    binary_expression: *BinaryExpression,
    paren_expression: *ParenExpression,
    selector_expression: *SelectorExpression,
    implicit_selector_expression: *ImplicitSelectorExpression,
    selector_call_expression: *SelectorCallExpression,
    index_expression: *IndexExpression,
    deref_expression: *DerefExpression,
    slice_expression: *SliceExpression,
    call_expression: *CallExpression,
    field_value: *FieldValue,
    ternary_if_expression: *TernaryIfExpression,
    or_else_expression: *OrElseExpression,
    or_return_expression: *OrReturnExpression,
    or_branch_expression: *OrBranchExpression,
    type_assertion: *TypeAssertion,
    type_cast: *TypeCast,
    auto_cast: *AutoCast,

    function_group: *FunctionGroup,

    distinct_type: *DistinctType,
    polymorphic_type: *PolymorphicType,
    function_type: *FunctionType,
    pointer_type: *PointerType,
    multi_pointer_type: *MultiPointerType,
    array_type: *ArrayType,
    dynamic_array_type: *DynamicArrayType,
    struct_type: *StructType,
    union_type: *UnionType,
    enum_type: *EnumType,
    bit_set_type: *BitSetType,
    map_type: *MapType,

    bad_statement: *BadStatement,
    empty_statement: *EmptyStatement,
    expression_statement: *ExpressionStatement,
    tag_statement: *TagStatement,
    assign_statement: *AssignStatement,
    block_statement: *BlockStatement,
    if_statement: *IfStatement,
    when_statement: *WhenStatement,
    return_statement: *ReturnStatement,
    defer_statement: *DeferStatement,
    for_statement: *ForStatement,
    range_statement: *RangeStatement,
    inline_range_statement: *InlineRangeStatement,
    case_clause: *CaseClause,
    switch_statement: *SwitchStatement,
    type_switch_statement: *TypeSwitchStatement,
    branch_statement: *BranchStatement,
    using_statement: *UsingStatement,

    bad_declaration: *BadDeclaration,
    value_declaration: *ValueDeclaration,
    package_declaration: *PackageDeclaration,
    import_declaration: *ImportDeclaration,

    attribute: *Attribute,
    field: *Field,
    field_list: *FieldList,
};

pub const AnyExpression = union {
    bad: *BadExpression,
    identifier: *Identifier,
    implicit: *Implicit,
    undef: *Undef,
    basic_literal: *BasicLiteral,
    basic_directive: *BasicDirective,
    ellipsis: *Ellipsis,
    function_literal: *FunctionLiteral,
    comp_literal: *CompLiteral,
    tag_expression: *TagExpression,
    unary_expression: *UnaryExpression,
    binary_expression: *BinaryExpression,
    paren_expression: *ParenExpression,
    selector_expression: *SelectorExpression,
    implicit_selector_expression: *ImplicitSelectorExpression,
    selector_call_expression: *SelectorCallExpression,
    index_expression: *IndexExpression,
    deref_expression: *DerefExpression,
    slice_expression: *SliceExpression,
    call_expression: *CallExpression,
    field_value: *FieldValue,
    ternary_if_expression: *TernaryIfExpression,
    or_else_expression: *OrElseExpression,
    or_return_expression: *OrReturnExpression,
    or_branch_expression: *OrBranchExpression,
    type_assertion: *TypeAssertion,
    type_cast: *TypeCast,
    auto_cast: *AutoCast,

    distinct_type: *DistinctType,
    polymorphic_type: *PolymorphicType,
    function_type: *FunctionType,
    pointer_type: *PointerType,
    multi_pointer_type: *MultiPointerType,
    array_type: *ArrayType,
    dynamic_array_type: *DynamicArrayType,
    struct_type: *StructType,
    union_type: *UnionType,
    enum_type: *EnumType,
    bit_set_type: *BitSetType,
    map_type: *MapType,
};

pub const AnyStatement = struct {
    bad: *BadStatement,
    empty: *EmptyStatement,
    expression: *ExpressionStatement,
    tag: *TagStatement,
    assign: *AssignStatement,
    block: *BlockStatement,
    @"if": *IfStatement,
    when: *WhenStatement,
    @"return": *ReturnStatement,
    @"defer": *DeferStatement,
    @"for": *ForStatement,
    range: *RangeStatement,
    inline_range: *InlineRangeStatement,
    case: *CaseClause,
    @"switch": *SwitchStatement,
    type_switch: *TypeSwitchStatement,
    branch: *BranchStatement,
    using: *UsingStatement,

    bad_declaration: *BadDeclaration,
    value_declaration: *ValueDeclaration,
    package_declaration: *PackageDeclaration,
    import_declaration: *ImportDeclaration,
};
