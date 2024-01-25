const std = @import("std");

const Tree = @import("Tree.zig");
const parser = @import("parser.zig");

const Context = @import("Context.zig");

const util = @import("../util.zig");

pub const Collection = struct {
    name: []const u8,
    path: []const u8,
};

pub const Project = struct {
    allocator: std.mem.Allocator = undefined,
    context: ?*const Context = null,

    mutex: std.Thread.Mutex = .{},
    pathname: []const u8 = "",
    packages: std.ArrayList(Package) = undefined,

    pub fn init(
        self: *Project,
        allocator: std.mem.Allocator,
        pathname: []const u8,
        context: ?*const Context,
    ) void {
        self.allocator = allocator;
        self.context = context;
        self.pathname = pathname;
        self.packages = std.ArrayList(Package).init(allocator);
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
        pathname: []const u8,
    ) !*Package {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.packages.items) |package| {
            if (std.mem.eql(u8, package.pathname, pathname)) {
                self.err("package already exists: {s}", .{pathname});
                return error.AlreadyExists;
            }
        }

        var package = try self.packages.addOne();
        try package.init(
            self,
            self.allocator,
            pathname,
        );
        return package;
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

    pathname: []const u8 = "",
    mutex: std.Thread.Mutex = .{},
    trees: std.ArrayList(Tree) = undefined,

    pub fn init(
        self: *Package,
        parent_project: *Project,
        allocator: std.mem.Allocator,
        pathname: []const u8,
    ) !void {
        self.parent_project = parent_project;
        self.allocator = allocator;
        self.pathname = pathname;
        self.mutex = .{};
        self.trees = std.ArrayList(Tree).init(self.allocator);
    }

    pub fn deinit(self: *Package) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.trees.items) |*t| {
            t.deinit();
        }
        self.trees.deinit();
    }

    pub fn addTree(self: *Package, name: []const u8) !*Tree {
        self.mutex.lock();
        defer self.mutex.unlock();
        const tree = try self.trees.addOne();
        try tree.init(self.allocator, name, self.parent_project.context);
        return tree;
    }

    // pub fn processed(self: *Package) bool {
    //     self.mutex.lock();
    //     defer self.mutex.unlock();
    //     return self.done_count == self.sources.len;
    // }

    // pub fn processBlocking(self: *Package) !void {
    //     for (self.sources) |_| {
    //         try self.processOne();
    //     }
    // }

    // pub fn processOne(self: *Package) !void {
    //     self.mutex.lock();
    //     const index = self.trees.items.len;
    //     var tree = self.trees.addOneAssumeCapacity();
    //     self.mutex.unlock();
    //     try tree.init(
    //         self.allocator,
    //         self.collection,
    //         self.parent_project.context,
    //     );

    //     const source = self.sources[index];
    //     try parser.parse(tree, source);

    //     for (tree.imports.items) |imp_index| {
    //         const import_statement = tree.getStatementConst(imp_index).import;
    //         try self.parent_project.addPackage(
    //             import_statement.collection,
    //             import_statement.pathname,
    //         );
    //     }
    //     // std.log.warn("{any}", .{tree.all_statements.items});

    //     self.mutex.lock();
    //     self.done_count += 1;
    //     self.mutex.unlock();
    // }
};

