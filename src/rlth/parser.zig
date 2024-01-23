const std = @import("std");

const Tree = @import("tree.zig").Tree;
const ProcedureType = @import("tree.zig").ProcedureType;
const Identifier = @import("tree.zig").Identifier;
const Expression = @import("tree.zig").Expression;
const CompoundLiteralExpression = @import("tree.zig").CompoundLiteralExpression;
const FieldFlags = @import("tree.zig").FieldFlags;
const Field = @import("tree.zig").Field;
const ProcedureFlags = @import("tree.zig").ProcedureFlags;
const BlockFlags = @import("tree.zig").BlockFlags;
const BlockStatement = @import("tree.zig").BlockStatement;
const TupleExpression = @import("tree.zig").TupleExpression;
const CallExpression = @import("tree.zig").CallExpression;
const Statement = @import("tree.zig").Statement;
const IdentifierExpression = @import("tree.zig").IdentifierExpression;
const LiteralExpression = @import("tree.zig").LiteralExpression;
const TypeExpression = @import("tree.zig").TypeExpression;
const StructFlags = @import("tree.zig").StructFlags;
const UnionFlags = @import("tree.zig").UnionFlags;

const Type = @import("tree.zig").Type;

const lexer = @import("lexer.zig");
const lexemes = @import("lexemes.zig");

pub fn parse(tree: *Tree, source: []const u8) !void {
    tree.source.code = source;
    var parser = Parser{};
    try parser.init(tree.allocator, tree);
    parser.deinit();

    try parser.advance();
}

pub const precedence = blk: {
    comptime var list = std.EnumArray(lexemes.OperatorKind, i32).initFill(0);
    comptime var ops = lexemes.operators;
    var it = ops.iterator();
    while (it.next()) |op| {
        list.set(op.key, op.value.precedence);
    }
    break :blk list;
};

