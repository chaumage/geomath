const std = @import("std");
const testing = std.testing;

const ValueError = error{
    ZeroLength,
};

const Point = struct {
    x: f64 = 0,
    y: f64 = 0,
};

///Cut polygon where linear function defined by values at points is equal to zero by adding points
fn cutPolygon(polygon: []Point, values: []f64) []Point {
    const n = polygon.len;
    if (n == 0) {
        return ValueError.ZeroLength;
    }
    var cut_polygon: [n * 2]Point = .{Point{}} ** (n * 2);
    var nb_cuts: u32 = 0;
    var next_i: u32 = 0;

    for (polygon, values, 0..) |pt, value, i| {
        next_i = (i + 1) % n;
        cut_polygon[i + nb_cuts] = pt;
        if (value * values[next_i] < 0) {
            nb_cuts += 1;
            cut_polygon[i + nb_cuts] = intersection(pt, polygon[next_i], value, values[next_i]);
        }
    }
    return cut_polygon[0..nb_cuts];
}

fn triangleArea(tri: [3]Point) f64 {
    return 0.5 * @abs(tri[0].x * (tri[1].y - tri[2].y) +
        tri[1].x * (tri[2].y - tri[0].y) +
        tri[2].x * (tri[0].y - tri[1].y));
}

/// Linear function defined as ax+bx+c
fn linearFn(abc: [3]f64, point: Point) []f64 {
    return abc[0] * point.x + abc[1] * point.y + abc[2];
}

///Intersection between line f=0 and line through p1 and p2, with f defined by its values at p1 and p2
fn intersection(p1: Point, p2: Point, f1: f64, f2: f64) Point {
    return Point{
        .x = (f2 * p1.x - f1 * p2.x) / (f2 - f1),
        .y = (f2 * p1.y - f1 * p2.y) / (f2 - f1),
    };
}

test "triangle area" {
    const triangle = [3]Point{
        Point{ .x = 0, .y = 0 },
        Point{ .x = 0, .y = 1 },
        Point{ .x = 1, .y = 0 },
    };
    const a: f64 = triangleArea(triangle);
    try testing.expectEqual(0.5, a);
}

test "intersection" {
    const x1 = Point{
        .x = 0,
        .y = 0,
    };
    const x2 = Point{
        .x = 1,
        .y = 0,
    };

    const f1 = 1;
    const f2 = -1;
    try testing.expectEqual(Point{ .x = 0.5, .y = 0 }, intersection(x1, x2, f1, f2));
}

test "cut_polygon" {
    const tri: [_]Point = []Point{
        Point{ .x = 0, .y = 0 },
        Point{ .x = 1, .y = 0 },
        Point{ .x = 0, .y = 1 },
    };
    const values: [_]f64 = .{ 0, 1, 0 };
    const expected: [_]Point = []Point{
        Point{ .x = 0, .y = 0 },
        Point{ .x = 0.5, .y = 0 },
        Point{ .x = 1, .y = 0 },
        Point{ .x = 0.5, .y = 0.5 },
        Point{ .x = 0, .y = 1 },
    };
}
