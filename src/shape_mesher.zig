const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const utils = @import("utils.zig");
const print = std.debug.print;

///Linked list of (x, y) positions
///Describes a 2D polygon
///Can be meshed with triangles on its positive part defined by a linear function of x and y
pub fn ShapeMesher(Id: type, F: type, capacity: Id) type {
    const Point = @import("point.zig").Point(F);
    return struct {
        len: Id,
        current: Id,
        points: [capacity]Point,
        prev: [capacity]Id,
        next: [capacity]Id,
        is_convex: ?bool = null,

        const Self = @This();

        pub const empty: Self = .{
            .len = 0,
            .current = 0,
            .points = undefined,
            .prev = undefined,
            .next = undefined,
        };

        pub fn init(points: []const Point) Self {
            const len: Id = @truncate(points.len);
            assert(len <= capacity);

            if (len < 1) {
                return .empty;
            }

            var res: Self = .empty;
            @memcpy(res.points[0..len], points[0..len]);

            res.len = len;
            res.current = 0;
            for (1..len) |i| {
                res.prev[i] = @truncate(i - 1);
                res.next[i] = @truncate(i + 1);
            }
            res.prev[0] = len - 1;
            res.next[0] = 1;
            res.next[len - 1] = 0;
            return res;
        }

        /// Reset linked list to the len first values
        /// in self.points in order
        /// self.current becomes 0
        inline fn reset(self: *Self, len: Id) void {
            self.len = len;
            self.current = 0;
            for (1..len) |i| {
                self.prev[i] = @truncate(i - 1);
                self.next[i] = @truncate(i + 1);
            }
            self.prev[0] = len - 1;
            self.next[0] = 1;
            self.next[len - 1] = 0;
        }

        inline fn prev_node(self: *Self) *Point {
            return &self.points[self.prev[self.current]];
        }

        inline fn current_node(self: *Self) *Point {
            return &self.points[self.current];
        }

        inline fn next_node(self: *Self) *Point {
            return &self.points[self.next[self.current]];
        }

        fn clear(self: *Self) void {
            self.len = 0;
            self.current = 0;
            self.prev[0] = 0;
            self.next[0] = 0;
        }

        ///Moves to next node
        inline fn move_forward(self: *Self) void {
            self.current = self.next[self.current];
        }

        ///Moves to previous node
        inline fn move_back(self: *Self) void {
            self.current = self.prev[self.current];
        }

        ///Insert data after current node
        ///Inserted node becomes current node
        fn insert(self: *Self, data: Point) void {
            assert(self.len < capacity);

            if (self.len == 0) {
                self.points[0] = data;
                self.prev[0] = 0;
                self.next[0] = 0;
                self.len += 1;
                return;
            }

            const current: Id = self.current;

            // attributes of inserted node
            const prev: Id = current;
            const new: Id = self.len;
            const next: Id = self.next[current];

            self.points[new] = data;

            self.next[prev] = new;
            self.next[new] = next;
            self.prev[new] = prev;
            self.prev[next] = new;

            self.current = new;
            self.len += 1;
        }

        /// Same as pop but doesn't maintain compactness
        /// of backing array
        /// Previous node becomes current node
        fn popNoPack(self: *Self) void {
            const popped: Id = self.current;

            if (self.len == 1) {
                self.clear();
                return;
            }

            const prev: Id = self.prev[popped];
            const next: Id = self.next[popped];

            self.next[prev] = next;
            self.prev[next] = prev;
            self.current = prev;
            self.len -= 1;

            return;
        }

        /// Calculates angle sign at current node
        inline fn angleSign(self: *Self) F {
            return utils.angleSign(
                F,
                self.prev_node(),
                self.current_node(),
                self.next_node(),
            );
        }

        inline fn isConvex(self: *Self) bool {
            if (self.len < 4) {
                return true;
            }
            var negatives_exist: bool = false;
            var positives_exist: bool = false;
            var angle: F = undefined;
            return for (0..self.len) |_| {
                self.move_forward();
                angle = self.angleSign();
                if (angle > 0) {
                    positives_exist = true;
                }
                if (angle < 0) {
                    negatives_exist = true;
                }
                if (negatives_exist and positives_exist) {
                    break false;
                }
            } else true;
        }

        /// Calculates the sum of self.angleSign on all nodes
        inline fn rotationSign(self: *Self) F {
            var sum: F = 0;
            for (0..self.len) |_| {
                sum += self.angleSign();
                self.move_forward();
            }
            return sum;
        }

        /// Evaluates f = ax + by + c on current node
        fn evaluate(self: *Self, a: F, b: F, c: F) F {
            const p = self.current_node();
            return a * p.x + b * p.y + c;
        }

        /// Inserts points where function f = ax + by + c evaluates to zero
        /// on segments defined by consecutive points
        fn cut(self: *Self, a: F, b: F, c: F) void {
            var v: F = undefined;
            var v_next: F = undefined;
            for (0..self.len) |_| {
                v = self.evaluate(a, b, c);
                self.move_forward();
                v_next = self.evaluate(a, b, c);
                self.move_back();
                if (v * v_next < 0) {
                    const intersection: Point = utils.intersection(F, self.current_node(), self.next_node(), v, v_next);
                    self.insert(intersection);
                }
                self.move_forward();
            }
        }

        /// Remove nodes where f = ax+by+c is strictly negative
        fn removeNegatives(self: *Self, a: F, b: F, c: F) void {
            const n = self.len;
            for (0..n) |_| {
                if (self.evaluate(a, b, c) < -1e-15) {
                    self.popNoPack();
                }
                self.move_forward();
            }
        }

        fn noOtherPtInsideTriangle(self: *Self) bool {
            const cur = self.current;
            defer self.current = cur;

            const prev = self.prev[cur];
            const next = self.next[cur];
            const n = self.len;

            self.move_forward();
            for (0..(n - 3)) |_| {
                self.move_forward();
                if (utils.isInsideTriangle(
                    F,
                    self.current_node(),
                    &self.points[prev],
                    &self.points[cur],
                    &self.points[next],
                )) {
                    return false;
                }
            }
            return true;
        }

        fn printNodes(self: *Self) void {
            const n = self.len;
            for (0..n) |_| {
                const p = self.current_node();
                print("({d:.2}, {d:.2}) -> ", .{ p.x, p.y });
                self.move_forward();
            }
            print("\n", .{});
        }

        /// Calculates integral of max(0, ax+by+c) on shape
        /// Shape state is restored after calculation
        pub fn integratePositiveLinearFn(self: *Self, a: F, b: F, c: F) F {
            const saved_len = self.len;
            defer {
                self.reset(saved_len);
            }

            if (self.is_convex == null) {
                self.is_convex = self.isConvex();
            }

            var mesh: [capacity * 3]Id = undefined;

            self.cut(a, b, c);
            self.removeNegatives(a, b, c);

            if (self.len < 3) {
                return 0.0;
            }

            // simple case when convex
            if (self.is_convex orelse unreachable) {
                const n = self.len;
                for (0..(n - 2)) |i| {
                    mesh[3 * i] = self.prev[self.current];
                    mesh[3 * i + 1] = self.current;
                    mesh[3 * i + 2] = self.next[self.current];
                    self.popNoPack();
                }
                return utils.integrateOnTriMesh(
                    F,
                    Id,
                    &self.points,
                    mesh[0..((n - 2) * 3)],
                    a,
                    b,
                    c,
                );
            }

            // mesh by poping nodes that have:
            // area > 0
            // angle sign * sum of angle signs > 0
            // no other active node inside
            var finished = false;
            var prev: Id = undefined;
            var cur: Id = undefined;
            var next: Id = undefined;
            var i: Id = 0;
            const rotation = self.rotationSign();
            while (!finished) {
                defer {
                    self.move_forward();
                    finished = (self.len < 3);
                }

                cur = self.current;
                prev = self.prev[cur];
                next = self.next[cur];

                // this garantees termination from condition on self.len only
                if (utils.triangleArea(
                    F,
                    self.prev_node(),
                    self.current_node(),
                    self.next_node(),
                ) < 1e-15) {
                    self.popNoPack();
                    continue;
                }

                if (self.angleSign() * rotation < 0) {
                    continue;
                }

                if (self.len == 3) {
                    mesh[3 * i] = prev;
                    mesh[3 * i + 1] = cur;
                    mesh[3 * i + 2] = next;
                    i += 1;
                    self.popNoPack();
                    continue;
                }

                if (self.noOtherPtInsideTriangle()) {
                    mesh[3 * i] = self.prev[self.current];
                    mesh[3 * i + 1] = self.current;
                    mesh[3 * i + 2] = self.next[self.current];
                    i += 1;
                    self.popNoPack();
                }
            }
            return utils.integrateOnTriMesh(
                F,
                Id,
                &self.points,
                mesh[0..(i * 3)],
                a,
                b,
                c,
            );
        }
    };
}

