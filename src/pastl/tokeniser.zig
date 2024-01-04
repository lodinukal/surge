const std = @import("std");

pub const Token = @import("Token.zig");

pub const ErrorHandler = *const fn (pos: Token.Pos, msg: []const u8) void;

pub const Tokeniser = struct {
    const codepoint = i32;
    allocator: std.mem.Allocator = undefined,
    location: []const u8 = "",
    source: []const u8 = "",
    err_handler: ?ErrorHandler = null,

    keyword_map: std.StringArrayHashMap(i32) = undefined,

    cp: codepoint = ' ',
    offset: i32 = 0,
    read_offset: i32 = 0,
    line_offset: i32 = 0,
    line_count: i32 = 1,

    error_count: i32 = 0,

    fn default_error_handler(pos: Token.Pos, msg: []const u8) void {
        std.debug.print("{s}:{}:{}: error: {s}\n", .{ pos.location, pos.line, pos.column, msg });
    }

    pub fn init(t: *Tokeniser, allocator: std.mem.Allocator, location: []const u8, source: []const u8, handler: ?ErrorHandler) !void {
        t.allocator = allocator;
        t.location = location;
        t.source = source;
        t.err_handler = handler orelse default_error_handler;

        t.keyword_map = try Token.Kind.getKeywordMap(allocator);

        t.line_count = if (source.len > 0) 1 else 0;

        t.advance();
    }

    pub fn deinit(t: *Tokeniser) void {
        t.keyword_map.deinit();
    }

    fn offsetToPos(t: *Tokeniser, offset: i32) Token.Pos {
        return Token.Pos{
            .location = t.location,
            .offset = offset,
            .line = t.line_count,
            .column = offset - t.line_offset + 1,
        };
    }

    inline fn err(t: *Tokeniser, offset: i32, msg: []const u8, args: anytype) void {
        var buf = std.mem.zeroes([1024]u8);
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const temp_allocator = fba.allocator();

        if (t.err_handler) |handler| {
            const fmtted = std.fmt.allocPrint(temp_allocator, msg, args) catch unreachable;
            handler(t.offsetToPos(offset), fmtted);
        }

        t.error_count += 1;
    }

    pub fn advance(t: *Tokeniser) void {
        if (t.read_offset < t.source.len) {
            t.offset = t.read_offset;
            if (t.cp == '\n') {
                t.line_offset = t.offset;
                t.line_count += 1;
            }
            var c: codepoint = t.source[@intCast(t.read_offset)];
            var width: u3 = 1;
            if (c == 0) {
                t.err(t.offset, "unexpected 0 codepoint", .{});
            } else if (!std.ascii.isASCII(@intCast(c))) {
                width = std.unicode.utf8ByteSequenceLength(@intCast(c)) catch blk: {
                    t.err(t.offset, "invalid utf8 start byte", .{});
                    break :blk 1;
                };
                c = std.unicode.utf8Decode(t.source[@intCast(t.read_offset)..][0..width]) catch blk: {
                    t.err(t.offset, "invalid utf8 sequence", .{});
                    break :blk t.source[@intCast(t.read_offset)];
                };
            }
            t.read_offset += width;
            t.cp = c;
        } else {
            t.offset = @intCast(t.source.len);
            if (t.cp == '\n') {
                t.line_offset = t.offset;
                t.line_count += 1;
            }
            t.cp = -1;
        }
    }

    pub fn peekCodepoint(t: *Tokeniser, offset: i32) ?codepoint {
        if (t.read_offset + offset < t.source.len) {
            return t.source[@intCast(t.read_offset + offset)];
        }
        return null;
    }

    pub fn skipWhitespace(t: *Tokeniser) void {
        while (true) {
            switch (t.cp) {
                ' ', '\t', '\r', '\n' => t.advance(),
                else => return,
            }
        }
    }

    pub fn isLetter(c: codepoint) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    pub fn isDigit(c: codepoint) bool {
        return c >= '0' and c <= '9';
    }

    pub fn scanComment(t: *Tokeniser) []const u8 {
        const offset: i32 = t.offset;
        if (t.cp == '/') {
            t.advance();
            while (t.cp != '\n' and t.cp >= 0) {
                t.advance();
            }
            t.advance();
        }

        return t.source[@intCast(offset)..@intCast(t.offset)];
    }

    pub fn scanIdentifier(t: *Tokeniser) []const u8 {
        const offset: i32 = t.offset;
        while (isLetter(t.cp) or isDigit(t.cp)) {
            t.advance();
        }
        return t.source[@intCast(offset)..@intCast(t.offset)];
    }

    pub fn scanString(t: *Tokeniser) []const u8 {
        const offset: i32 = t.offset - 1;
        while (true) {
            const cp = t.cp;
            if (cp == '\n' or cp < 0) {
                t.err(offset, "string literal was not terminated", .{});
                break;
            }
            t.advance();
            if (cp == '"') {
                break;
            }
            if (cp == '\\') {
                _ = t.scanEscape();
            }
        }
        return t.source[@intCast(offset)..@intCast(t.offset)];
    }

    pub fn scanRawString(t: *Tokeniser) []const u8 {
        const offset: i32 = t.offset - 1;
        while (true) {
            const cp = t.cp;
            if (cp == '\n' or cp < 0) {
                t.err(offset, "raw string literal was not terminated", .{});
                break;
            }
            t.advance();
            if (cp == '`') {
                break;
            }
        }
        return t.source[@intCast(offset)..@intCast(t.offset)];
    }

    fn digitValue(cp: codepoint) u32 {
        return switch (cp) {
            '0'...'9' => @intCast(cp - '0'),
            'a'...'f' => @intCast(cp - 'a' + 10),
            'A'...'F' => @intCast(cp - 'A' + 10),
            else => 16,
        };
    }

    pub fn scanEscape(t: *Tokeniser) ?[]const u8 {
        const offset: i32 = t.offset;

        var n: i32 = 0;
        var base: u32 = 0;
        var max: u32 = 0;

        switch (t.cp) {
            'a', 'b', 'f', 'n', 'r', 't', 'v', '\\', '"', '\'' => {
                t.advance();
                return t.source[@intCast(offset)..@intCast(t.offset)];
            },
            '0'...'7' => {
                n = 3;
                base = 8;
                max = 255;
            },
            'x' => {
                n = 2;
                base = 16;
                max = 255;
            },
            'u' => {
                std.debug.print("unicode escape sequences are not yet supported\n", .{});
                n = 4;
                base = 16;
                max = '\u{0001ffff}';
            },
            'U' => {
                n = 8;
                base = 16;
                max = '\u{0010ffff}';
            },
            else => {
                if (t.cp == 0) {
                    t.err(offset, "escape sequence was not terminated", .{});
                } else {
                    t.err(offset, "unknown escape sequence", .{});
                }
                return null;
            },
        }

        var total: u32 = 0;
        while (n > 0) : (n -= 1) {
            const digit_value = digitValue(t.cp);
            if (digit_value >= base) {
                if (t.cp == 0) {
                    t.err(offset, "escape sequence was not terminated", .{});
                } else {
                    t.err(offset, "invalid character {} in escape sequence", .{t.cp});
                }
                return null;
            }

            total = total * base + digit_value;
            t.advance();
        }

        if (total > max or (total >= 0xD800 and total <= 0xDFFF)) {
            t.err(offset, "escape sequence is out of range", .{});
            return null;
        }

        return "";
    }

    pub fn scanCodepoint(t: *Tokeniser) []const u8 {
        const offset: i32 = t.offset - 1;

        var valid: bool = true;
        var n: codepoint = 0;
        while (true) {
            if (t.cp == '\n' or t.cp == 0) {
                if (valid) {
                    t.err(offset, "codepoint literal was not terminated", .{});
                    valid = false;
                }
                break;
            }
            t.advance();
            if (t.cp == '\'') {
                break;
            }
            n += 1;
            if (t.cp == '\\') {
                if (t.scanEscape() == null) {
                    valid = false;
                }
            }
        }

        if (valid and n != 1) {
            t.err(offset, "codepoint literal must contain exactly one codepoint {}", .{n});
        }

        return t.source[@intCast(offset)..@intCast(t.offset)];
    }

    fn scanMantissa(t: *Tokeniser, base: i32) void {
        while (digitValue(t.cp) < base or t.cp == '_') {
            t.advance();
        }
    }

    fn scanExponent(t: *Tokeniser) void {
        if (t.cp == 'e' or t.cp == 'E') {
            t.advance();
            if (t.cp == '+' or t.cp == '-') {
                t.advance();
            }
            if (digitValue(t.cp) < 10) {
                t.scanMantissa(10);
            } else {
                t.err(t.offset, "illegal floating point exponent", .{});
            }
        }
    }

    fn scanFraction(t: *Tokeniser, kind: *Token.Kind) bool {
        if (t.cp == '.' and t.peekCodepoint(0) == '.') {
            return true;
        }
        if (t.cp == '.') {
            kind.* = .float;
            t.advance();
            t.scanMantissa(10);
        }
        return false;
    }

    fn intBase(t: *Tokeniser, base: i32) bool {
        const prev = t.offset;
        t.advance();
        t.scanMantissa(base);
        return !(t.offset - prev <= 1);
    }

    pub fn scanNumber(t: *Tokeniser, decimal_seen: bool) struct { Token.Kind, []const u8 } {
        var offset: i32 = t.offset;
        var kind: Token.Kind = .integer;
        var point_seen: bool = decimal_seen;

        if (point_seen) {
            offset -= 1;
            kind = .float;
            t.scanMantissa(10);
            t.scanExponent();
        } else {
            if (t.cp == '0') {
                t.advance();
                const invalid = switch (t.cp) {
                    'b' => t.intBase(2),
                    'o' => t.intBase(8),
                    'x' => t.intBase(16),
                    else => {
                        point_seen = false;
                        t.scanMantissa(10);
                        if (t.cp == '.') {
                            point_seen = true;
                            if (t.scanFraction(&kind)) {
                                return .{ kind, t.source[@intCast(offset)..@intCast(t.offset)] };
                            }
                        }
                        t.scanExponent();
                        return .{ kind, t.source[@intCast(offset)..@intCast(t.offset)] };
                    },
                };
                if (invalid) {
                    t.err(offset, "illegal float literal", .{});
                }
            }
        }

        t.scanMantissa(10);

        if (t.scanFraction(&kind)) {
            return .{ kind, t.source[@intCast(offset)..@intCast(t.offset)] };
        }
        t.scanExponent();
        return .{ kind, t.source[@intCast(offset)..@intCast(t.offset)] };
    }

    pub fn scan(t: *Tokeniser) Token {
        t.skipWhitespace();

        const offset: i32 = t.offset;
        var kind: Token.Kind = .invalid;
        var literal: []const u8 = "";
        const pos = t.offsetToPos(offset);

        const cp = t.cp;
        if (isLetter(cp)) {
            literal = t.scanIdentifier();
            kind = .identifier;
            if (t.keyword_map.get(literal)) |keyword| {
                kind = @enumFromInt(keyword);
            }
        } else if ('0' <= cp and cp <= '9') {
            kind, literal = t.scanNumber(false);
        } else {
            t.advance();
            switch (t.cp) {
                -1 => {
                    kind = .eof;
                },
                '\n' => {
                    kind = .semicolon;
                    literal = "\n";
                },
                '\'' => {
                    kind = .codepoint;
                    literal = t.scanCodepoint();
                },
                '"' => {
                    kind = .str;
                    literal = t.scanString();
                },
                '`' => {
                    kind = .str;
                    literal = t.scanRawString();
                },
                '.' => {
                    kind = .dot;
                    switch (t.cp) {
                        '0'...'9' => {
                            kind, literal = t.scanNumber(true);
                        },
                        '.' => {
                            kind = .dot_dot;
                        },
                        else => {},
                    }
                },
                '@' => {
                    kind = .at;
                },
                ',' => {
                    kind = .comma;
                },
                '$' => {
                    kind = .dollar;
                },
                '(' => {
                    kind = .open_paren;
                },
                ')' => {
                    kind = .close_paren;
                },
                '[' => {
                    kind = .open_bracket;
                },
                ']' => {
                    kind = .close_bracket;
                },
                '{' => {
                    kind = .open_brace;
                },
                '}' => {
                    kind = .close_brace;
                },
                ':' => {
                    kind = .colon;
                },
                ';' => {
                    kind = .semicolon;
                },
                '%' => {
                    kind = .mod;
                    switch (t.cp) {
                        '=' => {
                            t.advance();
                            kind = .mod_eq;
                        },
                        '%' => {
                            t.advance();
                            kind = .mod_mod;
                            if (t.cp == '=') {
                                t.advance();
                                kind = .mod_mod_eq;
                            }
                        },
                        else => {},
                    }
                },
                '*' => {
                    kind = .mul;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .mul_eq;
                    }
                },
                '/' => {
                    kind = .div;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .div_eq;
                    } else if (t.cp == '/') {
                        literal = t.scanComment();
                        kind = .comment;
                    }
                },
                '+' => {
                    kind = .add;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .add_eq;
                    }
                },
                '-' => {
                    kind = .sub;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .sub_eq;
                    }
                },
                '~' => {
                    kind = .bxor;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .bxor_eq;
                    }
                },
                '!' => {
                    kind = .not;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .not_eq;
                    }
                },
                '#' => {
                    kind = .hash;
                },
                '<' => {
                    kind = .lt;
                    switch (t.cp) {
                        '=' => {
                            t.advance();
                            kind = .lt_eq;
                        },
                        '<' => {
                            t.advance();
                            kind = .bshl;
                            if (t.cp == '=') {
                                t.advance();
                                kind = .bshl_eq;
                            }
                        },
                        else => {},
                    }
                },
                '>' => {
                    kind = .gt;
                    switch (t.cp) {
                        '=' => {
                            t.advance();
                            kind = .gt_eq;
                        },
                        '>' => {
                            t.advance();
                            kind = .bshr;
                            if (t.cp == '=') {
                                t.advance();
                                kind = .bshr_eq;
                            }
                        },
                        else => {},
                    }
                },
                '&' => {
                    kind = .band;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .band_eq;
                    }
                },
                '|' => {
                    kind = .bor;
                    if (t.cp == '=') {
                        t.advance();
                        kind = .bor_eq;
                    }
                },
                else => |c| {
                    t.err(offset, "illegal character {}", .{c});
                    kind = .invalid;
                },
            }
        }

        if (literal.len == 0) {
            literal = t.source[@intCast(offset)..@intCast(t.offset)];
        }

        return Token{
            .location = t.location,
            .kind = kind,
            .literal = literal,
            .pos = pos,
        };
    }
};
