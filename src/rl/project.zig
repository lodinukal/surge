const std = @import("std");

const Tree = @import("Tree.zig");
const parser = @import("parser.zig");

const Context = @import("Context.zig");

const util = @import("core").util;

pub const Collection = struct {
    name: []const u8,
    path: []const u8,
};

pub const Project = struct {
    context: *const Context = undefined,

    mutex: std.Thread.Mutex = .{},
    pathname: []const u8 = "",
    packages: std.ArrayList(Package) = undefined,

    pub fn init(
        self: *Project,
        context: *const Context,
        pathname: []const u8,
    ) void {
        self.context = context;
        self.pathname = pathname;
        self.packages = std.ArrayList(Package).init(context.allocator);
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
        var found = true;
        _ = self.findPackage(pathname) catch {
            found = false;
        };
        if (found) {
            return error.AlreadyExists;
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        var package = try self.packages.addOne();
        try package.init(
            self,
            try self.context.allocator.dupe(u8, pathname),
        );
        return package;
    }

    pub fn findPackage(
        self: *Project,
        pathname: []const u8,
    ) !*Package {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.packages.items) |*package| {
            if (std.mem.eql(u8, package.pathname, pathname)) {
                return package;
            }
        }

        return error.NotFound;
    }
};

pub const Package = struct {
    parent_project: *Project = undefined,

    pathname: []const u8 = "",
    mutex: std.Thread.Mutex = .{},
    trees: std.ArrayList(Tree) = undefined,

    pub fn init(
        self: *Package,
        parent_project: *Project,
        pathname: []const u8,
    ) !void {
        self.parent_project = parent_project;
        self.pathname = pathname;
        self.mutex = .{};
        self.trees = std.ArrayList(Tree).init(parent_project.context.allocator);
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
        tree.* = try Tree.init(
            self.parent_project.context.allocator,
            name,
        );
        return tree;
    }
};

pub const Build = struct {
    context: *const Context = undefined,

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
        context: *const Context,
    ) !void {
        self.context = context;
        try self.pool.init(std.Thread.Pool.Options{ .allocator = context.allocator });
        self.wait_group = .{};
        self.mutex = .{};
        self.work_list = std.ArrayList(Work).init(context.allocator);
        self.collections = std.ArrayList(Collection).init(context.allocator);

        self.project.init(
            context,
            "",
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
        _ = self.context.file_provider.get(path, .directory) catch |err| {
            if (err == error.NotFound) {
                self.context.err("Collection path `{s}` does not exist", .{path});
                return error.NotFound;
            }
            return err;
        };

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

        const dir = try self.context.file_provider.get(
            path,
            .directory,
        );
        var it = try dir.iterator();
        while (it.next()) |file_node| {
            const file_name = try file_node.getName();
            if (!std.mem.endsWith(u8, file_name, ".rl")) {
                continue;
            }
            var buf = std.mem.zeroes([1024]u8);
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            const source = try std.mem.join(fba.allocator(), "/", &.{ path, file_name });
            self.wait_group.start();
            // try self.pool.spawn(worker, .{try self.addWork(package, source)});
            try tryingWorker(try self.addWork(package, try self.context.allocator.dupe(u8, source)));
        }
    }

    pub fn findCollection(self: *Build, collection: []const u8) ![]const u8 {
        for (self.collections.items) |c| {
            if (std.mem.eql(u8, c.name, collection)) {
                return c.path;
            }
        }
        self.context.err("Cannot find collection `{s}`", .{collection});
        return error.NotFound;
    }

    pub fn findPackage(self: *Build, pathname: []const u8) !*Package {
        return try self.project.findPackage(pathname);
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
        const file_node = try work.builder.context.file_provider.get(
            work.pathname,
            .file,
        );
        const source = (try file_node.read()) orelse "";
        try parser.parse(work.builder.context, work.tree, source);

        if (work.tree.statements.items.len == 0) {
            return;
        }
        const first_stmt = work.tree.getStatementConst(work.tree.statements.items[0]);
        const package_name: ?[]const u8 = if (first_stmt.* == .package) first_stmt.package.name else null;
        if (package_name) |name| {
            if (std.mem.eql(u8, name, "_")) {
                work.builder.context.err("package name cannot be `_`", .{});
                return error.InvalidPackageName;
            } else if (std.mem.eql(u8, name, "intrinsics") or
                std.mem.eql(u8, name, "builtin"))
            {
                work.builder.context.err(
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

            var buf = std.mem.zeroes([512]u8);
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            const resolved_source = try work.builder.resolveFullPathname(
                fba.allocator(),
                work.package.pathname,
                import_statement.collection,
                import_statement.pathname,
            );
            try work.builder.addPackage(resolved_source);
        }
    }

    pub fn resolveFullPathname(
        self: *Build,
        allocator: std.mem.Allocator,
        base: []const u8,
        collection: []const u8,
        pathname: []const u8,
    ) ![]const u8 {
        const look_path = if (collection.len == 0)
            base
        else
            self.findCollection(collection) catch {
                self.context.err("Cannot find collection `{s}`", .{collection});
                return error.NotFound;
            };

        const resolved_source = try std.mem.join(allocator, "/", &.{
            look_path,
            pathname,
        });

        return resolved_source;
    }
};