test "Init empty" {
    const Shape = ShapeMesher(u16, f64, 10);
    const shape = Shape.init(&.{});
    try std.testing.expect(shape.len == 0);
}

test "Init slice" {
    const Shape = ShapeMesher(u16, f64, 10);
    const shape = Shape.init(&.{
        .{ .x = 1.0, .y = 1.0 },
        .{ .x = 1.0, .y = -1.0 },
        .{ .x = -1.0, .y = -1.0 },
        .{ .x = -1.0, .y = 1.0 },
    });

    try std.testing.expect(shape.len == 4);
    try std.testing.expect(shape.prev[0] == 3);
    try std.testing.expect(shape.next[0] == 1);
    try std.testing.expect(shape.next[3] == 0);
}

// test "Convex" {
//     const Shape = ShapeMesher(u16, f64, 10);
//     var shape = Shape.init(&.{
//         .{ .x = 0, .y = 0 },
//         .{ .x = 1, .y = 0 },
//         .{ .x = 1, .y = 1 },
//         .{ .x = 0, .y = 1 },
//     });
//
//     try std.testing.expect(shape.isConvex());
// }
//
// test "Not convex" {
//     const Shape = ShapeMesher(u16, f64, 10);
//     var shape = Shape.init(&.{
//         .{ .x = 0, .y = 0 },
//         .{ .x = 1, .y = 0 },
//         .{ .x = 0.25, .y = 0.25 },
//         .{ .x = 0, .y = 1 },
//     });
//
//     try std.testing.expect(!shape.isConvex());
// }

