const math = @import("std").math;

fn assertFloat(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .float) {
        @compileError("Expected float type");
    }
}

pub fn Point(T: type) type {
    assertFloat(T);
    return struct {
        x: T,
        y: T,

        const Self = @This();

        pub fn init(x: f64, y: f64) Self {
            return .{
                .x = x,
                .y = y,
            };
        }

        pub fn distance(self: *const Self, other: *const Self) T {
            return @sqrt(math.pow(T, self.x - other.x, 2) + math.pow(T, self.y - other.y, 2));
        }
    };
}
