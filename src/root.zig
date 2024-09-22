const std = @import("std");
const testing = std.testing;

fn triangleArea(tri: [3][2]f64) f64 {
    return 0.5 * @abs(tri[0][0] * (tri[1][1] - tri[2][1]) +
        tri[1][0] * (tri[2][1] - tri[0][1]) +
        tri[2][0] * (tri[0][1] - tri[1][1]));
}

test "triangle area" {
    const triangle = [3][2]f64{
        [_]f64{ 0, 0 },
        [_]f64{ 0, 1 },
        [_]f64{ 1, 0 },
    };
    const a: f64 = triangleArea(triangle);
    try testing.expectEqual(0.5, a);
}
