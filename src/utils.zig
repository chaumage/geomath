const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const Point = @import("point.zig").Point;

pub fn assertFloat(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .float) {
        @compileError("Expected float type");
    }
}

fn assertUnsignedInt(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .int or info.int.signedness != .unsigned) {
        @compileError("Expected unsigned int type (u8, u16, u32, ...)");
    }
}

pub fn triangleArea(T: type, p1: *const Point(T), p2: *const Point(T), p3: *const Point(T)) T {
    assertFloat(T);
    return 0.5 * @abs(p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y));
}

test "triangle area" {
    const P = Point(f64);
    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 0, .y = 1 };
    const p3: P = .{ .x = 1, .y = 0 };
    const res = triangleArea(f64, &p1, &p2, &p3);
    try testing.expectEqual(0.5, res);
}

pub fn isInsideTriangle(T: type, p: *const Point(T), p1: *const Point(T), p2: *const Point(T), p3: *const Point(T)) bool {
    assertFloat(T);
    const area = triangleArea(T, p1, p2, p3);
    var s: T = 0.0;
    s += triangleArea(T, p1, p2, p);
    s += triangleArea(T, p2, p3, p);
    s += triangleArea(T, p3, p1, p);
    return s - area < 1e-15;
}

test "inside triangle" {
    const P = Point(f64);
    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 0, .y = 1 };
    const p3: P = .{ .x = 1, .y = 0 };
    const p: P = .{ .x = 0.1, .y = 0.1 };
    try testing.expect(isInsideTriangle(f64, &p, &p1, &p2, &p3));
}

test "outside triangle" {
    const P = Point(f64);
    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 0, .y = 1 };
    const p3: P = .{ .x = 1, .y = 0 };
    const p: P = .{ .x = -0.1, .y = 0.1 };
    try testing.expect(!isInsideTriangle(f64, &p, &p1, &p2, &p3));
}

test "on edge" {
    const P = Point(f64);
    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 0, .y = 1 };
    const p3: P = .{ .x = 1, .y = 0 };
    const p: P = .{ .x = 0.0, .y = 0.1 };
    try testing.expect(isInsideTriangle(f64, &p, &p1, &p2, &p3));
}

// Intersection between line f=0 and line through p1 and p2, with f defined by its values at p1 and p2
pub inline fn intersection(T: type, p1: *const Point(T), p2: *const Point(T), v1: T, v2: T) Point(T) {
    assertFloat(T);
    return .{
        .x = (v2 * p1.x - v1 * p2.x) / (v2 - v1),
        .y = (v2 * p1.y - v1 * p2.y) / (v2 - v1),
    };
}

test "intersection" {
    const P = Point(f64);
    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 1, .y = 0 };
    const v1: f64 = 1;
    const v2: f64 = -1;

    const i = intersection(f64, &p1, &p2, v1, v2);
    try testing.expectEqual(0.5, i.x);
    try testing.expectEqual(0.0, i.y);
}

pub fn sum(T: type, numbers: []const T) T {
    assertFloat(T);
    var result: T = 0;
    for (numbers) |x| {
        result += x;
    }
    return result;
}

pub inline fn crossProd2d(T: type, x1: T, x2: T, y1: T, y2: T) T {
    assertFloat(T);
    return x1 * y2 - y1 * x2;
}

pub inline fn angleSign(T: type, p1: *const Point(T), p2: *const Point(T), p3: *const Point(T)) T {
    assertFloat(T);
    return crossProd2d(
        T,
        p2.x - p1.x,
        p3.x - p2.x,
        p2.y - p1.y,
        p3.y - p2.y,
    );
}

test "angle signs 1" {
    const F = f64;
    const P = Point(F);

    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 1, .y = 0 };
    const p3: P = .{ .x = 0, .y = 1 };

    try std.testing.expect(angleSign(F, &p1, &p2, &p3) > 0);
    try std.testing.expect(angleSign(F, &p2, &p3, &p1) > 0);
    try std.testing.expect(angleSign(F, &p3, &p1, &p2) > 0);

    try std.testing.expect(angleSign(F, &p3, &p2, &p1) < 0);
    try std.testing.expect(angleSign(F, &p1, &p3, &p2) < 0);
    try std.testing.expect(angleSign(F, &p2, &p1, &p3) < 0);
}

