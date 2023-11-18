const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");
const Renderer = @import("render/gpu/Renderer.zig");

const interface = @import("core/interface.zig");

const Context = struct {
    allocator: std.mem.Allocator,
    application: *app.Application,
    window: *app.window.Window,
    // renderer: *app.renderer.Renderer,

    ui_thread: ?std.Thread = null,
    mutex: std.Thread.Mutex = .{},
    ready: bool = false,

    pub fn init(allocator: std.mem.Allocator) !Context {
        var application = try app.Application.create(allocator);
        errdefer application.destroy();

        // application.input.focused_changed_callback = focused_changed_callback;
        application.input.input_began_callback = input_began_callback;
        application.input.input_changed_callback = input_changed_callback;
        application.input.input_ended_callback = input_ended_callback;

        return Context{
            .allocator = allocator,
            .application = application,
            .window = try application.createWindow(.{
                .title = "helloo!",
                .width = 800,
                .height = 600,
                .visible = true,
            }),
        };
    }

    pub fn deinit(self: *Context) void {
        if (self.ui_thread) |t| {
            t.join();
        }
        self.application.destroy();
    }

    pub fn pumpEvents(self: *Context) !void {
        try self.application.pumpEvents();
    }

    pub fn running(self: *Context) bool {
        return !self.window.shouldClose();
    }

    pub fn spawnWindowThread(self: *Context) !void {
        self.ui_thread = try std.Thread.spawn(.{
            .allocator = self.allocator,
        }, windowLoop, .{self});
    }

    pub const focused_sleep = std.time.ns_per_us * 100;
    pub const unfocused_sleep = std.time.ns_per_ms * 10;

    fn windowLoop(self: *Context) !void {
        try self.window.build();
        defer self.window.destroy();
        while (self.running()) {
            try self.pumpEvents();
            self.window.setTitle(if (self.window.isFocused()) "focused" else "not focused");
            std.time.sleep(if (self.window.isFocused()) focused_sleep else unfocused_sleep);
        }
    }

    fn input_began_callback(ipo: app.input.InputObject) void {
        if (ipo.type == .mousebutton) {
            std.debug.print("mousebutton {} down\n", .{ipo.data.mousebutton});
        }
        if (ipo.type == .textinput) {
            if (ipo.data.textinput == .short) {
                std.debug.print("{c}\n", .{ipo.data.textinput.short});
            }
        }
    }

    fn input_changed_callback(ipo: app.input.InputObject) void {
        // std.debug.print("input changed: {}\n", .{ipo});
        if (ipo.type == .resize) {
            std.debug.print("resize: {}x{}\n", .{ ipo.data.resize[0], ipo.data.resize[1] });
        }
    }

    fn input_ended_callback(ipo: app.input.InputObject) void {
        // std.debug.print("input ended: {}\n", .{ipo});
        if (ipo.type == .mousebutton) {
            std.debug.print("mousebutton {} up\n", .{ipo.data.mousebutton});
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gpa_alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    var context = try Context.init(alloc);
    defer context.deinit();

    try context.spawnWindowThread();

    var renderer = try Renderer.create(alloc);
    defer renderer.destroy();

    try renderer.load(.d3d11);
    std.debug.print("{}\n", .{try renderer.getRendererInfo()});

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    var start = std.time.timestamp();
    while (context.running()) {
        if (std.time.timestamp() - start > 100) {
            start = std.time.timestamp();
            context.window.setVisible(!context.window.isVisible());
        }
        std.time.sleep(std.time.ns_per_s);
    }

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});
}

test {
    std.testing.refAllDecls(Renderer);
}
