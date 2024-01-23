const std = @import("std");

// Token kinds
pub const TokenKind = enum {
    invalid,
    eof,
    comment,
    identifier,
    literal,
    operator,
    keyword,
    assignment,
    directive,
    attribute,
    @"const",
    semicolon,
    lbrace,
    rbrace,
    undefined,
};
pub const TokenInfo = struct {
    name: []const u8,
    asi: bool,
};
pub const tokens = std.EnumArray(TokenKind, TokenInfo).init(.{
    .invalid = .{ .name = "invalid", .asi = false },
    .eof = .{ .name = "end of file", .asi = false },
    .comment = .{ .name = "comment", .asi = false },
    .identifier = .{ .name = "identifier", .asi = true },
    .literal = .{ .name = "literal", .asi = true },
    .operator = .{ .name = "operator", .asi = false },
    .keyword = .{ .name = "keyword", .asi = false },
    .assignment = .{ .name = "assignment", .asi = false },
    .directive = .{ .name = "directive", .asi = false },
    .attribute = .{ .name = "attribute", .asi = false },
    .@"const" = .{ .name = "const", .asi = false },
    .semicolon = .{ .name = "semicolon", .asi = false },
    .lbrace = .{ .name = "left brace", .asi = false },
    .rbrace = .{ .name = "right brace", .asi = true },
    .undefined = .{ .name = "undefined", .asi = true },
});

// Assignment tokens.
pub const AssignmentKind = enum {
    eq,
    add,
    sub,
    mul,
    quo,
    mod,
    rem,
    @"and",
    @"or",
    xor,
    andnot,
    shl,
    shr,
    cmpand,
    cmpor,
};
pub const assignment_tokens = std.EnumArray(AssignmentKind, []const u8).init(.{
    .eq = "=",
    .add = "+=",
    .sub = "-=",
    .mul = "*=",
    .quo = "/=",
    .mod = "%=",
    .rem = "%%=",
    .@"and" = "&=",
    .@"or" = "|=",
    .xor = "~=",
    .andnot = "&~=",
    .shl = "<<=",
    .shr = ">>=",
    .cmpand = "&&=",
    .cmpor = "||=",
});

// Literal kinds
pub const LiteralKind = enum {
    integer,
    float,
    imaginary,
    codepoint,
    string,
};