test "Convex edge case" {
    const Shape = ShapeMesher(u16, f64, 10);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0.5, .y = 0.5 },
        .{ .x = 0, .y = 1 },
    });

    try std.testing.expect(shape.isConvex());
}

test "Integrate convex" {
    const Shape = ShapeMesher(u16, f64, 10);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    });

    var integral = shape.integratePositiveLinearFn(2, 0, -1);
    try std.testing.expectEqual(0.25, integral);

    integral = shape.integratePositiveLinearFn(0, 2, -1);
    try std.testing.expectEqual(0.25, integral);
}

test "Integrate not convex 1" {
    const Shape = ShapeMesher(u16, f64, 20);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0.4, .y = 1 },
        .{ .x = 0.4, .y = 2 },
        .{ .x = 1, .y = 2 },
        .{ .x = 1, .y = 3 },
        .{ .x = 0, .y = 3 },
    });

    const integral = shape.integratePositiveLinearFn(2, 0, -1);
    try std.testing.expectApproxEqAbs(0.5, integral, 1e-15);
}

test "Integrate not convex 2" {
    const Shape = ShapeMesher(u16, f64, 20);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0.5, .y = 1 },
        .{ .x = 0.5, .y = 2 },
        .{ .x = 1, .y = 2 },
        .{ .x = 1, .y = 3 },
        .{ .x = 0, .y = 3 },
    });

    var integral = shape.integratePositiveLinearFn(2, 0, -1);
    try std.testing.expectApproxEqAbs(0.5, integral, 1e-15);

    integral = shape.integratePositiveLinearFn(-1, -0.5, 1);
    try std.testing.expectApproxEqAbs(1.0 / 3.0, integral, 1e-15);
}

test "Integrate edge case" {
    const Shape = ShapeMesher(u16, f64, 20);
    var shape = Shape.init(&.{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 1 },
    });

    const integral = shape.integratePositiveLinearFn(-1, 0, 0);
    try std.testing.expectApproxEqAbs(0, integral, 1e-15);
}