pub const Build = struct {
    allocator: std.mem.Allocator = undefined,
    context: ?*const Context = null,
    file_provider: util.FileProvider = undefined,

    project: Project = undefined,
    collections: std.ArrayList(Collection) = undefined,
    pool: std.Thread.Pool = undefined,
    wait_group: std.Thread.WaitGroup = .{},

    mutex: std.Thread.Mutex = .{},
    work_list: std.ArrayList(Work) = undefined,

    pub const Work = struct {
        builder: *Build,
        package: *const Package,
        pathname: []const u8,
        tree: *Tree,
        err: bool,
    };

    pub fn init(
        self: *Build,
        allocator: std.mem.Allocator,
        context: ?*const Context,
        file_provider: util.FileProvider,
    ) !void {
        self.allocator = allocator;
        self.context = context;
        self.file_provider = file_provider;
        try self.pool.init(std.Thread.Pool.Options{ .allocator = allocator });
        self.wait_group = .{};
        self.mutex = .{};
        self.work_list = std.ArrayList(Work).init(allocator);
        self.collections = std.ArrayList(Collection).init(allocator);

        self.project.init(
            allocator,
            "",
            context,
        );
    }

    pub fn deinit(self: *Build) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.pool.deinit();
        self.work_list.deinit();
        self.collections.deinit();
        self.project.deinit();
    }

    pub fn wait(self: *Build) void {
        self.pool.waitAndWork(&self.wait_group);
    }

    pub fn addCollection(self: *Build, name: []const u8, path: []const u8) !void {
        if (!self.file_provider.directoryExists(path)) {
            self.err("Collection path `{s}` does not exist", .{path});
            return error.NotFound;
        }

        for (self.collections.items) |c| {
            if (std.mem.eql(u8, c.name, name)) {
                return error.AlreadyExists;
            }
        }

        try self.collections.append(Collection{
            .name = name,
            .path = path,
        });
    }

    pub fn addPackage(self: *Build, path: []const u8) !void {
        const package = try self.project.addPackage(path);

        var buf = std.mem.zeroes([1024]u8);
        var fba = std.heap.FixedBufferAllocator.init(&buf);

        const files = try self.file_provider.getFilesForDirectory(
            fba.allocator(),
            path,
        );
        for (files.items) |file| {
            if (!std.mem.endsWith(u8, file, ".rl")) {
                continue;
            }
            fba.reset();
            const source = try std.mem.join(fba.allocator(), "/", &.{ path, file });
            self.wait_group.start();
            // try self.pool.spawn(worker, .{try self.addWork(package, source)});
            try tryingWorker(try self.addWork(package, source));
        }
    }

    pub fn findCollection(self: *Build, collection: []const u8) ![]const u8 {
        for (self.collections.items) |c| {
            if (std.mem.eql(u8, c.name, collection)) {
                return c.path;
            }
        }
        self.err("Cannot find collection `{s}`", .{collection});
        return error.NotFound;
    }

    fn addWork(self: *Build, package: *Package, name: []const u8) !*Work {
        self.mutex.lock();
        defer self.mutex.unlock();
        const work = try self.work_list.addOne();
        work.builder = self;
        work.err = false;
        work.tree = try package.addTree(name);
        work.package = package;
        work.pathname = name;
        return work;
    }

    fn worker(work: *Work) void {
        tryingWorker(work) catch |e| {
            work.err = true;
            std.debug.print("ERROR {}\n", .{e});
        };
    }

    pub const WorkerError = util.FileProvider.Error || parser.Error || error{
        InvalidPackageName,
        AlreadyExists,
    };
    fn tryingWorker(work: *Work) WorkerError!void {
        defer work.builder.wait_group.finish();
        const source = (try work.builder.file_provider.readFile(work.pathname)) orelse "";
        try parser.parse(work.tree, source);

        if (work.tree.statements.items.len == 0) {
            return;
        }
        const first_stmt = work.tree.getStatementConst(work.tree.statements.items[0]);
        const package_name: ?[]const u8 = if (first_stmt.* == .package) first_stmt.package.name else null;
        if (package_name) |name| {
            if (std.mem.eql(u8, name, "_")) {
                work.builder.err("package name cannot be `_`", .{});
                return error.InvalidPackageName;
            } else if (std.mem.eql(u8, name, "intrinsics") or
                std.mem.eql(u8, name, "builtin"))
            {
                work.builder.err(
                    "use of reserved package name `{s}`",
                    .{name},
                );
                return error.InvalidPackageName;
            }
        }

        for (work.tree.imports.items) |import| {
            const import_statement = work.tree.getStatementConst(import).import;
            if (std.mem.eql(u8, import_statement.collection, "core")) {
                if (std.mem.eql(u8, import_statement.pathname, "intrinsics") or
                    std.mem.eql(u8, import_statement.pathname, "builtin"))
                {
                    continue;
                }
            }
            const pathname = if (import_statement.collection.len == 0)
                work.package.pathname
            else
                work.builder.findCollection(import_statement.collection) catch {
                    work.builder.err("Cannot find collection `{s}`", .{import_statement.collection});
                    return error.NotFound;
                };

            var buf = std.mem.zeroes([512]u8);
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            const resolved_source = try std.mem.join(fba.allocator(), "/", &.{
                pathname,
                import_statement.pathname,
            });
            try work.builder.addPackage(resolved_source);
        }
    }

    fn err(self: *Build, comptime msg: []const u8, args: anytype) void {
        if (self.context) |ctx| {
            ctx.err(null, msg, args);
        }
    }
};