// Operators
pub const OperatorKind = enum {
    not,
    pointer,
    arrow,
    lparen,
    rparen,
    lbracket,
    rbracket,
    colon,
    period,
    comma,
    in,
    not_in,
    auto_cast,
    cast,
    transmute,
    or_else,
    or_return,
    question,
    ellipsis,
    rangefull,
    rangehalf,
    cmpor,
    cmpand,
    cmpeq,
    noteq,
    lt,
    gt,
    lteq,
    gteq,
    add,
    sub,
    @"or",
    xor,
    quo,
    mul,
    mod,
    modmod,
    @"and",
    andnot,
    shl,
    shr,
};
pub const OperatorInfo = struct {
    name: []const u8,
    precedence: u8,
    named: bool,
    asi: bool,
};
pub const operators = std.EnumArray(OperatorKind, OperatorInfo).init(.{
    .not = .{ .name = "!", .precedence = 0, .named = false, .asi = false },
    .pointer = .{ .name = "^", .precedence = 0, .named = false, .asi = true },
    .arrow = .{ .name = "->", .precedence = 0, .named = false, .asi = false },
    .lparen = .{ .name = "(", .precedence = 0, .named = false, .asi = false },
    .rparen = .{ .name = ")", .precedence = 0, .named = false, .asi = true },
    .lbracket = .{ .name = "[", .precedence = 0, .named = false, .asi = false },
    .rbracket = .{ .name = "]", .precedence = 0, .named = false, .asi = true },
    .colon = .{ .name = ":", .precedence = 0, .named = false, .asi = false },
    .period = .{ .name = ".", .precedence = 0, .named = false, .asi = false },
    .comma = .{ .name = ",", .precedence = 0, .named = false, .asi = false },
    .in = .{ .name = "in", .precedence = 6, .named = true, .asi = false },
    .not_in = .{ .name = "not_in", .precedence = 6, .named = true, .asi = false },
    .auto_cast = .{ .name = "auto_cast", .precedence = 0, .named = true, .asi = false },
    .cast = .{ .name = "cast", .precedence = 0, .named = true, .asi = false },
    .transmute = .{ .name = "transmute", .precedence = 0, .named = true, .asi = false },
    .or_else = .{ .name = "or_else", .precedence = 1, .named = true, .asi = false },
    .or_return = .{ .name = "or_return", .precedence = 1, .named = true, .asi = true },
    .question = .{ .name = "?", .precedence = 1, .named = false, .asi = true },
    .ellipsis = .{ .name = "..", .precedence = 2, .named = false, .asi = false },
    .rangefull = .{ .name = "..=", .precedence = 2, .named = false, .asi = false },
    .rangehalf = .{ .name = "..<", .precedence = 2, .named = false, .asi = false },
    .cmpor = .{ .name = "||", .precedence = 3, .named = false, .asi = false },
    .cmpand = .{ .name = "&&", .precedence = 4, .named = false, .asi = false },
    .cmpeq = .{ .name = "==", .precedence = 5, .named = false, .asi = false },
    .noteq = .{ .name = "!=", .precedence = 5, .named = false, .asi = false },
    .lt = .{ .name = "<", .precedence = 5, .named = false, .asi = false },
    .gt = .{ .name = ">", .precedence = 5, .named = false, .asi = false },
    .lteq = .{ .name = "<=", .precedence = 5, .named = false, .asi = false },
    .gteq = .{ .name = ">=", .precedence = 5, .named = false, .asi = false },
    .add = .{ .name = "+", .precedence = 6, .named = false, .asi = false },
    .sub = .{ .name = "-", .precedence = 6, .named = false, .asi = false },
    .@"or" = .{ .name = "|", .precedence = 6, .named = false, .asi = false },
    .xor = .{ .name = "~", .precedence = 6, .named = false, .asi = false },
    .quo = .{ .name = "/", .precedence = 7, .named = false, .asi = false },
    .mul = .{ .name = "*", .precedence = 7, .named = false, .asi = false },
    .mod = .{ .name = "%", .precedence = 7, .named = false, .asi = false },
    .modmod = .{ .name = "%%", .precedence = 7, .named = false, .asi = false },
    .@"and" = .{ .name = "&", .precedence = 7, .named = false, .asi = false },
    .andnot = .{ .name = "&~", .precedence = 7, .named = false, .asi = false },
    .shl = .{ .name = "<<", .precedence = 7, .named = false, .asi = false },
    .shr = .{ .name = ">>", .precedence = 7, .named = false, .asi = false },
});
pub const named_operators = [_]OperatorKind{
    .in,
    .not_in,
    .auto_cast,
    .cast,
    .transmute,
    .or_else,
    .or_return,
};
pub inline fn operatorName(op: OperatorKind) []const u8 {
    return operators.get(op).name;
}

