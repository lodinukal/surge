const std = @import("std");
const lexemes = @import("lexemes.zig");

pub const codepoint = u21;

pub const Source = struct {
    name: []const u8,
    code: []const u8,
};

pub const Location = struct {
    column: i32,
    line: i32,
};

pub const Token = struct {
    location: Location,
    string: []const u8,
    un: union(lexemes.TokenKind) {
        invalid,
        eof,
        comment,
        identifier,
        literal: lexemes.LiteralKind,
        operator: lexemes.OperatorKind,
        keyword: lexemes.KeywordKind,
        assignment: lexemes.AssignmentKind,
        directive: lexemes.DirectiveKind,
        attribute,
        @"const",
        semicolon,
        lbrace,
        rbrace,
        undefined,
    },
};
pub const NullToken = Token{
    .location = Location{
        .column = 0,
        .line = 0,
    },
    .string = "",
    .un = .invalid,
};

pub const Input = struct {
    source: *const Source,
    current: usize,
    end: usize,
};

pub const Lexer = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    err_handler: ?*const fn (msg: []const u8) void = null,

    input: Input,
    this_location: Location,
    last_location: Location,
    here: usize,
    codepoint: codepoint,
    asi: bool,
    peek: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, source: *const Source) !Lexer {
        if (source.code.len == 0) return error.LexerEmptySource;

        var lexer = Lexer{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .allocator = undefined,
            .input = Input{
                .source = source,
                .current = 0,
                .end = source.code.len,
            },
            .this_location = Location{
                .column = 0,
                .line = 0,
            },
            .last_location = Location{
                .column = 0,
                .line = 0,
            },
            .here = 0,
            .codepoint = 0,
            .asi = false,
            .peek = std.ArrayList(Token).init(allocator),
        };
        lexer.advance();

        return lexer;
    }

    pub fn deinit(self: *Lexer) void {
        self.arena.deinit();
    }

    pub fn next(self: *Lexer) Token {
        if (self.peek.items.len != 0) {
            const token = self.peek.items[0];
            self.peek.orderedRemove(0);
            return token;
        }
        return self.rawNext();
    }

    pub fn peek(self: *Lexer) !Token {
        try self.peek.append(self.rawNext());
        return self.peek.getLast();
    }

    fn err(self: *Lexer, msg: []const u8, args: anytype) void {
        var buf = std.mem.zeroes([1024]u8);
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const temp_allocator = fba.allocator();

        if (self.err_handler) |handler| {
            const fmtted = std.fmt.allocPrint(temp_allocator, msg, args) catch unreachable;
            handler.*(fmtted);
        }
    }

    fn _peek(self: *Lexer) u8 {
        return if (self.input.current < self.input.end) self.input.source.code[self.input.current] else 0;
    }

    fn advance(self: *Lexer) codepoint {
        if (self.codepoint == '\n') {
            self.this_location.column = 0;
            self.this_location.line += 1;
        }
        const input = &self.input;
        if (input.current < input.end) {
            self.here = input.current;
            const char = input.source.code[input.current];
            var result: codepoint = @intCast(char);
            if (char == 0) {
                self.err("unexpected eof", .{});
                input.current += 1;
            } else if (char & 0x80 != 0) {
                const width = std.unicode.utf8ByteSequenceLength(char) catch blk: {
                    self.err("invalid utf8 start byte", .{});
                    break :blk 1;
                };
                result = std.unicode.utf8Decode(input.source.code[input.current..][0..width]) catch blk: {
                    self.err("invalid utf8 sequence", .{});
                    break :blk char;
                };
                input.current += 1;
            } else {
                input.current += 1;
            }
            self.codepoint = result;
            self.this_location.column += 1;
        } else {
            self.here = input.end;
            self.codepoint = 0;
        }
    }

    fn skipLine(self: *Lexer) void {
        while (self.codepoint != '\n' and self.codepoint != 0) {
            _ = self.advance();
        }
    }

    fn skipWhitespace(self: *Lexer, newline: bool) void {
        while (true) {
            switch (self.codepoint) {
                ' ', '\t', '\r' => _ = self.advance(),
                '\n' => {
                    if (!newline) {
                        _ = self.advance();
                    } else {
                        break;
                    }
                },
                else => break,
            }
        }
    }

    fn scan(self: *Lexer, base: i32) void {
        while (numericBase(self.codepoint) < base or self.codepoint == '_') {
            _ = self.advance();
        }
    }

    inline fn tokenHalf(
        self: *const Lexer,
    ) Token {
        return Token{ .location = self.last_location, .string = "", .un = .undefined };
    }

    inline fn tokenVoid(
        self: *const Lexer,
        kind: lexemes.TokenKind,
    ) Token {
        var token = self.tokenHalf();
        token.un = @field(lexemes.TokenKind, @tagName(kind));
        return token;
    }

    inline fn tokenOperator(
        self: *const Lexer,
        kind: lexemes.OperatorKind,
    ) Token {
        var token = self.tokenHalf();
        token.un = .{ .operator = kind };
        return token;
    }

    inline fn tokenAssignment(
        self: *const Lexer,
        kind: lexemes.AssignmentKind,
    ) Token {
        var token = self.tokenHalf();
        token.un = .{ .assignment = kind };
        return token;
    }

    fn scanNumeric(self: *Lexer, dot: bool) Token {
        var token = self.tokenHalf();
        token.string = self.input.source.code[self.here..][0..1];
        token.un = .{ .literal = .integer };
        const old_here = self.here;

        blk: {
            if (dot) {
                token.un = .{ .literal = .float };
                token.string = self.input.source.code[self.here - 1 ..][0..2];
                token.location.column -= 1;
                self.scan(10);
                break :blk;
            }

            if (self.codepoint == '0') {
                switch (self.advance()) {
                    'b' => {
                        _ = self.advance();
                        self.scan(2);
                    },
                    'o' => {
                        _ = self.advance();
                        self.scan(8);
                    },
                    'x' => {
                        _ = self.advance();
                        self.scan(16);
                    },
                    else => {},
                }
            }

            self.scan(10);

            if (self.codepoint == '.') {
                if (self._peek() == '.') {
                    token.string = self.input.source.code[self.here..][0 .. self.here - old_here];
                    return token;
                }

                _ = self.advance();
                token.un = .{ .literal = .float };
                self.scan(10);
            }
        }

        if (self.codepoint == 'e' or self.codepoint == 'E') {
            _ = self.advance();
            token.un = .{ .literal = .float };
            if (self.codepoint == '+' or self.codepoint == '-') {
                _ = self.advance();
            }
            self.scan(10);
        }

        if (self.codepoint == 'i' or self.codepoint == 'j' or self.codepoint == 'k') {
            _ = self.advance();
            token.un = .{ .literal = .imaginary };
        }

        token.string.len = self.here - old_here;
        return token;
    }

    fn scanEscape(self: *Lexer) bool {
        switch (self.codepoint) {
            'a', 'b', 'f', 'n', 'r', 't', 'v', '\\', '\'', '"' => {
                _ = self.advance();
                return true;
            },
            'x' => {
                _ = self.advance();
                for (0..2) |_| {
                    _ = self.advance();
                }
                return true;
            },
            'u' => {
                _ = self.advance();
                for (0..4) |_| {
                    _ = self.advance();
                }
                return true;
            },
            'U' => {
                _ = self.advance();
                for (0..8) |_| {
                    _ = self.advance();
                }
                return true;
            },
            else => {
                if (isDigit(self.codepoint)) {
                    for (0..3) |_| {
                        _ = self.advance();
                    }
                    return true;
                } else {
                    self.err("invalid escape sequence {}", .{self.codepoint});
                }
            },
        }
    }

    fn tokenise(self: *Lexer) Token {
        self.skipWhitespace(self.asi);

        self.last_location = self.this_location;

        var token = self.tokenHalf();
        token.string = self.input.source.code[self.here..][0..1];

        const cp = self.codepoint;
        if (isChar(cp)) {
            token.un = .identifier;
            const old_here = self.here;
            while (isChar(self.codepoint) or isDigit(self.codepoint)) {
                _ = self.advance();
            }
            token.string.len = self.here - old_here;

            if (findKeyword(token.string)) |kw| {
                token.un = .{ .keyword = kw };
            }
            if (findOperator(token.string)) |op| {
                token.un = .{ .operator = op };
            }
            return token;
        } else if (isDigit(cp)) {
            return self.scanNumeric(false);
        }

        _ = self.advance();

        const old_here = self.here;
        switch (cp) {
            0 => {
                token.un = .eof;
                if (self.asi) {
                    self.asi = false;
                    token.string = "\n";
                    token.un = .semicolon;
                }
                return token;
            },
            '\n' => {
                self.asi = false;
                token.string = "\n";
                token.un = .semicolon;
                return token;
            },
            '\\' => {
                self.asi = false;
                return self.tokenise();
            },
            '\'' => {
                token.un = .{ .literal = .codepoint };
                while (true) {
                    const c = self.codepoint;
                    if (c == '\n') {
                        self.err("unexpected newline in codepoint literal", .{});
                    }
                    _ = self.advance();
                    if (c == '\'') {
                        break;
                    }
                    if (c == '\\' and !self.scanEscape()) {
                        self.err("malformed escape sequence in codepoint literal", .{});
                    }
                }
                token.string.len = self.here - old_here;
            },
            '`', '"' => {
                const quote = cp;
                while (true) {
                    const c = self.codepoint;
                    if (c == '\n') {
                        self.err("unexpected newline in string literal", .{});
                    }
                    _ = self.advance();
                    if (c == quote) {
                        break;
                    }
                    if (cp == '"' and (c == '\\' and !self.scanEscape())) {
                        self.err("malformed escape sequence in string literal", .{});
                    }
                }
                token.un = .{ .literal = .string };
                token.string.len = self.here - old_here;
            },
            '.' => {
                if (isDigit(self.codepoint)) {
                    return self.scanNumeric(true);
                } else if (self.codepoint == '.') {
                    switch (self.advance()) {
                        '<' => {
                            _ = self.advance();
                            return self.tokenOperator(.rangehalf);
                        },
                        '=' => {
                            _ = self.advance();
                            return self.tokenOperator(.rangefull);
                        },
                        else => {
                            return self.tokenOperator(.ellipsis);
                        },
                    }
                } else {
                    return self.tokenOperator(.period);
                }
            },
            '{' => return self.tokenVoid(.lbrace),
            '}' => return self.tokenVoid(.rbrace),
            ';' => return self.tokenVoid(.semicolon),
            '@' => return self.tokenVoid(.attribute),
            '$' => return self.tokenVoid(.@"const"),
            '?' => return self.tokenOperator(.question),
            '^' => return self.tokenOperator(.pointer),
            ',' => return self.tokenOperator(.comma),
            ':' => return self.tokenOperator(.colon),
            '(' => return self.tokenOperator(.lparen),
            ')' => return self.tokenOperator(.rparen),
            '[' => return self.tokenOperator(.lbracket),
            ']' => return self.tokenOperator(.rbracket),
            '%' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenAssignment(.mod);
                    },
                    '%' => {
                        if (self.advance() == '=') {
                            _ = self.advance();
                            return self.tokenAssignment(.rem);
                        }
                        return self.tokenOperator(.modmod);
                    },
                    else => return self.tokenOperator(.mod),
                }
            },
            '*' => {
                if (self.codepoint == '=') {
                    _ = self.advance();
                    return self.tokenAssignment(.mul);
                } else {
                    return self.tokenOperator(.mul);
                }
            },
            '=' => {
                if (self.codepoint == '=') {
                    _ = self.advance();
                    return self.tokenOperator(.cmpeq);
                } else {
                    return self.tokenAssignment(.eq);
                }
            },
            '~' => {
                if (self.codepoint == '=') {
                    _ = self.advance();
                    return self.tokenAssignment(.xor);
                } else {
                    return self.tokenOperator(.not);
                }
            },
            '!' => {
                if (self.codepoint == '=') {
                    _ = self.advance();
                    return self.tokenOperator(.noteq);
                } else {
                    return self.tokenOperator(.not);
                }
            },
            '+' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenAssignment(.add);
                    },
                    '+' => {
                        self.err("increment operator not supported", .{});
                    },
                    else => return self.tokenOperator(.add),
                }
            },
            '-' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenAssignment(.sub);
                    },
                    '-' => {
                        if (self.advance() == '-') {
                            _ = self.advance();
                            return self.tokenVoid(.undefined);
                        } else {
                            self.err("decrement operator not supported", .{});
                        }
                    },
                    '>' => {
                        _ = self.advance();
                        return self.tokenOperator(.arrow);
                    },
                    else => return self.tokenOperator(.sub),
                }
            },
            '#' => {
                while (isChar(self.codepoint)) {
                    _ = self.advance();
                }
                token.string = token.string[1..];
                token.string.len = self.here - old_here;
                if (findDirective(token.string)) |dir| {
                    token.un = .{ .directive = dir };
                } else {
                    self.err("unknown directive {}", .{token.string});
                }
                return token;
            },
            '/' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenAssignment(.quo);
                    },
                    '/' => {
                        self.skipLine();
                        return self.tokenVoid(.comment);
                    },
                    '*' => {
                        _ = self.advance();
                        var depth: u32 = 1;
                        while (depth > 0) {
                            switch (self.codepoint) {
                                0 => return self.tokenVoid(.eof),
                                '/' => {
                                    if (self.advance() == '*') {
                                        _ = self.advance();
                                        depth += 1;
                                    }
                                },
                                '*' => {
                                    if (self.advance() == '/') {
                                        _ = self.advance();
                                        depth -= 1;
                                    }
                                },
                                else => _ = self.advance(),
                            }
                        }
                        return self.tokenVoid(.comment);
                    },
                    else => return self.tokenOperator(.quo),
                }
            },
            '<' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenOperator(.lteq);
                    },
                    '<' => {
                        if (self.advance() == '=') {
                            _ = self.advance();
                            return self.tokenAssignment(.shl);
                        }
                        return self.tokenOperator(.shl);
                    },
                    else => return self.tokenOperator(.lt),
                }
            },
            '>' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenOperator(.gteq);
                    },
                    '>' => {
                        if (self.advance() == '=') {
                            _ = self.advance();
                            return self.tokenAssignment(.shr);
                        }
                        return self.tokenOperator(.shr);
                    },
                    else => return self.tokenOperator(.gt),
                }
            },
            '&' => {
                switch (self.codepoint) {
                    '~' => {
                        if (self.advance() == '=') {
                            _ = self.advance();
                            return self.tokenAssignment(.andnot);
                        }
                        return self.tokenOperator(.andnot);
                    },
                    '&' => {
                        if (self.advance() == '=') {
                            _ = self.advance();
                            return self.tokenAssignment(.cmpand);
                        }
                        return self.tokenOperator(.cmpand);
                    },
                    '=' => {
                        _ = self.advance();
                        return self.tokenAssignment(.@"and");
                    },
                    else => return self.tokenOperator(.@"and"),
                }
            },
            '|' => {
                switch (self.codepoint) {
                    '=' => {
                        _ = self.advance();
                        return self.tokenAssignment(.@"or");
                    },
                    '|' => {
                        if (self.advance() == '=') {
                            _ = self.advance();
                            return self.tokenAssignment(.cmpor);
                        }
                        return self.tokenOperator(.cmpor);
                    },
                    else => return self.tokenOperator(.@"or"),
                }
            },
            else => unreachable,
        }
    }

    pub fn rawNext(self: *Lexer) Token {
        const token = self.tokenise();
        switch (token.un) {
            .operator => |op| {
                self.asi = lexemes.operators.get(op).asi;
            },
            .keyword => |kw| {
                self.asi = lexemes.keywords.get(kw).asi;
            },
            else => {
                self.asi = lexemes.tokens.get(std.meta.activeTag(token)).asi;
            },
        }
        return token;
    }
};

