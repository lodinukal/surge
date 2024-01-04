const std = @import("std");

const Self = @This();

location: []const u8,
literal: []const u8,
kind: Kind,
pos: Pos,

pub const Pos = struct {
    location: []const u8,
    line: i32 = 1,
    column: i32 = 1,
    offset: i32 = 0,
};

pub const Kind = enum(i32) {
    invalid = -1,
    eof,
    comment,

    // literals
    identifier,
    integer,
    float,
    codepoint,
    str,
    uninit,

    // main operators
    eq,
    not,
    hash,
    at,
    dollar,
    pointer,
    add,
    sub,
    mul,
    div,
    mod,
    mod_mod,
    band,
    bor,
    bxor,
    band_not,
    bshl,
    bshr,
    @"and",
    @"or",

    // assignment operators
    add_eq,
    sub_eq,
    mul_eq,
    div_eq,
    mod_eq,
    mod_mod_eq,
    band_eq,
    bor_eq,
    bxor_eq,
    band_not_eq,
    bshl_eq,
    bshr_eq,

    // comparison operators
    eq_eq,
    not_eq,
    lt,
    gt,
    lt_eq,
    gt_eq,

    // other operators
    dot,
    dot_dot,
    open_paren,
    close_paren,
    open_bracket,
    close_bracket,
    open_brace,
    close_brace,
    comma,
    colon,
    semicolon,

    // keywords
    import,
    @"struct",
    @"enum",
    @"union",
    @"if",
    @"else",
    @"for",
    @"while",
    @"switch",
    @"inline",
    @"return",
    @"break",
    @"continue",
    @"defer",
    or_else,
    or_return,

    // allow custom keywords
    _,

    pub const keyword_start = @intFromEnum(Kind.or_return) + 1;

    pub inline fn name(kind: Kind) []const u8 {
        return switch (kind) {
            .invalid => "invalid",
            .eof => "eof",
            .comment => "comment",
            .identifier => "identifier",
            .integer => "integer",
            .float => "float",
            .codepoint => "codepoint",
            .str => "str",
            .uninit => "uninit",
            .eq => "=",
            .not => "!",
            .hash => "#",
            .at => "@",
            .dollar => "$",
            .pointer => "^",
            .add => "+",
            .sub => "-",
            .mul => "*",
            .div => "/",
            .mod => "%",
            .mod_mod => "%%",
            .band => "&",
            .bor => "|",
            .bxor => "^",
            .band_not => "~",
            .bshl => "<<",
            .bshr => ">>",
            .@"and" => "and",
            .@"or" => "or",
            .add_eq => "+=",
            .sub_eq => "-=",
            .mul_eq => "*=",
            .div_eq => "/=",
            .mod_eq => "%=",
            .mod_mod_eq => "%%=",
            .band_eq => "&=",
            .bor_eq => "|=",
            .bxor_eq => "^=",
            .band_not_eq => "~=",
            .bshl_eq => "<<=",
            .bshr_eq => ">>=",
            .eq_eq => "==",
            .not_eq => "!=",
            .lt => "<",
            .gt => ">",
            .lt_eq => "<=",
            .gt_eq => ">=",
            .dot => ".",
            .dot_dot => "..",
            .open_paren => "(",
            .close_paren => ")",
            .open_bracket => "[",
            .close_bracket => "]",
            .open_brace => "{",
            .close_brace => "}",
            .comma => ",",
            .colon => ":",
            .semicolon => ";",
            .import => "import",
            .@"struct" => "struct",
            .@"enum" => "enum",
            .@"union" => "union",
            .@"if" => "if",
            .@"else" => "else",
            .@"for" => "for",
            .@"while" => "while",
            .@"switch" => "switch",
            .@"inline" => "inline",
            .@"return" => "return",
            .@"break" => "break",
            .@"continue" => "continue",
            .@"defer" => "defer",
            .or_else => "or_else",
            .or_return => "or_return",

            else => "unknown",
        };
    }

    pub fn getKeywordMap(allocator: std.mem.Allocator) !std.StringArrayHashMap(i32) {
        var map = std.StringArrayHashMap(i32).init(allocator);
        const info = @typeInfo(Kind);
        inline for (info.Enum.fields) |field| {
            try map.put(field.name, @as(i32, field.value));
        }
        return map;
    }
};
