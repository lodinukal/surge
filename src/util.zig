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
        OutOfBounds,
    };
    pub const FileId = usize;

    context: ?*anyopaque = null,
    pfn_directory_exists: ?*const fn (
        context: ?*anyopaque,
        path: []const u8,
    ) bool = null,
    pfn_file_exists: ?*const fn (
        context: ?*anyopaque,
        path: []const u8,
    ) bool = null,
    pfn_get_files_for_directory: ?*const fn (
        context: ?*anyopaque,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) Error!std.ArrayList([]const u8) = null,
    pfn_read_file: ?*const fn (
        context: ?*anyopaque,
        path: []const u8,
    ) Error!?[]const u8 = null,

    pub inline fn directoryExists(
        self: *FileProvider,
        path: []const u8,
    ) bool {
        return if (self.pfn_directory_exists) |f| f(self.context, path) else false;
    }

    pub inline fn fileExists(
        self: *FileProvider,
        path: []const u8,
    ) bool {
        return if (self.pfn_file_exists) |f| f(self.context, path) else false;
    }

    pub inline fn getFilesForDirectory(
        self: *FileProvider,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) Error!std.ArrayList([]const u8) {
        return if (self.pfn_get_files_for_directory) |f| f(self.context, allocator, path) else unreachable;
    }

    pub inline fn readFile(
        self: *FileProvider,
        path: []const u8,
    ) Error!?[]const u8 {
        return if (self.pfn_read_file) |f| f(self.context, path) else unreachable;
    }
};

