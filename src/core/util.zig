const std = @import("std");

pub fn enumFromValue(comptime E: type, value: anytype) E {
    const typeInfo = @typeInfo(@TypeOf(value));
    if (typeInfo == std.builtin.Type.EnumLiteral) {
        return @as(E, value);
    } else if (typeInfo == .Int) {
        return @enumFromInt(value);
    } else if (@TypeOf(value) == E) {
        return value;
    } else {
        @compileError("enumFromValue: invalid type: " ++ @TypeOf(value));
    }
}

pub fn orEnum(comptime E: type, other: anytype) E {
    var result = @intFromEnum(enumFromValue(E, other.@"0"));
    inline for (other, 0..) |o, i| {
        if (i == 0) continue;
        result |= @intFromEnum(enumFromValue(E, o));
    }
    return @enumFromInt(result);
}

pub fn andEnum(comptime E: type, other: anytype) E {
    var result = @intFromEnum(enumFromValue(E, other.@"0"));
    inline for (other, 0..) |o, i| {
        if (i == 0) continue;
        result &= @intFromEnum(enumFromValue(E, o));
    }
    return @enumFromInt(result);
}

pub fn xorEnum(comptime E: type, other: anytype) E {
    var result = @intFromEnum(enumFromValue(E, other.@"0"));
    inline for (other, 0..) |o, i| {
        if (i == 0) continue;
        result ^= @intFromEnum(enumFromValue(E, o));
    }
    return @enumFromInt(result);
}