pub fn triangleCenter(T: type, p1: Point(T), p2: Point(T), p3: Point(T)) Point(T) {
    assertFloat(T);
    return .{
        .x = (p1.x + p2.x + p3.x) / 3.0,
        .y = (p1.y + p2.y + p3.y) / 3.0,
    };
}

/// Integrates f = ax+by+c on tri mesh
/// Doesn't check validity of data
/// Will scan iterate on values of mesh based on mesh.len
pub fn integrateOnTriMesh(F: type, Id: type, nodes: []const Point(F), mesh: []const Id, a: F, b: F, c: F) F {
    assertFloat(F);
    assertUnsignedInt(Id);
    assert(mesh.len % 3 == 0);
    var integral: F = 0;
    var area: F = undefined;
    var p1: Point(F) = undefined;
    var p2: Point(F) = undefined;
    var p3: Point(F) = undefined;
    var v1: F = undefined;
    var v2: F = undefined;
    var v3: F = undefined;
    const len: Id = @truncate(mesh.len / 3);
    for (0..len) |i| {
        p1 = nodes[mesh[i * 3]];
        p2 = nodes[mesh[i * 3 + 1]];
        p3 = nodes[mesh[i * 3 + 2]];
        v1 = a * p1.x + b * p1.y + c;
        v2 = a * p2.x + b * p2.y + c;
        v3 = a * p3.x + b * p3.y + c;
        area = triangleArea(F, &p1, &p2, &p3);
        integral += area * (v1 + v2 + v3) / 3.0;
    }
    return integral;
}

test "IntegrateOnTriMesh" {
    const P = Point(f64);
    const p1: P = .{ .x = 0, .y = 0 };
    const p2: P = .{ .x = 1, .y = 0 };
    const p3: P = .{ .x = 0, .y = 1 };

    const i = integrateOnTriMesh(
        f64,
        u16,
        &.{ p1, p2, p3 },
        &.{ 0, 1, 2 },
        0,
        0,
        1,
    );
    try testing.expectEqual(0.5, i);
}

/// Returns which side of the edge defined by p1 and p2
/// point p lies on
/// if the distance is less than tol, returns onEdge
fn distToLine(T: type, p: *const Point(T), p1: *const Point(T), p2: *const Point(T)) T {
    const dx = p2.x - p1.x;
    const dy = p2.y - p1.y;
    const len = @sqrt(dx * dx + dy * dy);

    const cross = (p.x - p1.x) * dy - (p.y - p1.y) * dx;
    return cross / len;
}

/// only useful for use inside segmentsIntersect
fn onSegment(T: type, p: *const Point(T), p1: *const Point(T), p2: *const Point(T)) bool {
    return @min(p1.x, p2.x) <= p.x and p.x <= @max(p1.x, p2.x) and
        @min(p1.y, p2.y) <= p.y and p.y <= @max(p1.y, p2.y);
}

/// Returns true if the two segments intersect
pub fn segmentsIntersect(T: type, p1: *const Point(T), p2: *const Point(T), p3: *const Point(T), p4: *const Point(T), tol: T) bool {
    assertFloat(T);

    const s1 = distToLine(T, p1, p3, p4);
    const s2 = distToLine(T, p2, p3, p4);
    const s3 = distToLine(T, p3, p1, p2);
    const s4 = distToLine(T, p4, p1, p2);

    if (s1 * s2 < 0 and s3 * s4 < 0) {
        return true;
    }

    // colinear edge case
    if (@abs(s1) <= tol and @abs(s2) <= tol and @abs(s3) <= tol and @abs(s4) <= tol) {
        if (onSegment(T, p1, p3, p4)) return true;
        if (onSegment(T, p2, p3, p4)) return true;
        if (onSegment(T, p2, p1, p2)) return true;
        if (onSegment(T, p3, p1, p2)) return true;
    }

    return false;
}