pub const LinearMemoryFileProvider = struct {
    pub const FileNode = struct {
        name: []const u8 = "",
        next: ?FileProvider.FileId = null,
        parent: ?FileProvider.FileId = null,
        un: union(enum) {
            file: ?[]const u8,
            directory: ?FileProvider.FileId,
        },
    };
    mutex: std.Thread.Mutex = .{},
    files: std.ArrayList(FileNode) = undefined,
    file_provider: FileProvider = undefined,
    pub const root = 0;

    pub fn init(
        self: *LinearMemoryFileProvider,
        allocator: std.mem.Allocator,
    ) !void {
        self.* = LinearMemoryFileProvider{
            .mutex = .{},
            .files = std.ArrayList(FileNode).init(allocator),
            .file_provider = .{
                .context = @ptrCast(self),
                .pfn_file_exists = _fileExists,
                .pfn_directory_exists = _directoryExists,
                .pfn_get_files_for_directory = _getFilesForDirectory,
                .pfn_read_file = _readFile,
            },
        };
        try self.files.append(.{
            .name = "root",
            .un = .{
                .directory = null,
            },
        });
    }

    pub fn deinit(self: *LinearMemoryFileProvider) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.files.deinit();
    }

    pub fn fileExists(self: *LinearMemoryFileProvider, path: []const u8) bool {
        const file = self.getFile(
            resolveFile(self, path) orelse return false,
        ) catch return false;
        return file.un == .file;
    }

    fn _fileExists(self: ?*anyopaque, path: []const u8) bool {
        return fileExists(@ptrCast(@alignCast(self.?)), path);
    }

    pub fn directoryExists(self: *LinearMemoryFileProvider, path: []const u8) bool {
        const file = self.getFile(
            resolveFile(self, path) orelse return false,
        ) catch return false;
        return file.un == .directory;
    }

    fn _directoryExists(self: ?*anyopaque, path: []const u8) bool {
        return directoryExists(@ptrCast(@alignCast(self.?)), path);
    }

    pub fn getFilesForDirectory(
        self: *LinearMemoryFileProvider,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) FileProvider.Error!std.ArrayList([]const u8) {
        const file = self.getFile(
            resolveFile(self, path) orelse return error.NotFound,
        ) catch return error.NotFound;
        if (file.un != .directory) {
            return error.NotFound;
        }
        var files = std.ArrayList([]const u8).init(allocator);
        var child = file.un.directory;
        while (child) |c| {
            const child_file = try self.getFile(c);
            try files.append(child_file.name);
            child = child_file.next;
        }
        return files;
    }

    fn _getFilesForDirectory(
        self: ?*anyopaque,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) FileProvider.Error!std.ArrayList([]const u8) {
        return getFilesForDirectory(@ptrCast(@alignCast(self.?)), allocator, path);
    }

    pub fn readFile(self: *LinearMemoryFileProvider, path: []const u8) FileProvider.Error!?[]const u8 {
        const file = self.getFile(
            resolveFile(self, path) orelse return error.NotFound,
        ) catch return error.NotFound;
        if (file.un != .file) {
            return error.NotFound;
        }
        return file.un.file;
    }

    fn _readFile(
        self: ?*anyopaque,
        path: []const u8,
    ) FileProvider.Error!?[]const u8 {
        return readFile(@ptrCast(@alignCast(self.?)), path);
    }

    pub fn resolveFile(self: *LinearMemoryFileProvider, path: []const u8) ?FileProvider.FileId {
        return self.resolveFileWithParent(root, path);
    }

    pub fn resolveFileWithParent(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.FileId,
        path: []const u8,
    ) ?FileProvider.FileId {
        var it = std.mem.tokenizeScalar(u8, path, '/');
        var current: FileProvider.FileId = parent;
        while (it.next()) |c| {
            if (self.findChild(current, c)) |child| {
                current = child;
            } else {
                return null;
            }
        }
        return current;
    }

    pub fn getFile(self: *LinearMemoryFileProvider, id: FileProvider.FileId) !*FileNode {
        if (id >= self.files.items.len) {
            return error.OutOfBounds;
        }
        return &self.files.items[id];
    }

    pub fn findChild(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.FileId,
        name: []const u8,
    ) ?FileProvider.FileId {
        self.mutex.lock();
        defer self.mutex.unlock();
        var child = (self.getFile(parent) catch return null).un.directory;
        while (child) |c| {
            const child_file = self.getFile(c) catch continue;
            if (std.mem.eql(u8, child_file.name, name)) {
                return child;
            }
            child = child_file.next;
        }
        return null;
    }

    pub fn addDirectory(
        self: *LinearMemoryFileProvider,
        name: []const u8,
    ) !FileProvider.FileId {
        return self.addDirectoryWithParent(root, name);
    }

    pub fn addDirectoryWithParent(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.FileId,
        path: []const u8,
    ) !FileProvider.FileId {
        var current_parent: FileProvider.FileId = parent;
        var it = std.mem.tokenizeScalar(u8, path, '/');
        while (it.next()) |c| {
            if (self.findChild(current_parent, c)) |child| {
                current_parent = child;
            } else {
                self.mutex.lock();
                defer self.mutex.unlock();
                const child_id = self.files.items.len;
                const child_file = try self.files.addOne();
                child_file.name = c;
                child_file.parent = current_parent;
                child_file.next = null;
                child_file.un = .{
                    .directory = null,
                };
                const parent_file = try self.getFile(current_parent);
                if (parent_file.un.directory) |*last_child| {
                    child_file.next = last_child.*;
                }
                parent_file.un.directory = child_id;
                current_parent = child_id;
            }
        }

        return current_parent;
    }

    pub fn addFile(
        self: *LinearMemoryFileProvider,
        name: []const u8,
        contents: []const u8,
    ) !FileProvider.FileId {
        return self.addFileWithParent(root, name, contents);
    }

    pub fn addFileWithParent(
        self: *LinearMemoryFileProvider,
        parent: FileProvider.FileId,
        name: []const u8,
        contents: ?[]const u8,
    ) !FileProvider.FileId {
        var current_parent: FileProvider.FileId = parent;
        if (std.fs.path.dirname(name)) |dir| {
            current_parent = try self.addDirectoryWithParent(current_parent, dir);
        }
        const file_name = std.fs.path.basename(name);

        self.mutex.lock();
        defer self.mutex.unlock();

        const child_id = self.files.items.len;
        const child_file = try self.files.addOne();
        child_file.name = file_name;
        child_file.parent = current_parent;
        child_file.next = null;
        child_file.un = .{
            .file = contents,
        };

        const parent_file = try self.getFile(current_parent);
        if (parent_file.un.directory) |*last_child| {
            child_file.next = last_child.*;
        }
        parent_file.un.directory = child_id;

        return child_id;
    }
};