fn findKeyword(string: []const u8) ?lexemes.KeywordKind {
    inline for (std.meta.fields(lexemes.KeywordKind)) |keyword| {
        if (std.mem.eql(u8, string, keyword.name)) return @field(lexemes.KeywordKind, keyword.name);
    }
}

fn findOperator(string: []const u8) ?lexemes.OperatorKind {
    inline for (lexemes.named_operators) |operator| {
        if (std.mem.eql(u8, string, lexemes.operators.get(operator).name)) return operator;
    }
}

fn findDirective(string: []const u8) ?lexemes.DirectiveKind {
    inline for (std.meta.fields(lexemes.DirectiveKind)) |directive| {
        if (std.mem.eql(u8, string, directive.name)) return @field(lexemes.DirectiveKind, directive.name);
    }
}

fn isChar(cp: codepoint) bool {
    if (cp < 0x80) {
        if (cp == '_') return true;
        return std.ascii.isAlphabetic(@intCast(cp));
    }
    // utf8 checks
    return true;
}

fn isDigit(cp: codepoint) bool {
    if (cp < 0x80) {
        return std.ascii.isDigit(@intCast(cp));
    }
    // utf8 checks
    return false;
}

fn numericBase(cp: codepoint) i32 {
    switch (cp) {
        '0'...'9' => cp - '0',
        'a'...'z' => cp - 'a' + 10,
        'A'...'Z' => cp - 'A' + 10,
        else => 16,
    }
}

test {
    std.testing.refAllDecls(@This());
}
