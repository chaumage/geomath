const std = @import("std");
const ShapeMesher = @import("shape_mesher.zig").ShapeMesher;

pub fn main() !void {
    const iterations = 1_000_000;

    const Shape = ShapeMesher(u16, f64, 20);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    });

    var timer = try std.time.Timer.start();
    var i: usize = 0;
    var sink: f64 = 0;
    while (i < iterations) : (i += 1) {
        sink += shape.integratePositiveLinearFn(2, 0.1, -1);
    }
    const elapsed_ns = timer.read();
    std.debug.print("{} ns \n", .{elapsed_ns});
}
