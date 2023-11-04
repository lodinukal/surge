const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

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

        application.input.focused_changed_callback = focused_changed_callback;
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

    fn windowLoop(self: *Context) !void {
        try self.window.build();
        defer self.window.destroy();
        while (self.running()) {
            try self.pumpEvents();
        }
    }

    fn focused_changed_callback(wnd: *app.window.Window, focused: bool) void {
        wnd.setTitle(if (focused) "focused" else "not focused");
    }

    fn input_began_callback(ipo: app.input.InputObject) void {
        if (ipo.type == .mousebutton) {
            std.debug.print("mousebutton {} down\n", .{ipo.data.mousebutton});
        }
        if (ipo.type == .textinput) {
            if (ipo.data.textinput == .short) {
                std.debug.print("{}\n", .{ipo.data.textinput.short});
            }
        }
    }

    fn input_changed_callback(ipo: app.input.InputObject) void {
        // std.debug.print("input changed: {}\n", .{ipo});
        if (ipo.type == .resize) {
            std.debug.print("resize: {}x{}\n", .{ ipo.data.resize.x, ipo.data.resize.y });
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

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    var start = std.time.timestamp();
    while (context.running()) {
        if (std.time.timestamp() - start > 100) {
            start = std.time.timestamp();
            context.window.setVisible(!context.window.isVisible());
        }
    }

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});
}
