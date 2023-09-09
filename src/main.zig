const std = @import("std");

const platform = @import("./video/platforms/platform.zig");
const definitions = @import("./video/definitions.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    _ = alloc;

    var values: [3][256]std.os.windows.WORD = [1][256]std.os.windows.WORD{[1]std.os.windows.WORD{0} ** 256} ** 3;
    @compileLog(values);
}
