const std = @import("std");

const Tree = @import("Tree.zig");
const parser = @import("parser.zig");

const Context = @import("Context.zig");

pub const Collection = struct {
    pathname: []const u8,
    path: []const u8,
};

pub const Project = struct {
    allocator: std.mem.Allocator = undefined,
    context: ?*const Context = null,

    mutex: std.Thread.Mutex = .{},
    pathname: []const u8 = "",
    packages: std.ArrayList(Package) = undefined,

    source_collector: SourceCollector = undefined,
    pub const SourceCollectorError = error{
        CollectSources,
        NotFound,
    };
    pub const SourceCollector = *const fn (
        collection: []const u8,
        pathname: []const u8,
    ) SourceCollectorError![]const []const u8;

    pub fn init(
        self: *Project,
        allocator: std.mem.Allocator,
        pathname: []const u8,
        source_collector: SourceCollector,
        context: ?*const Context,
    ) void {
        self.allocator = allocator;
        self.context = context;
        self.pathname = pathname;
        self.packages = std.ArrayList(Package).init(allocator);
        self.source_collector = source_collector;
    }

    pub fn deinit(self: *Project) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.packages.items) |*package| {
            package.deinit();
        }
        self.packages.deinit();
    }

    pub fn addPackage(
        self: *Project,
        collection: []const u8,
        pathname: []const u8,
    ) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const sources = self.source_collector(collection, pathname) catch {
            self.err(
                "failed to collect sources for package `{s}` in collection `{s}`",
                .{ pathname, collection },
            );
            return error.CollectSources;
        };

        var package = try self.packages.addOne();
        try package.init(
            self,
            self.allocator,
            collection,
            sources,
        );
    }

    pub fn processBlocking(self: *Project) !void {
        var index: usize = 0;
        while (true) {
            var package = &self.packages.items[index];
            try package.processBlocking();

            {
                self.mutex.lock();
                defer self.mutex.unlock();

                index += 1;
                if (index >= self.packages.items.len) {
                    return;
                }
            }
        }
    }

    fn err(self: *Project, comptime msg: []const u8, args: anytype) void {
        if (self.context) |ctx| {
            ctx.err(null, msg, args);
        }
    }
};

pub const Package = struct {
    parent_project: *Project = undefined,
    allocator: std.mem.Allocator = undefined,
    collection: []const u8 = "",

    mutex: std.Thread.Mutex = .{},
    trees: std.ArrayList(Tree) = undefined,
    sources: []const []const u8 = &.{},
    done_count: usize = 0,

    pub fn init(
        self: *Package,
        parent_project: *Project,
        allocator: std.mem.Allocator,
        collection: []const u8,
        sources: []const []const u8,
    ) !void {
        self.parent_project = parent_project;
        self.allocator = allocator;
        self.collection = collection;
        self.sources = sources;
        self.done_count = 0;
        self.mutex = .{};
        self.trees = try std.ArrayList(Tree).initCapacity(self.allocator, sources.len);
    }

    pub fn deinit(self: *Package) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.trees.items) |*t| {
            t.deinit();
        }
        self.trees.deinit();
    }

    pub fn processed(self: *Package) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.done_count == self.sources.len;
    }

    pub fn processBlocking(self: *Package) !void {
        for (self.sources) |_| {
            try self.processOne();
        }
    }

    pub fn processOne(self: *Package) !void {
        self.mutex.lock();
        const index = self.trees.items.len;
        var tree = self.trees.addOneAssumeCapacity();
        self.mutex.unlock();
        try tree.init(
            self.allocator,
            self.collection,
            self.parent_project.context,
        );

        const source = self.sources[index];
        try parser.parse(tree, source);

        for (tree.imports.items) |imp_index| {
            const import_statement = tree.getStatementConst(imp_index).import;
            try self.parent_project.addPackage(
                import_statement.collection,
                import_statement.pathname,
            );
        }
        // std.log.warn("{any}", .{tree.all_statements.items});

        self.mutex.lock();
        self.done_count += 1;
        self.mutex.unlock();
    }
};

const test_main =
    \\using import "surge:intrinsics"
    \\
    \\fragment :: proc() {
    \\  if (should_clear) { discard(); }
    \\}
;

const test_intrinsics =
    \\discard :: proc() -> ! {}
;

fn testSourceCollector(collection: []const u8, pathname: []const u8) ![]const []const u8 {
    if (std.mem.eql(u8, collection, "")) {
        if (std.mem.eql(u8, pathname, "main")) {
            return &.{test_main};
        }
    }
    if (std.mem.eql(u8, collection, "surge") and std.mem.eql(u8, pathname, "intrinsics")) {
        return &.{test_intrinsics};
    }
    return error.NotFound;
}

test {
    const allocator = std.testing.allocator;

    var project = Project{};
    defer project.deinit();
    project.init(allocator, "test", testSourceCollector, &.{
        .err_handler = @import("rlth.zig").handle_err,
    });
    try project.addPackage("", "main");

    try project.processBlocking();
}