pub const Parser = struct {
    arena: std.heap.ArenaAllocator = undefined,
    allocator: std.mem.Allocator = undefined,
    err_handler: ?*const fn (msg: []const u8) void = null,

    tree: *Tree = undefined,
    lexer: lexer.Lexer = .{},

    this_token: lexer.Token = undefined,
    last_token: lexer.Token = undefined,

    this_procedure: ?*ProcedureType = null,

    trace_depth: i32 = 0,
    expression_depth: i32 = 0,

    allow_newline: bool = false,
    allow_type: bool = false,
    allow_in: bool = false,

    pub fn init(self: *Parser, allocator: std.mem.Allocator, tree: *Tree) !void {
        self.arena = std.heap.ArenaAllocator.init(allocator);
        self.allocator = self.arena.allocator();
        self.tree = tree;

        try self.lexer.init(allocator, &tree.source);

        self.this_token = lexer.NullToken;
        self.last_token = lexer.NullToken;

        self.this_procedure = null;

        self.trace_depth = 0;
        self.expression_depth = 0;

        self.allow_newline = false;
        self.allow_type = false;
        self.allow_in = false;
    }

    pub fn deinit(self: *Parser) void {
        self.lexer.deinit();
        self.arena.deinit();
    }

    fn err(self: *Parser, comptime msg: []const u8, args: anytype) void {
        var buf = std.mem.zeroes([1024]u8);
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const temp_allocator = fba.allocator();

        if (self.err_handler) |handler| {
            const fmtted = std.fmt.allocPrint(temp_allocator, msg, args) catch unreachable;
            handler(fmtted);
        }
    }

    fn acceptedOperator(self: *Parser, op: lexemes.OperatorKind) bool {
        if (isOperator(self.this_token, op)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn acceptedAssignment(self: *Parser, op: lexemes.AssignmentKind) bool {
        if (isAssignment(self.this_token, op)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn acceptedKind(self: *Parser, kind: lexemes.TokenKind) bool {
        if (isKind(self.this_token, kind)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn acceptedKeyword(self: *Parser, kind: lexemes.KeywordKind) bool {
        if (isKeyword(self.this_token, kind)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn peek(self: *Parser) !lexer.Token {
        var token = try self.lexer.peek();
        while (isKind(token, .comment)) {
            token = try self.lexer.peek();
        }
        return token;
    }

    fn acceptedSeparator(self: *Parser) !void {
        const token = self.this_token;
        if (self.acceptedOperator(.comma)) return true;
        if (isKind(token, .semicolon)) {
            if (isNewline(token)) {
                const pk = try self.peek();
                if (isKind(pk, .rbrace) or isOperator(pk, .rparen)) {
                    _ = try self.advance();
                    return true;
                }
            }
            self.err("Expected comma", .{});
            return error.AcceptedSeparator;
        }
        return false;
    }

    fn acceptedControlStatementSeparator(self: *Parser) !void {
        const token = try self.peek();
        if (!isKind(token, .lbrace)) {
            return self.acceptedKind(.semicolon);
        }
        if (std.mem.eql(u8, self.this_token.string[0], ";")) {
            return self.acceptedKind(.semicolon);
        }
        return false;
    }

    fn ignoreNewline(self: *Parser) bool {
        return self.expression_depth > 0;
    }

    fn advancePossibleNewline(self: *Parser) !void {
        if (isNewline(self.this_token)) {
            _ = try self.advance();
            return true;
        }
        return false;
    }

    fn advancePossibleNewlineWithin(self: *Parser) !void {
        const token = self.this_token;
        if (!isNewline(token)) return false;
        const next = try self.peek();
        if (token.location.line + 1 < next.location.line) return false;
        if (!isKind(next, .lbrace) and !isKeyword(next, .@"else") and !isKeyword(next, .where)) return false;
        _ = try self.advance();
        return true;
    }

    fn advance(self: *Parser) !lexer.Token {
        const last = self.this_token;
        self.last_token = last;
        self.this_token = try self.lexer.next();
        while (isKind(self.this_token, .comment)) {
            self.this_token = try self.lexer.next();
        }
        if (isKind(self.this_token, .semicolon)) {
            if (self.ignoreNewline() and std.mem.eql(u8, self.this_token.string, "\n")) {
                _ = try self.advance();
            }
        }
        return last;
    }

    fn expectKind(self: *Parser, kind: lexemes.TokenKind) !lexer.Token {
        const token = self.this_token;
        if (!isKind(token, kind)) {
            self.err("Expected token of kind `{}`, got `{}`", .{ @tagName(kind), @tagName(token.un) });
            return error.ExpectKind;
        }
        return try self.advance();
    }

    fn expectOperator(self: *Parser, kind: lexemes.OperatorKind) !lexer.Token {
        const token = self.this_token;
        if ((isOperator(token, .in) or isOperator(token, .not_in)) and
            (self.expression_depth >= 0 or self.allow_in))
        {
            // empty
        } else if (!isOperator(token, kind)) {
            self.err("Expected operator `{}`, got `{}`", .{ lexemes.operatorName(kind), lexemes.operatorName(token.un) });
            return error.ExpectOperator;
        }
        return try self.advance();
    }

    fn expectKeyword(self: *Parser, kind: lexemes.KeywordKind) !lexer.Token {
        const token = self.this_token;
        if (!isKeyword(token, kind)) {
            self.err("Expected keyword `{}`, got `{}`", .{ @tagName(kind), @tagName(token.un) });
            return error.ExpectKeyword;
        }
        return try self.advance();
    }

    fn expectAssignment(self: *Parser, kind: lexemes.AssignmentKind) !lexer.Token {
        const token = self.this_token;
        if (!isAssignment(token, kind)) {
            self.err("Expected assignment `{}`, got `{}`", .{
                lexemes.assignment_tokens.get(kind),
                lexemes.assignment_tokens.get(token.un),
            });
            return error.ExpectAssignment;
        }
        return try self.advance();
    }

    fn expectLiteral(self: *Parser, kind: lexemes.LiteralKind) !lexer.Token {
        const token = self.this_token;
        if (!isLiteral(token, kind)) {
            self.err("Expected literal `{}`, got `{}`", .{ @tagName(kind), @tagName(token.un) });
            return error.ExpectLiteral;
        }
        return try self.advance();
    }

    fn expectSemicolon(self: *Parser) !void {
        if (self.acceptedKind(.semicolon)) return;

        const token = self.this_token;
        if (isKind(token, .rbrace) or isOperator(token, .rparen)) {
            if (token.location.line == self.last_token.location.line) return;
        }

        if (isKind(self.last_token, .semicolon)) return;
        if (isKind(self.this_token, .eof)) return;

        if (token.location.line == self.last_token.location.line) {
            self.err("Expected semicolon, got `{}`", .{@tagName(token.un)});
            return error.ExpectSemicolon;
        }
    }

    fn parseIdentifier(self: *Parser, poly: bool) !*Identifier {
        self.record();

        var token = self.this_token;
        if (isKind(token, .identifier)) {
            _ = try self.advance();
        } else if (isKind(token, .@"const")) {
            _ = try self.advance();
            if (!self.acceptedKind(.identifier)) {
                self.err("Expected identifier after `const`, got `{}`", .{@tagName(self.this_token.un)});
                return error.ParseIdentifier;
            }
            token = self.this_token;
        } else {
            self.err("Expected identifier or `$`, got `{}`", .{@tagName(token.un)});
            return error.ParseIdentifier;
        }

        return try self.tree.newIdentifier(token.string, poly);
    }

    fn parseOperand(self: *Parser, lhs: bool) !?*Expression {
        switch (self.this_token.un) {
            .identifier => return try self.parseIdentifierExpression(),
            .literal => return try self.parseLiteralExpression(),
            .lbrace => {
                if (!lhs) {
                    return try self.parseCompoundLiteralExpression(null);
                }
            },
            .directive => return try self.parseDirectivePrefix(lhs),
            .@"const" => return try self.parsePolyTypeExpression(),
            .undefined => return try self.parseUndefinedExpression(),
            .keyword => |kw| switch (kw) {
                .distinct => return try self.parseDistinctTypeExpression(),
                .proc => {
                    _ = try self.expectKeyword(.proc);
                    // proc group or proc
                    if (isKind(self.this_token, .lbrace)) {
                        return try self.parseProcedureGroupExpression();
                    }
                    return try self.parseProcedure();
                },
                .bit_set => return try self.parseBitSetTypeExpression(),
                .typeid => return try self.parseTypeidTypeExpression(),
                .map => return try self.parseMapTypeExpression(),
                .matrix => return try self.parseMatrixTypeExpression(),
                .@"struct" => return try self.parseStructTypeExpression(),
                .@"union" => return try self.parseUnionTypeExpression(),
                .@"enum" => return try self.parseEnumTypeExpression(),
                .context => {
                    _ = try self.expectKeyword(.context);
                    return try self.tree.newContextExpression();
                },
            },
            .operator => |op| switch (op) {
                .lparen => {
                    _ = try self.expectOperator(.lparen);
                    if (isOperator(self.last_token, .rparen)) {
                        self.err("Expected expression, got `()`", .{});
                        return error.ParseOperand;
                    }
                    const depth = self.expression_depth;
                    const allow_newline = self.allow_newline;
                    if (depth < 0) self.allow_newline = false;
                    self.expression_depth = @max(depth, 0) + 1;
                    const operand = try self.parseExpression(false);
                    _ = try self.expectOperator(.rparen);
                    self.expression_depth = depth;
                    self.allow_newline = allow_newline;
                    return operand;
                },
                .pointer => return try self.parsePointerTypeExpression(),
                .lbracket => {
                    _ = try self.expectOperator(.lbracket);
                    if (isOperator(self.this_token, .pointer)) {
                        return try self.parseMultiPointerTypeExpression();
                    } else if (isOperator(self.this_token, .question)) {
                        return try self.parseArrayTypeExpression();
                    } else if (self.acceptedKeyword(.dynamic)) {
                        return try self.parseDynamicArrayTypeExpression();
                    } else if (!isOperator(self.this_token, .rbracket)) {
                        return try self.parseArrayTypeExpression(true);
                    } else if (self.acceptedOperator(.rbracket)) {
                        return try self.parseSliceTypeExpression();
                    }
                },
                else => {},
            },
            else => {},
        }
        return null;
    }

    fn parseExpression(self: *Parser, lhs: bool) !*Expression {
        return self.parseBinaryExpression(lhs, 1);
    }

    fn parseAtomExpression(self: *Parser, opt_operand: ?*Expression, lhs: bool) !?*Expression {
        if (opt_operand == null) {
            if (self.allow_type) {
                return null;
            }
            self.err("Expected operand, got `{}`", .{@tagName(self.this_token.un)});
        }
        var operand = opt_operand.?;

        var still_lhs = lhs;
        while (true) {
            switch (self.this_token.un) {
                .operator => |op| switch (op) {
                    .lparen => return try self.parseCallExpression(operand),
                    .period => {
                        _ = try self.expectOperator(.period);
                        switch (self.this_token.un) {
                            .identifier => {
                                operand = try self.tree.newSelectorExpression(operand, try self.parseIdentifier(false));
                            },
                            .operator => |in_op| switch (in_op) {
                                .lparen => {
                                    _ = try self.expectOperator(.lparen);
                                    const access = try self.parseIdentifier(false);
                                    _ = try self.expectOperator(.rparen);
                                    operand = try self.tree.newUnwrapExpression(operand, access);
                                },
                                .question => {
                                    _ = try self.expectOperator(.question);
                                    operand = try self.tree.newUnwrapExpression(operand, null);
                                },
                                else => {},
                            },
                            else => {
                                self.err("Expected selector in selector expression", .{});
                                return error.ParseAtomExpression;
                            },
                        }
                    },
                    .arrow => {
                        _ = try self.expectOperator(.arrow);
                        operand = try self.tree.newSelectorExpression(operand, try self.parseIdentifier(false));
                    },
                    .lbracket => {
                        operand = try self.parseIndexExpression(operand);
                    },
                    .pointer, .or_return => |in_op| {
                        _ = try self.expectOperator(in_op);
                        operand = try self.tree.newUnaryExpression(in_op, operand);
                    },
                    else => return operand,
                },
                .lbrace => {
                    if (!still_lhs and self.expression_depth >= 0) {
                        const ty = try self.tree.newExpressionType(operand);
                        operand = try self.parseCompoundLiteralExpression(ty);
                    } else {
                        return operand;
                    }
                },
                else => return operand,
            }
            still_lhs = false;
        }

        return operand;
    }

    fn parseTypeOrIdentifier(self: *Parser) !?*Type {
        const depth = self.expression_depth;
        const allow_type = self.allow_type;
        self.expression_depth = -1;
        self.allow_type = true;

        const operand = try self.parseOperand(true);
        const expression = self.parseAtomExpression(operand, true);

        self.expression_depth = depth;
        self.allow_type = allow_type;

        if (expression) |ex| {
            return switch (ex.*) {
                .type => |t| t.type,
                else => try self.tree.newExpressionType(expression),
            };
        } else |_| {
            // ignore error
        }

        return null;
    }

    fn parseType(self: *Parser) !*Type {
        const ty = try self.parseTypeOrIdentifier();
        if (ty == null) {
            self.err("Expected type, got `{}`", .{@tagName(self.this_token.un)});
            return error.ParseType;
        }
        return ty;
    }

    fn parseCompoundLiteralExpression(self: *Parser, ty: ?*Type) !*Expression {
        var fields = std.ArrayList(*Field).init(self.allocator);
        const depth = self.expression_depth;
        self.expression_depth = 0;

        _ = try self.expectKind(.lbrace);
        while (!isKind(self.this_token, .rbrace) and !isKind(self.this_token, .eof)) {
            const element = try self.parseValue();
            const name = try evaluateIdentifierExpression(element);
            if (isAssignment(self.this_token, .eq)) {
                _ = try self.expectAssignment(.eq);
                const value = try self.parseValue();
                const field = try self.tree.newField(null, name, value, null, FieldFlags{});
                try fields.append(field);
            } else {
                const field = try self.tree.newField(null, name, null, null, FieldFlags{});
                try fields.append(field);
            }
            if (!self.acceptedSeparator()) break;
        }

        _ = self.expectClosing(.rbrace);
        self.expression_depth = depth;

        return try self.tree.newCompoundLiteralExpression(ty, fields);
    }

    fn parseVariableNameOrType(self: *Parser) !*Type {
        if (isOperator(self.this_token, .ellipsis)) {
            _ = self.advance();
            if (try self.parseTypeOrIdentifier()) |ty| {
                return ty;
            }
            self.err("Expected type after `...`, got `{}`", .{@tagName(self.this_token.un)});
            return error.ParseVariableNameOrType;
        } else if (isKeyword(self.this_token, .typeid)) {
            try self.expectKeyword(.typeid);
            var spec: ?*Type = null;
            if (self.acceptedOperator(.quo)) {
                spec = try self.parseType();
            }
            return try self.tree.newTypeidType(spec);
        }

        return try self.parseType();
    }

    fn evaluateIdentifierExpression(expression: *const Expression) !?*Identifier {
        return switch (expression.*) {
            .identifier => |id| id.identifier,
            .type => |ty| try evaluateIdentifierType(ty.type),
            .selector => |s| blk: {
                if (s.operand == null) break :blk s.field;
                break :blk null;
            },
            else => null,
        };
    }

    fn evaluateIdentifierType(ty: *const Type) !?*Identifier {
        return switch (ty.*.derived) {
            .expression => |ex| try evaluateIdentifierExpression(ex),
            .poly => |ply| blk: {
                if (ply.specialisation == null) break :blk evaluateIdentifierType(ply.type);
                break :blk null;
            },
            else => null,
        };
    }

    fn parseFieldFlags(self: *Parser) !FieldFlags {
        var flags = FieldFlags{};
        if (isKeyword(self.this_token, .using)) {
            _ = try self.advance();
            flags.using = true;
        }

        while (isKind(self.this_token, .directive)) {
            switch (self.this_token.un.directive) {
                .any_int => flags.any_int = true,
                .c_vararg => flags.c_vararg = true,
                .no_alias => flags.no_alias = true,
                .subtype => flags.subtype = true,
                .@"const" => flags.@"const" = true,
                else => {
                    self.err("Unknown field flag `{}`", .{@tagName(self.this_token.un.directive)});
                    return error.ParseFieldFlagsparseFieldFlags;
                },
            }
            _ = try self.advance();
        }

        return flags;
    }

    fn parseFieldList(self: *Parser, is_struct: bool) std.ArrayList(*Field) {
        var fields = std.ArrayList(*Field).init(self.allocator);
        if (isOperator(self.this_token, .rparen)) return fields;

        const allow_newline = self.allow_newline;
        self.allow_newline = true;

        var type_list = std.ArrayList(*Type).init(self.allocator);
        var field_flags = std.ArrayList(FieldFlags).init(self.allocator);
        var f_type: ?*Type = null;
        while ((if (is_struct) !isKind(self.this_token, .rbrace) else isOperator(self.this_token, .colon)) and
            !isKind(self.this_token, .eof))
        {
            const flags = try self.parseFieldFlags();
            const name_or_type = try self.parseVariableNameOrType();
            try type_list.append(name_or_type);
            try field_flags.append(flags);
            if (!self.acceptedSeparator()) break;
        }

        if (isOperator(self.this_token, .colon)) {
            self.expectOperator(.colon);
            if (!isAssignment(self.this_token, .eq)) {
                f_type = try self.parseVariableNameOrType();
            }
        }

        var default_value: ?*Expression = null;
        if (self.acceptedAssignment(.eq)) {
            default_value = try self.parseExpression(true);
        }

        var tag: ?[]const u8 = null;
        if (f_type != null and default_value == null and isLiteral(self.this_token, .string)) {
            tag = self.this_token.string;
            _ = try self.advance();
        }

        const n_elements = type_list.items.len;
        if (f_type) |ty| {
            for (0..n_elements) |i| {
                const name = type_list.items[i];
                const flags = field_flags.items[i];
                const ident = try evaluateIdentifierType(name);
                if (ident == null) {
                    self.err("Expected identifier, got `{}`", .{@tagName(name.derived)});
                    return error.ParseFieldList;
                }
                try fields.append(try self.tree.newField(ty, ident, default_value, tag, flags));
            }
        } else {
            self.record();

            for (0..n_elements) |i| {
                const ty = type_list.items[i];
                const flags = field_flags.items[i];
                const name = std.fmt.allocPrint(self.allocator, "_unnamed_{}", .{i});
                const ident = try self.tree.newIdentifier(name, false);
                try fields.append(try self.tree.newField(ty, ident, default_value, tag, flags));
            }
        }

        if (!self.acceptedSeparator()) {
            self.allow_newline = allow_newline;
            return fields;
        }

        while ((if (is_struct) !isKind(self.this_token, .rbrace) else !isOperator(self.this_token, .rparen)) and !isKind(self.this_token, .eof) and !isKind(self.this_token, .semicolon)) {
            const flags = try self.parseFieldFlags();
            f_type = null;
            var names = std.ArrayList(*Identifier).init(self.allocator);
            while (true) {
                const name = try self.parseIdentifier(false);
                try names.append(name);
                const token = self.this_token;
                if (!isOperator(token, .comma) or isKind(token, .eof)) break;
                _ = try self.advance();
            }

            self.expectOperator(.colon);
            if (!isAssignment(self.this_token, .eq)) {
                f_type = try self.parseVariableNameOrType();
            }
            default_value = null;
            if (self.acceptedAssignment(.eq)) {
                default_value = try self.parseExpression(false);
            }
            tag = null;
            if (f_type != null and default_value == null and isLiteral(self.this_token, .string)) {
                tag = self.this_token.string;
                _ = try self.advance();
            }
            const n_names = names.items.len;
            for (0..n_names) |i| {
                try fields.append(try self.tree.newField(f_type, names.items[i], default_value, tag, flags));
            }

            if (!self.acceptedSeparator()) break;
        }

        self.allow_newline = allow_newline;
        return fields;
    }

    fn parseProcedureResults(self: *Parser, no_return: *bool) !std.ArrayList(*Field) {
        if (!self.acceptedOperator(.arrow)) {
            self.err("Expected `->`, got `{}`", .{@tagName(self.this_token.un)});
            return error.ParseProcedureResults;
        }

        var fields = std.ArrayList(*Field).init(self.allocator);
        if (self.acceptedOperator(.not)) {
            no_return.* = true;
            // this won't allocate anything
            return fields;
        }

        // not a tuple
        if (!isOperator(self.this_token, .lparen)) {
            const ty = try self.parseType();
            self.record();
            const ident = try self.tree.newIdentifier("_unnamed", false);
            const field = try self.tree.newField(ty, ident, null, null, FieldFlags{});
            try fields.append(field);
            return fields;
        }

        // we have a tuple
        _ = try self.expectOperator(.lparen);

        fields.deinit();
        fields = try self.parseFieldList(false);
        try self.advancePossibleNewline();
        _ = try self.expectOperator(.rparen);

        return fields;
    }

    fn parseProcedureType(self: *Parser) !*ProcedureType {
        var cc = lexemes.CallingConvention.rlth;
        if (isLiteral(self.this_token, .string)) {
            const token = try self.expectLiteral(.string);
            cc = std.meta.stringToEnum(lexemes.CallingConvention, token.string) orelse {
                self.err("Unknown calling convention `{}`", .{token.string});
                return error.ParseProcedureType;
            };
        }

        _ = try self.expectOperator(.lparen);
        const params = self.parseFieldList(false);
        try self.advancePossibleNewline();
        _ = try self.expectOperator(.rparen);

        var is_generic = false;
        for (params.items) |param| {
            if (param.name.poly) {
                is_generic = true;
                break;
            }
            if (if (param.type) |ty| ty.poly else false) {
                is_generic = true;
                break;
            }
        }

        var diverging = false;
        const results = try self.parseProcedureResults(&diverging);

        const flags = ProcedureFlags{
            .bounds_check = true,
            .type_assert = true,
            .diverging = diverging,
        };

        return try (if (is_generic)
            self.tree.newGenericProcedureType(flags, cc, params, results)
        else
            self.tree.newConcreteProcedureType(flags, cc, params, results));
    }

    fn parseBody(self: *Parser, block_flags: BlockFlags) !*Statement {
        const depth = self.expression_depth;
        const allow_newline = self.allow_newline;
        self.expression_depth = 0;
        self.allow_newline = true;

        _ = try self.expectKind(.lbrace);
        const statements = try self.parseStatementList(block_flags);
        _ = try self.expectKind(.rbrace);

        self.allow_newline = allow_newline;
        self.expression_depth = depth;

        return try self.tree.newBlockStatement(block_flags, statements, null);
    }

    fn parseRhsTupleExpression(self: *Parser) !*TupleExpression {
        return try self.parseTupleExpression(false);
    }

    fn parseProcedure(self: *Parser) !*Expression {
        const ty = try self.parseProcedureType();
        try self.advancePossibleNewline();

        var where_clauses: ?*TupleExpression = null;
        if (isKeyword(self.this_token, .where)) {
            _ = try self.expectKeyword(.where);
            const depth = self.expression_depth;
            self.expression_depth = -1;
            where_clauses = try self.parseRhsTupleExpression();
            self.expression_depth = depth;
        }

        var flags = ty.flags;

        while (isKind(self.this_token, .directive)) {
            const token = try self.expectKind(.directive);
            switch (token.un.directive) {
                .optional_ok => flags.optional_ok = true,
                .optional_allocator_error => flags.optional_allocation_error = true,
                .no_bounds_check => flags.bounds_check = false,
                .bounds_check => flags.bounds_check = true,
                .no_type_assert => flags.type_assert = false,
                .type_assert => flags.type_assert = true,
                else => {
                    self.err("Unknown procedure flag `{}`", .{@tagName(token.un.directive)});
                    return error.ParseProcedure;
                },
            }
        }

        ty.flags = flags;

        if (self.acceptedKind(.undefined)) {
            if (where_clauses) |_| {
                self.err("Procedures with `where` clauses need bodies", .{});
                return error.ParseProcedure;
            }
            return try self.tree.newProcedureExpression(ty, null, null);
        } else if (isKind(self.this_token, .lbrace)) {
            const block_flags = BlockFlags{
                .bounds_check = flags.bounds_check,
                .type_assert = flags.type_assert,
            };
            self.this_procedure = ty;
            const body = self.parseBody(block_flags);
            return try self.tree.newProcedureExpression(ty, body, where_clauses);
        }

        // no body or equivalent, must be a type
        return try self.tree.newTypeExpression(@fieldParentPtr(Type, "procedure", ty));
    }

    fn parseCallExpression(self: *Parser, operand: *Expression) !*Expression {
        var arguments = std.ArrayList(*Expression).init(self.allocator);
        const depth = self.expression_depth;
        const allow_newline = self.allow_newline;
        self.expression_depth = 0;
        self.allow_newline = true;

        _ = try self.expectOperator(.lparen);

        var seen_ellipsis = false;
        while (!isOperator(self.this_token, .rparen) and !isKind(self.this_token, .eof)) {
            if (isOperator(self.this_token, .comma)) {
                self.err("Expected expression, got `,`", .{});
                return error.ParseCallExpression;
            } else if (isAssignment(self.this_token, .eq)) {
                self.err("Expected expression, got `=`", .{});
                return error.ParseCallExpression;
            }

            var has_ellipsis = false;
            if (isOperator(self.this_token, .ellipsis)) {
                has_ellipsis = true;
                _ = try self.expectOperator(.ellipsis);
            }

            const argument = try self.parseExpression(false);
            if (isAssignment(self.this_token, .eq)) {
                _ = try self.expectAssignment(.eq);
                if (has_ellipsis) {
                    self.err("Cannot apply `..`", .{});
                    return error.ParseCallExpression;
                }
                if (try self.evaluateIdentifierExpression(argument)) |name| {
                    try arguments.append(
                        try self.tree.newField(null, name, try self.parseValue(), null, FieldFlags{}),
                    );
                } else {
                    self.err("Expected identifier, got `{}`", .{@tagName(argument.*)});
                }
            } else {
                if (seen_ellipsis) {
                    self.err("Positional arguments not allowed after `..`", .{});
                    return error.ParseCallExpression;
                }
                try arguments.append(try self.tree.newField(null, null, argument, null, FieldFlags{}));
            }

            if (has_ellipsis) {
                seen_ellipsis = true;
            }

            if (!self.acceptedSeparator()) break;
        }

        _ = try self.expectOperator(.rparen);

        self.allow_newline = allow_newline;
        self.expression_depth = depth;

        return try self.tree.newCallExpression(operand, arguments);
    }

    fn parseStatement(self: *Parser, block_flags: BlockFlags) !?*Statement {
        _ = self; // autofix
        _ = block_flags; // autofix
    }

    fn parseUnaryExpression(self: *Parser, lhs: bool) !*Expression {
        switch (self.this_token.un) {
            .operator => |op| switch (op) {
                .transmute, .auto_cast, .cast => return try self.parseCastExpression(lhs),
                .add, .sub, .xor, .@"and", .not => return try self.parseUnaryStemExpression(lhs),
                .period => return try self.parseImplicitSelectorExpression(),
                else => {},
            },
            else => {},
        }

        const operand = try self.parseOperand(lhs);
        return try self.parseAtomExpression(operand, lhs);
    }

    fn parseDirectiveCallExpression(self: *Parser, name: []const u8) !*Expression {
        self.record();
        const intrinsics = try self.tree.newIdentifier("intrinsics", false);
        const directive = try self.tree.newIdentifier(name, false);
        const ident = try self.tree.newIdentifierExpression(intrinsics);
        const selector = try self.tree.newSelectorExpression(ident, directive);
        return try self.parseCallExpression(selector);
    }

    fn parseDirectiveCallStatement(self: *Parser, name: []const u8) !*Statement {
        const expression = try self.parseDirectiveCallExpression(name);
        return try self.tree.newExpressionStatement(expression);
    }

    fn parseDirectiveForStatement(self: *Parser, block_flags: BlockFlags) !*Statement {
        const token = try self.expectKind(.directive);
        return switch (token.un.directive) {
            .bounds_check => self.parseStatement(blk: {
                var flags = block_flags;
                flags.bounds_check = true;
                break :blk flags;
            }),
            .no_bounds_check => self.parseStatement(blk: {
                var flags = block_flags;
                flags.bounds_check = false;
                break :blk flags;
            }),
            .type_assert => self.parseStatement(blk: {
                var flags = block_flags;
                flags.type_assert = true;
                break :blk flags;
            }),
            .no_type_assert => self.parseStatement(blk: {
                var flags = block_flags;
                flags.type_assert = false;
                break :blk flags;
            }),
            .partial => self.parseStatement(blk: {
                // TODO: partial
                // var flags = block_flags;
                // flags.partial = true;
                break :blk block_flags;
            }),
            .assert => self.parseDirectiveCallStatement("assert"),
            .panic => self.parseDirectiveCallStatement("panic"),
            .load => self.parseDirectiveCallStatement("load"),
            .unroll => self.parseStatement(blk: {
                // TODO: unroll
                // var flags = block_flags;
                // flags.partial = true;
                break :blk block_flags;
            }),
            .force_inline, .no_inline => self.parseStatement(blk: {
                // TODO: force_inline, no_inline
                // var flags = block_flags;
                // flags.partial = true;
                break :blk block_flags;
            }),
            else => {
                self.err("Unknown statement directive `{}`", .{@tagName(token.un.directive)});
                return error.ParseDirectiveForStatement;
            },
        };
    }

    fn parseValue(self: *Parser) !*Expression {
        if (isKind(self.this_token, .lbrace)) {
            return self.parseCompoundLiteralExpression(null);
        }
        return self.parseExpression(false);
    }

    fn parseAttributesForStatement(self: *Parser, block_flags: BlockFlags) !*Expression {
        _ = try self.expectKind(.attribute);
        var attributes = std.ArrayList(*Expression).init(self.allocator);
        if (isKind(self.this_token, .identifier)) {
            const ident = try self.parseIdentifier(false);
            try attributes.append(try self.tree.newField(null, ident, null, null, FieldFlags{}));
        } else {
            _ = try self.expectOperator(.lparen);
            self.expression_depth += 1;
            while (!isOperator(self.this_token, .rparen) and !isKind(self.this_token, .eof)) {
                const ident = self.parseIdentifier(false);
                try attributes.append(try self.tree.newField(null, ident, blk: {
                    if (isAssignment(self.this_token, .eq)) {
                        _ = try self.expectAssignment(.eq);
                        break :blk try self.parseValue();
                    }
                    break :blk null;
                }, null, FieldFlags{}));
                if (!self.acceptedSeparator()) break;
            }
            self.expression_depth -= 1;
            _ = try self.expectOperator(.rparen);
        }

        try self.advancePossibleNewline();
        const stmt = try self.parseStatement(block_flags);
        switch (stmt.*) {
            .declaration => |dcl| dcl.attributes = attributes,
            .foreign_block => |fb| fb.attributes = attributes,
            .foreign_import => |fi| fi.attributes = attributes,
            else => {
                self.err("Attributes can only be applied to declarations", .{});
                return error.ParseAttributesForStatement;
            },
        }
        return stmt;
    }

    fn parseIdentifierExpression(self: *Parser) !*IdentifierExpression {
        return try self.tree.newIdentifierExpression(try self.parseIdentifier(false));
    }

    fn parseLiteralExpression(self: *Parser) !*Expression {
        const token = try self.advance();
        if (token.un != .literal) {
            self.err("Expected literal, got `{}`", .{@tagName(token.un)});
            return error.ParseLiteralExpression;
        }
        return try self.tree.newLiteralExpression(token.un.literal, token.string);
    }

    fn parseBitSetTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.bit_set);
        _ = try self.expectOperator(.lbracket);
        const expression = try self.parseExpression(false);
        const underlying: ?*Type = blk: {
            if (self.acceptedKind(.semicolon)) {
                break :blk try self.parseType();
            }
            break :blk null;
        };
        _ = try self.expectOperator(.rbracket);
        return try self.tree.newTypeExpression(try self.tree.newBitSetType(expression, underlying));
    }

    fn parseTypeidTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.typeid);
        return try self.tree.newTypeExpression(try self.tree.newTypeidType(null));
    }

    fn parseMapTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.map);
        _ = try self.expectOperator(.lbracket);
        const key_expression = try self.parseExpression(true);
        _ = try self.expectOperator(.rbracket);
        const value = try self.parseType();
        const key = try self.tree.newExpressionType(key_expression);
        return try self.tree.newTypeExpression(try self.tree.newMapType(key, value));
    }

    fn parseMatrixTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.matrix);
        _ = try self.expectOperator(.lbracket);
        const rows_expression = try self.parseExpression(true);
        _ = try self.expectOperator(.comma);
        const columns_expression = try self.parseExpression(true);
        _ = try self.expectOperator(.rbracket);

        const base_ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newMatrixType(rows_expression, columns_expression, base_ty));
    }

    fn parsePointerTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectOperator(.pointer);
        const ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newPointerType(ty));
    }

    fn parseMultiPointerTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectOperator(.pointer);
        _ = try self.expectOperator(.rbracket);

        const ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newMultiPointerType(ty));
    }

    fn parseArrayTypeExpression(self: *Parser, parse_count: bool) !*Expression {
        const count: ?*Expression = blk: {
            if (parse_count) {
                self.expression_depth += 1;
                const c = try self.parseExpression(false);
                self.expression_depth -= 1;
                break :blk c;
            }
            _ = try self.expectOperator(.question);
            break :blk null;
        };
        _ = try self.expectOperator(.rbracket);

        const ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newArrayType(ty, count));
    }

    fn parseDynamicArrayTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectOperator(.rbracket);
        const ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newDynamicArrayType(ty));
    }

    fn parseSliceTypeExpression(self: *Parser) !*Expression {
        const ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newSliceType(ty));
    }

    fn parseDistinctTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.distinct);
        const ty = try self.parseType();
        return try self.tree.newTypeExpression(try self.tree.newDistinctType(ty));
    }

    fn parseProcedureGroupExpression(self: *Parser) !*Expression {
        var expressions = std.ArrayList(*Expression).init(self.allocator);
        _ = try self.expectKind(.lbrace);
        while (!isKind(self.this_token, .rbrace) and !isKind(self.this_token, .eof)) {
            try expressions.append(try self.parseExpression(false));
            if (!self.acceptedSeparator()) break;
        }
        _ = try self.expectKind(.rbrace);

        return try self.tree.newProcedureGroupExpression(expressions);
    }

    fn parseStructTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.@"struct");
        var parameters = std.ArrayList(*Field).init(self.allocator);
        // parapoly
        if (self.acceptedOperator(.lparen)) {
            parameters = self.parseFieldList(false);
            _ = try self.expectOperator(.rparen);
        }

        var alignment: ?*Expression = null;
        var flags = StructFlags{};
        while (self.acceptedKind(.directive)) {
            switch (self.last_token.un.directive) {
                .@"packed" => flags.@"packed" = true,
                .@"align" => {
                    const depth = self.expression_depth;
                    self.expression_depth = -1;
                    _ = try self.expectOperator(.lparen);
                    alignment = try self.parseExpression(true);
                    _ = try self.expectOperator(.rparen);
                    self.expression_depth = depth;
                },
                .raw_union => flags.@"union" = true,
                .no_copy => flags.uncopyable = true,
                else => |d| {
                    self.err("Unknown struct flag `{}`", .{@tagName(d)});
                    return error.ParseStructTypeExpression;
                },
            }
        }

        try self.advancePossibleNewline();

        const where_clauses: ?*TupleExpression = blk: {
            if (self.acceptedKeyword(.where)) {
                const depth = self.expression_depth;
                self.expression_depth = -1;
                const c = try self.parseRhsTupleExpression();
                self.expression_depth = depth;
                break :blk c;
            }
            break :blk null;
        };

        try self.advancePossibleNewline();

        _ = try self.expectKind(.lbrace);
        const fields = self.parseFieldList(true);
        _ = try self.expectKind(.rbrace);

        const ty = try (if (parameters.items.len == 0)
            self.tree.newConcreteStructType(flags, alignment, fields, where_clauses)
        else
            self.tree.newGenericStructType(flags, alignment, fields, where_clauses, parameters));
        return try self.tree.newTypeExpression(ty);
    }

    fn parseUnionTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.@"union");

        const parameters = std.ArrayList(*Field).init(self.allocator);
        // parapoly
        if (self.acceptedOperator(.lparen)) {
            parameters = self.parseFieldList(false);
            _ = try self.expectOperator(.rparen);
        }

        var flags = UnionFlags{};
        var alignment: ?*Expression = null;
        while (self.acceptedKind(.directive)) {
            switch (self.last_token.un.directive) {
                .@"align" => {
                    const depth = self.expression_depth;
                    self.expression_depth = -1;
                    _ = try self.expectOperator(.lparen);
                    alignment = try self.parseExpression(true);
                    _ = try self.expectOperator(.rparen);
                    self.expression_depth = depth;
                },
                .no_nil => flags.no_nil = true,
                .shared_nil => flags.shared_nil = true,
                .maybe => flags.maybe = true,
                else => |d| {
                    self.err("Unknown union flag `{}`", .{@tagName(d)});
                    return error.ParseUnionTypeExpression;
                },
            }
        }

        try self.advancePossibleNewline();

        const where_clauses: ?*TupleExpression = blk: {
            if (self.acceptedKeyword(.where)) {
                const depth = self.expression_depth;
                self.expression_depth = -1;
                const c = try self.parseRhsTupleExpression();
                self.expression_depth = depth;
                break :blk c;
            }
            break :blk null;
        };

        try self.advancePossibleNewline();

        _ = try self.expectKind(.lbrace);
        const variants = self.parseFieldList(true);
        _ = try self.expectKind(.rbrace);

        const ty = try (if (parameters.items.len == 0)
            self.tree.newConcreteUnionType(flags, alignment, variants, where_clauses)
        else
            self.tree.newGenericUnionType(flags, alignment, variants, where_clauses, parameters));
        return try self.tree.newTypeExpression(ty);
    }

    fn parseEnumTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKeyword(.@"enum");
        const base_ty: ?*Type = blk: {
            if (!isKind(self.this_token, .lbrace)) {
                break :blk try self.parseType();
            }
            break :blk null;
        };

        try self.advancePossibleNewline();

        var fields = std.ArrayList(*Field).init(self.allocator);
        _ = try self.expectKind(.lbrace);
        while (!isKind(self.this_token, .rbrace) and !isKind(self.this_token, .eof)) {
            const name = try self.parseValue();
            if (name != .identifier) {
                self.err("Expected identifier for enumerator, got `{}`", .{@tagName(name)});
                return error.ParseEnumTypeExpression;
            }

            var value: ?*Expression = null;
            if (isAssignment(self.this_token, .eq)) {
                _ = try self.expectAssignment(.eq);
                value = try self.parseValue();
            }

            try fields.append(try self.tree.newField(null, name.identifier.identifier, value, null, FieldFlags{}));
            if (!self.acceptedSeparator()) break;
        }
        _ = try self.expectKind(.rbrace);

        const ty = try self.tree.newEnumType(base_ty, fields);
        return try self.tree.newTypeExpression(ty);
    }

    fn parsePolyTypeExpression(self: *Parser) !*Expression {
        _ = try self.expectKind(.@"const");
        const ident = try self.tree.newIdentifierExpression(try self.parseIdentifier(true));
        const expr_ty = self.tree.newExpressionType(ident);

        var specialisation: ?*Type = null;
        if (self.acceptedOperator(.quo)) {
            specialisation = try self.parseType();
        }

        const poly = try self.tree.newPolyType(expr_ty, specialisation);
        return try self.tree.newTypeExpression(poly);
    }

    fn parseUndefinedExpression(self: *Parser) !*Expression {
        _ = try self.expectKind(.undefined);
        return try self.tree.newUndefinedExpression();
    }

    fn parseDirectivePrefix(self: *Parser, lhs: bool) !*Expression {
        switch ((try self.expectKind(.directive)).un.directive) {
            .type => {
                return try self.tree.newTypeExpression(try self.parseType());
            },
            .simd => {
                const ty = try self.parseType();
                if (ty.derived != .array) {
                    self.err("Expected array type for `simd`, got `{}`", .{@tagName(ty.derived)});
                    return error.ParseDirectivePrefix;
                }
                // TODO: simd
                return try self.tree.newTypeExpression(ty);
            },
            .soa, .sparse => {
                return try self.tree.newTypeExpression(try self.parseType());
            },
            .partial => {
                return try self.parseExpression(lhs);
            },
            .no_bounds_check, .bounds_check, .type_assert, .no_type_assert => {
                return try self.parseExpression(lhs);
            },
            .force_no_inline, .force_inline => {
                return try self.parseExpression(lhs);
            },
            .config => {
                return self.parseDirectiveCallExpression("config");
            },
            .defined => {
                return self.parseDirectiveCallExpression("defined");
            },
            .load => {
                return self.parseDirectiveCallExpression("load");
            },
            .caller_location => {
                const intrinsics = try self.tree.newIdentifier("intrinsics", false);
                const caller_location = try self.tree.newIdentifier("caller_location", false);
                const operand = try self.tree.newIdentifierExpression(intrinsics);
                return try self.tree.newSelectorExpression(operand, caller_location);
            },
            .procedure => {
                const intrinsics = try self.tree.newIdentifier("intrinsics", false);
                const caller_location = try self.tree.newIdentifier("procedure", false);
                const operand = try self.tree.newIdentifierExpression(intrinsics);
                return try self.tree.newSelectorExpression(operand, caller_location);
            },
            else => {
                self.err("Unknown directive `{}`", .{@tagName(self.last_token.un.directive)});
                return error.ParseDirectivePrefix;
            },
        }
    }

    fn expectClosing(self: *Parser, kind: lexemes.TokenKind) !lexer.Token {
        const token = self.this_token;
        if (!isKind(token, kind) and isKind(token, .semicolon) and
            (std.mem.eql(u8, token.string, "\n") or isKind(token, .eof)))
        {
            if (self.allow_newline) {
                self.err("Expected `,` before newline", .{});
                return error.ExpectClosing;
            }
            _ = try self.advance();
        }
        return self.expectKind(kind);
    }

    fn parseIndexExpression(self: *Parser, operand: *Expression) !*Expression {
        var lhs: ?*Expression = null;
        var rhs: ?*Expression = null;

        self.expression_depth += 1;

        _ = try self.expectOperator(.lbracket);

        if (!isOperator(self.this_token, .ellipsis) and !isOperator(self.this_token, .rangefull) and !isOperator(self.this_token, .rangehalf) and !isOperator(self.this_token, .colon)) {
            lhs = try self.parseExpression(false);
        }

        if (!isOperator(self.this_token, .ellipsis) or !isOperator(self.this_token, .rangefull) or !isOperator(self.this_token, .rangehalf)) {
            self.err("Expected `:` in indexing expression, got {}", .{@tagName(self.this_token.un)});
            return error.ParseIndexExpression;
        }

        const interval: ?lexer.Token = null;
        if (isOperator(self.this_token, .comma) or isOperator(self.this_token, .colon)) {
            interval = try self.advance();
            if (!isOperator(self.this_token, .rbracket) and !isKind(self.this_token, .eof)) {
                rhs = try self.parseExpression(false);
            }
        }

        _ = try self.expectOperator(.rbracket);
        self.expression_depth -= 1;

        // if (interval) |ivl| {
        //     if (isOperator(ivl, .comma))
        //     {

        //     } else {

        //     }
        // } else {
        //     return
        // }
        return try self.tree.newIndexExpression(operand, lhs, rhs);
    }

    fn parseCastExpression(self: *Parser, lhs: bool) !*Expression {
        const token = try self.advance();

        var ty: ?*Type = null;
        if (!isOperator(token, .auto_cast)) {
            _ = try self.expectOperator(.lparen);
            ty = try self.parseType();
            _ = try self.expectOperator(.rparen);
        }

        const operand = try self.parseUnaryExpression(lhs);
        if (token.un != .operator) {
            self.err("Expected operator, got `{}`", .{@tagName(token.un)});
            return error.ParseCastExpression;
        }
        return try self.tree.newCastExpression(token.un.operator, ty, operand);
    }

    fn parseUnaryStemExpression(self: *Parser, lhs: bool) !*Expression {
        const token = try self.advance();
        const operand = try self.parseUnaryExpression(lhs);
        if (token.un != .operator) {
            self.err("Expected operator, got `{}`", .{@tagName(token.un)});
            return error.ParseUnaryStemExpression;
        }
        return try self.tree.newUnaryExpression(token.un.operator, operand);
    }

    fn parseImplicitSelectorExpression(self: *Parser) !*Expression {
        _ = try self.expectOperator(.period);
        const ident = try self.parseIdentifier(false);
        return try self.tree.newSelectorExpression(null, ident);
    }

    fn parseTernaryExpression(self: *Parser, expression: *Expression, lhs: bool) !*Expression {
        var condition: ?*Expression = null;
        var on_true: ?*Expression = null;
        var kind: lexemes.KeywordKind = .@"if";
        if (self.acceptedOperator(.question)) {
            condition = expression;
            on_true = try self.parseExpression(lhs);
            _ = try self.expectOperator(.colon);
        } else if (self.acceptedKeyword(.@"if") or self.acceptedKeyword(.when)) {
            kind = self.last_token.un.keyword;
            condition = try self.parseExpression(lhs);
            on_true = expression;
            _ = try self.expectKeyword(.@"else");
        }

        const on_false = self.parseExpression(lhs);
        return try self.tree.newTernaryExpression(kind, on_true, condition, on_false);
    }

    fn parseBinaryExpression(self: *Parser, lhs: bool, prec: i32) !*Expression {
        var expr = try self.parseUnaryExpression(lhs);
        var still_lhs = lhs;
        while (true) {
            const token = self.this_token;
            const last = self.last_token;
            var op_prec: i32 = 0;
            if (isKind(token, .operator)) {
                op_prec = precedence.get(token.un.operator);
                if (isOperator(token, .in) or isOperator(token, .not_in)) {
                    if (self.expression_depth < 0 and !self.allow_in) {
                        op_prec = 0;
                    }
                }
            } else if (isKeyword(token, .@"if") or isKeyword(token, .when)) {
                op_prec = 1;
            }
            if (op_prec < prec) break;

            if (isKeyword(token, .@"if") or isKeyword(token, .when)) {
                if (last.location.line < token.location.line) {
                    return expr;
                }
            }

            if (isOperator(token, .question) or isKeyword(token, .@"if") or isKeyword(token, .when)) {
                expr = try self.parseTernaryExpression(expr, still_lhs);
            } else {
                _ = try self.expectKind(.operator);
                const rhs = self.parseBinaryExpression(false, op_prec + 1) catch {
                    self.err("Expected expression on the right-hand side");
                    return error.ParseBinaryExpression;
                };
                expr = try self.tree.newBinaryExpression(token.un.operator, expr, rhs);
            }

            still_lhs = false;
        }

        return expr;
    }

    fn parseTupleExpression(self: *Parser, lhs: bool) !*Expression {
        const allow_newline = self.allow_newline;
        self.allow_newline = true;

        var expressions = std.ArrayList(*Expression).init(self.allocator);
        while (true) {
            try expressions.append(try self.parseExpression(lhs));
            if (!isOperator(self.this_token, .comma) or isKind(self.this_token, .eof)) break;
            _ = try self.advance();
        }

        self.allow_newline = allow_newline;
        return try self.tree.newTupleExpression(expressions);
    }

    fn parseLhsTupleExpression(self: *Parser) !*Expression {
        return try self.parseTupleExpression(true);
    }

    fn parseStatementList(self: *Parser, block_flags: BlockFlags) !std.ArrayList(*Statement) {
        var statements = std.ArrayList(*Statement).init(self.allocator);

        while (!isKeyword(self.this_token, .case) and
            !isKind(self.this_token, .rbrace) and
            !isKind(self.this_token, .eof))
        {
            if (try self.parseStatement(block_flags)) |statement| {
                if (statement != .empty) {
                    try statements.append(statement);
                }
            }
        }

        return statements;
    }

    fn parseBlockStatement(self: *Parser, block_flags: BlockFlags, when: bool) !*Statement {
        try self.advancePossibleNewlineWithin();

        if (!when and self.this_procedure == null) {
            self.err("Blocks can only be used in procedures", .{});
            return error.ParseBlockStatement;
        }

        return try self.parseBody(block_flags);
    }

    fn parseDeclarationStatementTail(self: *Parser, names: std.ArrayList(*Identifier), is_using: bool) !*Statement {
        var values: ?*TupleExpression = null;
        const ty = try self.parseTypeOrIdentifier();
        const token = self.this_token;
        var constant = false;

        const n_names = names.items.len;
        if (isAssignment(token, .eq) or isOperator(token, .colon)) {
            const seperator = try self.advance();
            constant = isOperator(seperator, .colon);
            try self.advancePossibleNewline();
            values = try self.parseRhsTupleExpression();
            const n_values = values.?.expressions.items.len;
            if (n_values > n_names) {
                self.err("Too many values for declaration, expected `{}`, got `{}`", .{ n_names, n_values });
                return error.ParseDeclarationStatementTail;
            } else if (n_values < n_names and constant) {
                self.err("Too few values for constant declarations, expected `{}`, got `{}`", .{ n_names, n_values });
                return error.ParseDeclarationStatementTail;
            } else if (n_values == 0) {
                self.err("Expected expression for declaration", .{});
                return error.ParseDeclarationStatementTail;
            }
        }

        const n_values = if (values) |v| v.expressions.items.len else 0;
        if (ty == null) {
            if (constant and n_values == 0) {
                self.err("Expected type for constant declaration", .{});
                return error.ParseDeclarationStatementTail;
            } else if (n_values == 0 and n_names > 0) {
                self.err("Expected constant value", .{});
                return error.ParseDeclarationStatementTail;
            }
        }

        if (self.expression_depth >= 0) {
            if (isKind(self.this_token, .rbrace) and self.this_token.location.line == self.last_token.location.line) {
                // nothing
            } else {
                try self.expectSemicolon();
            }
        }

        if (self.this_procedure == null and n_values > 0 and n_names != n_values) {
            self.err("Expected `{}` values on right-hand side, got `{}`", .{ n_names, n_values });
            return error.ParseDeclarationStatementTail;
        }

        if (ty != null and n_values == 0) {
            const expressions = std.ArrayList(*Expression).init(self.allocator);
            for (0..n_names) |_| {
                try expressions.append(try self.tree.newCompoundLiteralExpression(
                    ty,
                    std.ArrayList(*Field).init(self.allocator),
                ));
            }
            values = try self.tree.newTupleExpression(expressions);
        }

        return try self.tree.newDeclarationStatement(
            ty,
            names,
            values,
            std.ArrayList(*Field).init(self.allocator),
            is_using,
        );
    }

    fn parseDeclarationStatement(self: *Parser, lhs: *TupleExpression, is_using: bool) !*Statement {
        var names = std.ArrayList(*Identifier).init(self.allocator);
        for (lhs.expressions.items) |expr| {
            if (try evaluateIdentifierExpression(expr)) |ident| {
                try names.append(ident);
            } else {
                self.err("Expected identifier, got `{}`", .{@tagName(expr.*)});
                return error.ParseDeclarationStatement;
            }
        }

        return try self.parseDeclarationStatementTail(names, is_using);
    }

    fn parseAssignmentStatement(self: *Parser, lhs: *TupleExpression) !*Statement {
        if (self.this_procedure == null) {
            self.err("Assignment statements can only be used in procedures", .{});
            return error.ParseAssignmentStatement;
        }

        if (self.this_token.un != .assignment) {
            self.err("Expected assignment operator, got `{}`", .{@tagName(self.this_token.un)});
            return error.ParseAssignmentStatement;
        }
        const kind = self.this_token.un.assignment;

        _ = try self.advance();
        const rhs = try self.parseRhsTupleExpression();
        if (rhs.expressions.items.len == 0) {
            self.err("Missing right-hand side of assignment", .{});
            return error.ParseAssignmentStatement;
        }

        return try self.tree.newAssignmentStatement(kind, lhs, rhs);
    }

    fn parseSimpleStatement(self: *Parser, block_flags: BlockFlags, allow_in: bool, allow_label: bool) !*Statement {
        const lhs = try self.parseLhsTupleExpression();
        switch (self.this_token.un) {
            .assignment => return try self.parseAssignmentStatement(lhs),
            .operator => |op| switch (op) {
                .in => {
                    if (allow_in) {
                        const prev_allow_in = self.allow_in;
                        self.allow_in = false;
                        try self.expectOperator(.in);
                        const rhs = try self.parseExpression(true);
                        const expression = self.tree.newBinaryExpression(.in, lhs, rhs);
                        const statement = try self.tree.newExpressionStatement(expression);
                        self.allow_in = prev_allow_in;
                        return statement;
                    }
                },
                .colon => {
                    _ = try self.advance();

                    if (allow_label and lhs.tuple.expressions.items == 1) {
                        const token = self.this_token;
                        if (isKind(token, .lbrace) or isKeyword(token, .@"if") or isKeyword(token, .@"for") or isKeyword(token, .@"switch")) {
                            const name = lhs.tuple.expressions.items[0];
                            if (name != .identifier) {
                                self.err("Expected identifier for label, got `{}`", .{@tagName(name.*)});
                                return error.ParseSimpleStatement;
                            }
                            const label = name.identifier.identifier;
                            const statement = (try self.parseStatement(block_flags)) orelse {
                                self.err("Expected statement after label `{}`", .{label});
                                return error.ParseSimpleStatement;
                            };
                            switch (statement.*) {
                                .block => |*blk| blk.label = label,
                                .@"if" => |*i| i.label = label,
                                .@"for" => |*f| f.label = label,
                                .@"switch" => |*s| s.label = label,
                                else => {
                                    self.err("Cannot apply block `{}` to `{}`", .{ label, @tagName(statement.*) });
                                    return error.ParseSimpleStatement;
                                },
                            }
                            return statement;
                        }

                        return try self.parseDeclarationStatement(lhs, false);
                    }
                },
                else => {},
            },
            else => {},
        }

        const expressions = lhs.tuple.expressions;
        if (expressions.items.len == 0 or expressions.items.len > 1) {
            self.err("Expected single expression for declaration, got `{}`", .{expressions.items.len});
            return error.ParseSimpleStatement;
        }

        return try self.tree.newExpressionStatement(expressions.items[0]);
    }

    fn record(self: *Parser) void {
        self.tree.recordToken(self.this_token);
    }
};

fn isKind(token: lexer.Token, kind: lexemes.TokenKind) bool {
    return token.un == kind;
}

fn isOperator(token: lexer.Token, kind: lexemes.OperatorKind) bool {
    return token.un == lexemes.TokenKind.operator and token.un.operator == kind;
}

fn isKeyword(token: lexer.Token, kind: lexemes.KeywordKind) bool {
    return token.un == lexemes.TokenKind.keyword and token.un.keyword == kind;
}

fn isAssignment(token: lexer.Token, kind: lexemes.AssignmentKind) bool {
    return token.un == lexemes.TokenKind.assignment and token.un.assignment == kind;
}

fn isLiteral(token: lexer.Token, kind: lexemes.LiteralKind) bool {
    return token.un == lexemes.TokenKind.literal and token.un.literal == kind;
}

fn isNewline(token: lexer.Token) bool {
    return token.un == lexemes.TokenKind.semicolon and std.mem.eql(u8, token.string[0], "\n");
}

test {
    std.testing.refAllDecls(@This());
}
