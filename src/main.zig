const std = @import("std");

const platform = @import("./video/platforms/platform.zig");
const definitions = @import("./video/definitions.zig");

const X = struct {
    pub const number: usize = 42;
};

const Prefix = enum {
    pos,
    neg,
    unsigned,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    _ = alloc;

    const original = "03000000120c00001088000000000000,Xbox Controller,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,leftshoulder:b4,leftstick:b8,lefttrigger:a2~,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b9,righttrigger:a5~,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Windows,";

    var inmapping: platform.InternalMapping = platform.InternalMapping{};
    var mapping: *platform.InternalMapping = &inmapping;

    var fields = [_]struct { name: []const u8, element: ?*platform.InternalMapElement }{
        .{ .name = "platform", .element = null },
        .{ .name = "a", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.a)] },
        .{ .name = "b", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.b)] },
        .{ .name = "x", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.x)] },
        .{ .name = "y", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.y)] },
        .{ .name = "back", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.back)] },
        .{ .name = "start", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.start)] },
        .{ .name = "guide", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.guide)] },
        .{ .name = "leftshoulder", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.left_bumper)] },
        .{ .name = "rightshoulder", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.right_bumper)] },
        .{ .name = "leftstick", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.left_thumb)] },
        .{ .name = "rightstick", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.right_thumb)] },
        .{ .name = "dpup", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_up)] },
        .{ .name = "dpright", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_right)] },
        .{ .name = "dpdown", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_down)] },
        .{ .name = "dpleft", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_left)] },
        .{ .name = "lefttrigger", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.left_trigger)] },
        .{ .name = "righttrigger", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.right_trigger)] },
        .{ .name = "leftx", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.left_x)] },
        .{ .name = "lefty", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.left_y)] },
        .{ .name = "rightx", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.right_x)] },
        .{ .name = "righty", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.right_y)] },
    };

    var parser = std.fmt.Parser{ .buf = original };
    var guid = parser.until(',');
    if (guid.len != 32) {
        return;
    }
    @memcpy(mapping.guid[0..32], guid[0..32]);
    if (!parser.maybe(',')) return;

    var name = parser.until(',');
    if (name.len > mapping.name.len) {
        return;
    }
    var m = @min(name.len, mapping.name.len);
    @memcpy(mapping.name[0..m], name[0..m]);
    if (!parser.maybe(',')) return;

    lp: while (parser.peek(0)) |_| {
        std.debug.print("{s}\n", .{parser.buf[parser.pos..]});
        var key_prefix: Prefix = key_prefix: {
            var is_pos = (parser.peek(0) orelse return) == '+';
            var is_neg = (parser.peek(0) orelse return) == '-';
            if (is_pos or is_neg) {
                _ = parser.char();
            }
            break :key_prefix if (is_pos) .pos else if (is_neg) .neg else .unsigned;
        };
        _ = key_prefix;
        var key = parser.until(':');
        if (!parser.maybe(':')) return;

        var val_prefix: Prefix = val_prefix: {
            var is_pos = (parser.peek(0) orelse return) == '+';
            var is_neg = (parser.peek(0) orelse return) == '-';
            if (is_pos or is_neg) {
                _ = parser.char();
            }
            break :val_prefix if (is_pos) .pos else if (is_neg) .neg else .unsigned;
        };

        var mapping_source_opt: ?platform.JoystickMappingSource = mapping_source: {
            break :mapping_source switch ((parser.char() orelse return)) {
                'a' => platform.JoystickMappingSource.axis,
                'b' => platform.JoystickMappingSource.button,
                'h' => platform.JoystickMappingSource.hatbit,
                else => null,
            };
        };

        var value = parser.until(',');
        if (!parser.maybe(',')) return;
        const mapping_source = mapping_source_opt orelse {
            std.debug.print("unknown mapping source: {s}\n", .{value});
            continue :lp;
        };

        var min: i8 = -1;
        var max: i8 = 1;
        switch (val_prefix) {
            .pos => min = 0,
            .neg => max = 0,
            else => {},
        }

        var has_axis_invert = has_axis_invert: {
            if (mapping_source != .axis) {
                break :has_axis_invert false;
            }
            if (value[value.len - 1] == '~') {
                value = value[0 .. value.len - 1];
                break :has_axis_invert true;
            }
            break :has_axis_invert false;
        };

        kv: for (fields) |f| {
            if (!std.mem.eql(u8, f.name, key)) {
                continue :kv;
            }

            if (f.element == null) {
                continue :kv;
            }
            var element = f.element.?;

            var index = index: {
                break :index switch (mapping_source) {
                    .hatbit => hatbit: {
                        var inner_parser = std.fmt.Parser{ .buf = value };
                        var hat_contents = inner_parser.until('.');
                        if (hat_contents.len < 1) {
                            continue :kv;
                        }
                        _ = inner_parser.char();
                        var hat = std.fmt.parseInt(u8, hat_contents, 0) catch {
                            continue :kv;
                        };
                        var bit: u8 = @truncate(inner_parser.number() orelse continue :kv);
                        break :hatbit @as(u8, ((hat << 4) | bit));
                    },
                    else => std.fmt.parseInt(u8, value, 0) catch {
                        continue :kv;
                    },
                };
            };

            element.typ = mapping_source;
            element.index = index;

            if (mapping_source == .axis) {
                element.axis_scale = @divTrunc(2, max - min);
                element.axis_offset = -(max + min);

                if (has_axis_invert) {
                    element.axis_scale *= -1;
                    element.axis_offset *= -1;
                }
            }
        }
    }

    for (mapping.guid[0..32]) |*c| {
        c.* = std.ascii.toLower(c.*);
    }

    std.debug.print("{any}\n", .{mapping.*});
}