pub fn ErrorEnum(comptime E: type) type {
    const ti = @typeInfo(E);
    const error_set = ti.ErrorSet.?;
    comptime var enum_fields: [error_set.len]std.builtin.Type.EnumField = undefined;
    inline for (error_set, 0..) |e, index| {
        enum_fields[index] = .{
            .name = e.name,
            .value = index,
        };
    }

    return @Type(std.builtin.Type{
        .Enum = .{
            .tag_type = u16,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

pub fn errorEnumFromError(comptime E: type, err: E) ErrorEnum(E) {
    return @field(ErrorEnum(E), @errorName(err));
}

pub fn errorFromErrorEnum(comptime E: type, err: E) E {
    return @field(E, @tagName(err));
}

pub const FileProvider = struct {
    pub const Error = error{
        NotFound,
        OutOfMemory,
        IsNotDirectory,
        IsNotFile,
        DeletedNode,
    };
    pub const Handle = usize;

    pub const Kind = enum {
        file,
        directory,
    };

    pub inline fn getRootNode(self: FileProvider) Node {
        return self.pfn_get_root_node(self);
    }

    pub const Node = struct {
        provider: FileProvider,
        handle: Handle,

        pub inline fn iterator(self: Node) Error!FileProvider.Iterator {
            return self.provider.pfn_get_iterator(self.provider, self);
        }

        pub inline fn get(self: Node, path: []const u8, kind: Kind) Error!Node {
            return self.provider.pfn_get_node_from(self.provider, self, path, kind);
        }

        pub inline fn getName(self: Node) Error![]const u8 {
            return self.provider.pfn_get_node_name(self.provider, self);
        }

        pub inline fn getKind(self: Node) Error!Kind {
            return self.provider.pfn_get_node_kind(self.provider, self);
        }

        pub inline fn read(self: Node) Error!?[]const u8 {
            return self.provider.pfn_read(self.provider, self);
        }

        pub inline fn setContents(self: Node, contents: ?[]const u8) Error {
            return self.provider.pfn_set_node_contents(self.provider, self, contents);
        }

        pub inline fn delete(self: Node) Error!void {
            return self.provider.pfn_delete_node(self.provider, self);
        }

        pub inline fn createDirectory(self: Node, name: []const u8) Error!Node {
            return self.provider.pfn_create_directory(self.provider, self, name);
        }

        pub inline fn createDirectories(self: Node, path: []const u8) Error!Node {
            return self.provider.pfn_create_directories(self.provider, self, path);
        }

        pub inline fn createFile(
            self: Node,
            name: []const u8,
            contents: ?[]const u8,
        ) Error!Node {
            return self.provider.pfn_create_file(self.provider, self, name, contents);
        }

        pub fn getFullName(self: Node, allocator: std.mem.Allocator) Error![]const u8 {
            return self.provider.pfn_get_full_name(self.provider, allocator, self);
        }

        pub fn createTree(self: Node, tree: anytype) Error!void {
            switch (@typeInfo(@TypeOf(tree))) {
                .Struct => |s| {
                    const fields = s.fields;
                    try self.createTreeInternal(fields);
                },
                else => {},
            }
        }

        fn createTreeInternal(
            self: Node,
            comptime fields: []const std.builtin.Type.StructField,
        ) !void {
            inline for (fields) |f| {
                const is_directory = @typeInfo(f.type) == .Struct;
                if (is_directory) {
                    const directory = try self.createDirectory(f.name);
                    try directory.createTreeInternal(@typeInfo(f.type).Struct.fields);
                } else {
                    const name_raw: [*:0]const u8 = @ptrCast(@alignCast(f.default_value.?));
                    _ = try self.createFile(
                        f.name,
                        std.mem.span(name_raw),
                    );
                }
            }
        }
    };

    pub const Iterator = struct {
        provider: FileProvider,
        dir: Node,
        data: usize,
        done: bool = false,

        pub inline fn next(self: *Iterator) ?Node {
            return self.provider.pfn_iterator_node(self.provider, self);
        }
    };

    pub const delimiter = '/';
    pub const Component = union(enum) {
        none,
        up,
        down: []const u8,
    };
    pub fn getComponent(str: []const u8) Component {
        if (str.len == 0) return .none;
        if (std.mem.eql(u8, str, "..")) return .up;
        return .{ .down = str };
    }

    pub fn get(self: FileProvider, path: []const u8, kind: Kind) !Node {
        return self.getRootNode().get(path, kind);
    }

    context: ?*anyopaque = null,
    pfn_get_root_node: *const fn (self: FileProvider) Node,
    pfn_iterator_node: *const fn (self: FileProvider, it: *Iterator) ?Node,
    pfn_get_iterator: *const fn (self: FileProvider, dir: Node) Error!Iterator,
    pfn_get_node_from: *const fn (
        self: FileProvider,
        parent: Node,
        path: []const u8,
        kind: Kind,
    ) Error!Node,
    pfn_get_node_name: *const fn (self: FileProvider, node: Node) Error![]const u8,
    pfn_get_node_kind: *const fn (self: FileProvider, node: Node) Error!Kind,
    pfn_read: *const fn (
        self: FileProvider,
        node: Node,
    ) Error!?[]const u8,
    pfn_set_node_contents: *const fn (
        self: FileProvider,
        node: Node,
        contents: ?[]const u8,
    ) Error!void,
    pfn_delete_node: *const fn (self: FileProvider, node: Node) Error!void,
    pfn_create_directory: *const fn (
        self: FileProvider,
        parent: Node,
        name: []const u8,
    ) Error!Node,
    pfn_create_directories: *const fn (
        self: FileProvider,
        parent: Node,
        path: []const u8,
    ) Error!Node,
    pfn_create_file: *const fn (
        self: FileProvider,
        parent: Node,
        name: []const u8,
        contents: ?[]const u8,
    ) Error!Node,
    pfn_get_full_name: *const fn (
        self: FileProvider,
        allocator: std.mem.Allocator,
        node: Node,
    ) Error![]const u8,
};

pub const LinearMemoryFileProvider = struct {
    pub const FileNode = union(enum) {
        pub const Active = struct {
            name: []const u8 = "",
            next: ?FileProvider.Node = null,
            parent: ?FileProvider.Node = null,
            un: union(FileProvider.Kind) {
                file: ?[]const u8,
                directory: ?FileProvider.Node,
            },
        };
        active: Active,
        free: ?FileProvider.Node,
    };
    mutex: std.Thread.Mutex = .{},
    files: std.ArrayList(FileNode) = undefined,
    free_list: ?FileProvider.Node = null,
    pub const root = 0;

    pub fn init(
        self: *LinearMemoryFileProvider,
        allocator: std.mem.Allocator,
    ) !void {
        self.* = LinearMemoryFileProvider{
            .mutex = .{},
            .files = try std.ArrayList(FileNode).initCapacity(allocator, 1),
        };
        self.files.appendAssumeCapacity(.{
            .active = .{
                .name = "root",
                .un = .{
                    .directory = null,
                },
            },
        });
    }

    pub fn deinit(self: *LinearMemoryFileProvider) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.files.deinit();
    }

    pub fn fileProvider(self: *LinearMemoryFileProvider) FileProvider {
        const Glue = struct {
            fn this(fp: FileProvider) *LinearMemoryFileProvider {
                return @ptrCast(@alignCast(fp.context.?));
            }

            pub fn getRootNode(fp: FileProvider) FileProvider.Node {
                return LinearMemoryFileProvider.getRootNode(this(fp));
            }

            pub fn iteratorNode(fp: FileProvider, it: *FileProvider.Iterator) ?FileProvider.Node {
                return LinearMemoryFileProvider.iteratorNode(this(fp), it);
            }

            pub fn getIterator(
                fp: FileProvider,
                dir: FileProvider.Node,
            ) FileProvider.Error!FileProvider.Iterator {
                return LinearMemoryFileProvider.getIterator(this(fp), dir);
            }

            pub fn getNodeFrom(
                fp: FileProvider,
                parent: FileProvider.Node,
                path: []const u8,
                kind: FileProvider.Kind,
            ) FileProvider.Error!FileProvider.Node {
                return LinearMemoryFileProvider.getNodeFrom(this(fp), parent, path, kind);
            }

            pub fn getNodeName(
                fp: FileProvider,
                node: FileProvider.Node,
            ) FileProvider.Error![]const u8 {
                return LinearMemoryFileProvider.getNodeName(this(fp), node);
            }

            pub fn getNodeKind(
                fp: FileProvider,
                node: FileProvider.Node,
            ) FileProvider.Error!FileProvider.Kind {
                return LinearMemoryFileProvider.getNodeKind(this(fp), node);
            }

            pub fn read(
                fp: FileProvider,
                node: FileProvider.Node,
            ) FileProvider.Error!?[]const u8 {
                return LinearMemoryFileProvider.read(this(fp), node);
            }

            pub fn setNodeContents(
                fp: FileProvider,
                node: FileProvider.Node,
                contents: ?[]const u8,
            ) FileProvider.Error!void {
                return LinearMemoryFileProvider.setNodeContents(this(fp), node, contents);
            }

            pub fn deleteNode(
                fp: FileProvider,
                node: FileProvider.Node,
            ) FileProvider.Error!void {
                return LinearMemoryFileProvider.deleteNode(this(fp), node);
            }

            pub fn createDirectory(
                fp: FileProvider,
                parent: FileProvider.Node,
                name: []const u8,
            ) FileProvider.Error!FileProvider.Node {
                return LinearMemoryFileProvider.createDirectory(this(fp), parent, name);
            }

            pub fn createDirectories(
                fp: FileProvider,
                parent: FileProvider.Node,
                path: []const u8,
            ) FileProvider.Error!FileProvider.Node {
                return LinearMemoryFileProvider.createDirectories(this(fp), parent, path);
            }

            pub fn createFile(
                fp: FileProvider,
                parent: FileProvider.Node,
                name: []const u8,
                contents: ?[]const u8,
            ) FileProvider.Error!FileProvider.Node {
                return LinearMemoryFileProvider.createFile(this(fp), parent, name, contents);
            }

            pub fn getFullName(
                fp: FileProvider,
                allocator: std.mem.Allocator,
                node: FileProvider.Node,
            ) FileProvider.Error![]const u8 {
                return LinearMemoryFileProvider.getFullName(this(fp), allocator, node);
            }
        };
        return .{
            .context = @ptrCast(self),
            .pfn_get_root_node = Glue.getRootNode,
            .pfn_iterator_node = Glue.iteratorNode,
            .pfn_get_iterator = Glue.getIterator,
            .pfn_get_node_from = Glue.getNodeFrom,
            .pfn_get_node_name = Glue.getNodeName,
            .pfn_get_node_kind = Glue.getNodeKind,
            .pfn_read = Glue.read,
            .pfn_set_node_contents = Glue.setNodeContents,
            .pfn_delete_node = Glue.deleteNode,
            .pfn_create_directory = Glue.createDirectory,
            .pfn_create_directories = Glue.createDirectories,
            .pfn_create_file = Glue.createFile,
            .pfn_get_full_name = Glue.getFullName,
        };
    }

    pub fn getFileNodeActive(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) !*FileNode.Active {
        const found = try self.getFileNode(node);
        if (found.* == .free) return error.DeletedNode;
        return &found.active;
    }

    pub fn getFileNode(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) !*FileNode {
        if (node.handle >= self.files.items.len) return error.NotFound;
        return &self.files.items[node.handle];
    }

    pub fn getRootNode(self: *LinearMemoryFileProvider) FileProvider.Node {
        return FileProvider.Node{
            .provider = self.fileProvider(),
            .handle = LinearMemoryFileProvider.root,
        };
    }

    pub fn iteratorNode(
        self: *LinearMemoryFileProvider,
        it: *FileProvider.Iterator,
    ) ?FileProvider.Node {
        if (it.done) return null;

        const data: FileProvider.Node = .{
            .provider = it.provider,
            .handle = it.data,
        };
        const file_node = self.getFileNodeActive(data) catch return null;
        if (file_node.next) |node| {
            it.data = node.handle;
        } else {
            it.done = true;
        }
        return data;
    }

    pub fn getIterator(
        self: *LinearMemoryFileProvider,
        dir: FileProvider.Node,
    ) FileProvider.Error!FileProvider.Iterator {
        const file_node = try self.getFileNodeActive(dir);
        if (file_node.un != .directory) return error.IsNotDirectory;

        return FileProvider.Iterator{
            .provider = self.fileProvider(),
            .dir = dir,
            .data = if (file_node.un.directory) |child| child.handle else 0,
            .done = file_node.un.directory == null,
        };
    }

    pub fn getNodeFrom(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.Node,
        path: []const u8,
        kind: FileProvider.Kind,
    ) FileProvider.Error!FileProvider.Node {
        var path_it = std.mem.tokenizeScalar(u8, path, FileProvider.delimiter);
        var parent_node = try self.getFileNodeActive(parent);
        var parent_node_index = parent;
        while (path_it.next()) |raw_component| {
            switch (FileProvider.getComponent(raw_component)) {
                .none => {},
                .up => {
                    const id = parent_node.parent orelse return error.NotFound;
                    parent_node = try self.getFileNodeActive(id);
                    parent_node_index = id;
                },
                .down => |name| {
                    var child_it = try self.getIterator(parent_node_index);
                    var got = false;
                    const has_more = path_it.peek() != null;
                    while (child_it.next()) |child_node_index| {
                        const child_node = try self.getFileNodeActive(child_node_index);
                        const name_matches = std.mem.eql(u8, child_node.name, name);
                        if (((has_more or kind == .directory) and
                            child_node.un == .directory and name_matches) or
                            ((!has_more and kind == .file) and
                            child_node.un == .file and name_matches))
                        {
                            parent_node = child_node;
                            parent_node_index = child_node_index;
                            got = true;
                            break;
                        }
                    }
                    if (!got) return error.NotFound;
                },
            }
        }
        return parent_node_index;
    }

    pub fn getNodeName(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) FileProvider.Error![]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const file_node = try self.getFileNodeActive(node);
        return file_node.name;
    }

    pub fn getNodeKind(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) FileProvider.Error!FileProvider.Kind {
        const file_node = try self.getFileNodeActive(node);
        return switch (file_node.un) {
            .file => .file,
            .directory => .directory,
        };
    }

    pub fn read(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) FileProvider.Error!?[]const u8 {
        const file_node = try self.getFileNodeActive(node);
        if (file_node.un != .file) return error.IsNotFile;
        return file_node.un.file;
    }

    pub fn setNodeContents(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
        contents: ?[]const u8,
    ) FileProvider.Error!void {
        const file_node = try self.getFileNodeActive(node);
        if (file_node.un != .file) return error.IsNotFile;
        file_node.un.file = contents;
    }

    pub fn deleteNode(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) FileProvider.Error!void {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.deleteNodeInternal(node);
    }

    fn deleteNodeInternal(
        self: *LinearMemoryFileProvider,
        node: FileProvider.Node,
    ) FileProvider.Error!void {
        const file_node = try self.getFileNodeActive(node);

        if (file_node.un == .directory) {
            var path_it = try self.getIterator(node);
            while (path_it.next()) |child_node| {
                try self.deleteNodeInternal(child_node);
            }
        }

        if (file_node.parent) |parent| {
            const parent_node = try self.getFileNodeActive(parent);
            parent_node.un.directory = file_node.next;
        }

        const set_node = try self.getFileNode(node);
        set_node.* = .{ .free = self.free_list };
        self.free_list = node;
    }

    pub fn createDirectory(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.Node,
        name: []const u8,
    ) FileProvider.Error!FileProvider.Node {
        self.mutex.lock();
        defer self.mutex.unlock();
        const parent_node = try self.getFileNodeActive(parent);
        if (parent_node.un != .directory) return error.IsNotDirectory;

        if (parent.get(name, .directory)) |node| {
            return node;
        } else |_| {
            const new_node_index = try self.allocNode();
            const new_node = try self.getFileNode(new_node_index);
            new_node.* = .{
                .active = .{
                    .name = name,
                    .parent = parent,
                    .next = parent_node.un.directory,
                    .un = .{
                        .directory = null,
                    },
                },
            };
            parent_node.un = .{ .directory = new_node_index };
            return new_node_index;
        }
    }

    pub fn createFile(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.Node,
        name: []const u8,
        contents: ?[]const u8,
    ) FileProvider.Error!FileProvider.Node {
        self.mutex.lock();
        defer self.mutex.unlock();
        const parent_node = try self.getFileNodeActive(parent);
        if (parent_node.un != .directory) return error.IsNotDirectory;

        if (parent.get(name, .directory)) |node| {
            return node;
        } else |_| {
            const new_node_index = try self.allocNode();
            const new_node = try self.getFileNodeActive(new_node_index);
            new_node.name = name;
            new_node.parent = parent;
            new_node.next = parent_node.un.directory;
            new_node.un = .{ .file = contents };
            parent_node.un.directory = new_node_index;
            return new_node_index;
        }
    }

    pub fn createDirectories(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.Node,
        path: []const u8,
    ) FileProvider.Error!FileProvider.Node {
        var it = std.mem.tokenizeScalar(u8, path, FileProvider.delimiter);
        var current_node = parent;
        while (it.next()) |component| {
            switch (FileProvider.getComponent(component)) {
                .none => {},
                .up => {
                    const parent_node = try self.getFileNodeActive(current_node);
                    current_node = parent_node.parent orelse return error.NotFound;
                },
                .down => |name| {
                    current_node = current_node.get(name, .directory) catch |err| blk: {
                        if (err == error.NotFound) break :blk try current_node.createDirectory(name);
                        return err;
                    };
                },
            }
        }
        return current_node;
    }

    pub fn getFullName(
        self: *LinearMemoryFileProvider,
        allocator: std.mem.Allocator,
        node: FileProvider.Node,
    ) ![]const u8 {
        var path = std.ArrayList(u8).init(allocator);
        var current_parent: ?FileProvider.Node = node;
        while (current_parent) |parent_node_index| {
            const parent = try self.getFileNodeActive(parent_node_index);
            try path.insert(0, FileProvider.delimiter);
            try path.insertSlice(0, parent.name);
            current_parent = parent.parent;
        }
        return try path.toOwnedSlice();
    }

    fn allocNode(self: *LinearMemoryFileProvider) !FileProvider.Node {
        if (self.free_list) |free| {
            const free_node = try self.getFileNode(free);
            self.free_list = free_node.free;
            free_node.* = .{ .active = undefined };
            return free;
        }

        const new_node_index = self.files.items.len;
        const x = try self.files.addOne();
        x.* = .{ .active = undefined };
        return FileProvider.Node{
            .provider = self.fileProvider(),
            .handle = new_node_index,
        };
    }
};

test LinearMemoryFileProvider {
    const allocator = std.heap.page_allocator;
    var p = LinearMemoryFileProvider{};
    try p.init(allocator);

    const fp = p.fileProvider();

    const root = fp.getRootNode();
    try root.createTree(.{
        .@"another_file.rl" = "baz bar bo",
        .foo = .{
            .bar = .{
                .@"baz.rl" = "hello world",
            },
            .@"baz.rl" = "hello world",
        },
    });
    const foo_dir = try root.createDirectory("foo");
    _ = try foo_dir.createFile("rutile.rl", "hello world");
    _ = try foo_dir.createFile("rutile2.rl", "hello world2");
    const bar_dir = try foo_dir.createDirectory("bar");
    _ = try bar_dir.createFile("misc.rl", "example");

    const test_file = try root.get("foo/bar/misc.rl", .file);
    try std.testing.expectEqualStrings("example", (try test_file.read()).?);

    try std.testing.expectError(error.NotFound, root.get("foo/tar", .directory));

    var it = try foo_dir.iterator();

    try std.testing.expect(it.next() != null);
    try std.testing.expect(it.next() != null);
    try std.testing.expect(it.next() != null);
    try std.testing.expect(it.next() != null);
    try std.testing.expect(it.next() == null);

    try std.testing.expectEqual(@as(?FileProvider.Node, null), p.free_list);
    try bar_dir.delete();
    var free_list_count: usize = 0;
    var first = p.free_list;
    while (first) |node| {
        free_list_count += 1;
        first = (try p.getFileNode(node)).free;
    }
    try std.testing.expectEqual(3, free_list_count); //baz.rl and misc.rl
}