// Keywords
pub const KeywordKind = enum {
    import,
    foreign,
    package,
    typeid,
    where,
    when,
    @"if",
    @"else",
    @"for",
    @"switch",
    do,
    case,
    @"break",
    @"continue",
    fallthrough,
    @"defer",
    @"return",
    proc,
    @"struct",
    @"union",
    @"enum",
    bit_set,
    map,
    dynamic,
    distinct,
    using,
    context,
    @"asm",
    matrix,
};
pub const KeywordInfo = struct {
    match: []const u8,
    asi: bool,
};
pub const keywords = std.EnumArray(KeywordKind, KeywordInfo).init(.{
    .import = .{ .match = "import", .asi = false },
    .foreign = .{ .match = "foreign", .asi = false },
    .package = .{ .match = "package", .asi = false },
    .typeid = .{ .match = "typeid", .asi = true },
    .where = .{ .match = "where", .asi = false },
    .when = .{ .match = "when", .asi = false },
    .@"if" = .{ .match = "if", .asi = false },
    .@"else" = .{ .match = "else", .asi = false },
    .@"for" = .{ .match = "for", .asi = false },
    .@"switch" = .{ .match = "switch", .asi = false },
    .do = .{ .match = "do", .asi = false },
    .case = .{ .match = "case", .asi = false },
    .@"break" = .{ .match = "break", .asi = true },
    .@"continue" = .{ .match = "continue", .asi = true },
    .fallthrough = .{ .match = "fallthrough", .asi = true },
    .@"defer" = .{ .match = "defer", .asi = false },
    .@"return" = .{ .match = "return", .asi = true },
    .proc = .{ .match = "proc", .asi = false },
    .@"struct" = .{ .match = "struct", .asi = false },
    .@"union" = .{ .match = "union", .asi = false },
    .@"enum" = .{ .match = "enum", .asi = false },
    .bit_set = .{ .match = "bit_set", .asi = false },
    .map = .{ .match = "map", .asi = false },
    .dynamic = .{ .match = "dynamic", .asi = false },
    .distinct = .{ .match = "distinct", .asi = false },
    .using = .{ .match = "using", .asi = false },
    .context = .{ .match = "context", .asi = false },
    .@"asm" = .{ .match = "asm", .asi = false },
    .matrix = .{ .match = "matrix", .asi = false },
});

// Direcitves
pub const DirectiveKind = enum {
    optional_ok,
    optional_allocator_error,
    bounds_check,
    no_bounds_check,
    type_assert,
    no_type_assert,
    @"align",
    raw_union,
    @"packed",
    type,
    simd,
    soa,
    partial,
    sparse,
    force_inline,
    force_no_inline,
    no_nil,
    shared_nil,
    no_alias,
    c_vararg,
    any_int,
    subtype,
    by_ptr,
    assert,
    panic,
    unroll,
    location,
    procedure,
    load,
    load_hash,
    defined,
    config,
    maybe,
    caller_location,
    no_copy,
    @"const",
};

pub const AttributeKind = enum {
    @"test",
    @"export",
    require,
    init,
    deferred,
    deferred_none,
    deferred_in,
    deferred_out,
    deferred_in_out,
    deprecated,
    warning,
    require_results,
    disabled,
    cold,
    optimization_mode,
    static,
    thread_local,
    private,
};
pub const AttributeInfo = struct {
    match: []const u8,
    where: AttributeTag,
};

pub const attributes = std.EnumArray(AttributeKind, AttributeInfo).init(.{
    .@"test" = .{ .match = "test", .where = .{ .proc = true } },
    .@"export" = .{ .match = "export", .where = .{ .proc = true, .@"var" = true } },
    .require = .{ .match = "require", .where = .{ .proc = true, .@"var" = true } },
    .init = .{ .match = "init", .where = .{ .proc = true } },
    .deferred = .{ .match = "deferred", .where = .{ .proc = true } },
    .deferred_none = .{ .match = "deferred_none", .where = .{ .proc = true } },
    .deferred_in = .{ .match = "deferred_in", .where = .{ .proc = true } },
    .deferred_out = .{ .match = "deferred_out", .where = .{ .proc = true } },
    .deferred_in_out = .{ .match = "deferred_in_out", .where = .{ .proc = true } },
    .deprecated = .{ .match = "deprecated", .where = .{ .proc = true } },
    .warning = .{ .match = "warning", .where = .{ .proc = true } },
    .require_results = .{ .match = "require_results", .where = .{ .proc = true } },
    .disabled = .{ .match = "disabled", .where = .{ .proc = true } },
    .cold = .{ .match = "cold", .where = .{ .proc = true } },
    .optimization_mode = .{ .match = "optimization_mode", .where = .{ .proc = true } },
    .static = .{ .match = "static", .where = .{ .@"var" = true } },
    .thread_local = .{ .match = "thread_local", .where = .{ .@"var" = true } },
    .private = .{ .match = "private", .where = .{ .proc = true, .@"var" = true, .type = true } },
});

pub const AttributeTag = packed struct {
    proc: bool = false,
    @"var": bool = false,
    @"const": bool = false,
    type: bool = false,
};

pub const CallingConvention = enum {
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

test {
    std.testing.refAllDecls(@This());
}