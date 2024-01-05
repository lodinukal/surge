const std = @import("std");

const Tokeniser = @import("./tokeniser.zig").Tokeniser;
const Token = @import("./tokeniser.zig").Token;
const ast = @import("ast.zig");

pub const ErrorHandler = @import("./tokeniser.zig").ErrorHandler;
pub const WarningHandler = *const fn (pos: Token.Pos, msg: []const u8) void;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    file: ?*ast.File = null,
    tok: Tokeniser = .{},

    err_handler: ?ErrorHandler,
    warn_handler: ?WarningHandler,

    previous_token: Token = std.mem.zeroes(Token),
    current_token: Token = std.mem.zeroes(Token),

    expression_level: i32 = 0,
    allow_range: bool = false,
    allow_in_expr: bool = false,
    allow_type: bool = false,

    lead_comment: ?*ast.CommentGroup = null,
    line_comment: ?*ast.CommentGroup = null,

    current_fn: ?*ast.Node = null,

    error_count: i32 = 0,

    fix_count: i32 = 0,
    fix_previous_pos: Token.Pos = std.mem.zeroes(Token.Pos),

    peeking: bool = false,

    fn default_error_handler(pos: Token.Pos, msg: []const u8) void {
        std.debug.print("{s}:{}:{}: error: {s}\n", .{ pos.location, pos.line, pos.column, msg });
    }

    fn default_warning_handler(pos: Token.Pos, msg: []const u8) void {
        std.debug.print("{s}:{}:{}: warning: {s}\n", .{ pos.location, pos.line, pos.column, msg });
    }

    inline fn err(p: *Parser, pos: Token.Pos, msg: []const u8, args: anytype) void {
        var buf = std.mem.zeroes([1024]u8);
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const temp_allocator = fba.allocator();

        if (p.err_handler) |handler| {
            const fmtted = std.fmt.allocPrint(temp_allocator, msg, args) catch unreachable;
            handler(pos, fmtted);
        }

        p.error_count += 1;
        p.file.syntax_error_count += 1;
    }

    inline fn warn(p: *Parser, pos: Token.Pos, msg: []const u8, args: anytype) void {
        var buf = std.mem.zeroes([1024]u8);
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const temp_allocator = fba.allocator();

        if (p.warn_handler) |handler| {
            const fmtted = std.fmt.allocPrint(temp_allocator, msg, args) catch unreachable;
            handler(pos, fmtted);
        }

        p.file.syntax_warning_count += 1;
    }

    fn tokenEndPos(tok: Token) Token.Pos {
        var pos = tok.pos;
        pos.offset += tok.literal.len;

        if (tok.kind == .comment) {
            for (tok.literal) |c| {
                if (c == '\n') {
                    pos.line += 1;
                    pos.column = 1;
                } else {
                    pos.column += 1;
                }
            }
        } else {
            pos.column += tok.literal.len;
        }
        return pos;
    }

    pub fn default(allocator: std.mem.Allocator) Parser {
        return Parser{
            .allocator = allocator,
            .err_handler = default_error_handler,
            .warn_handler = default_warning_handler,
        };
    }

    fn isPackageNameReserved(name: []const u8) bool {
        return (std.mem.indexOfDiff(u8, name, "builtin") == null);
    }

    pub fn parseFile(p: *Parser, file: *ast.File) !void {
        {
            p.previous_token = std.mem.zeroes(Token);
            p.current_token = std.mem.zeroes(Token);
            p.expression_level = 0;
            p.allow_range = false;
            p.allow_in_expr = false;
            p.allow_type = false;
            p.lead_comment = null;
            p.line_comment = null;
        }

        p.file = file;
        try p.tok.init(p.allocator, file.full_path, file.source, p.err_handler);
        if (p.tok.cp <= 0) {
            return true;
        }

        p.advanceToken();
        p.consumeCommentGroups(p.previous_token);

        const docs = p.lead_comment;
        _ = docs; // autofix

        p.file.?.package_token = p.expectToken(.package);
        if (p.file.?.package_token.kind != .package) {
            return error.UnexpectedToken;
        }
    }
};

pub const ImportDeclarationKind = enum {
    standard,
    using,
};
