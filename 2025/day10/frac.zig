const std = @import("std");

fn mustInitFrac(comptime T: type) type {
    return struct {
        pub fn init(comptime a: T, comptime b: T) Frac(T) {
            comptime {
                if (b == 0) {
                    @compileError("Initialized frac with zero denominator");
                }
            }
            const res = Frac(T){
                .a = a,
                .b = b,
            };
            return res.normalize();
        }
    };
}

test "frac" {
    const F = mustInitFrac(i16).init;

    try std.testing.expectEqual(F(1, 100), F(1, 10).div(10));

    try std.testing.expectEqual(F(1, 100), F(1, 10).mul(F(1, 10)));

    try std.testing.expectEqual(F(1, 1), F(1, 10).div(F(1, 10)));

    try std.testing.expectEqual(F(1, 1), F(-1, 10).div(F(-1, 10)));

    try std.testing.expectEqual(F(-1, 1), F(1, 10).div(F(-1, 10)));
}

test "frac.normalize" {
    const F = mustInitFrac(i16).init;

    try std.testing.expectEqual(F(-1, 10), F(1, -10));

    try std.testing.expectEqual(F(-10, 1), F(1, -10).inv());
}

test "frac mul" {
    const F = mustInitFrac(i16).init;

    try std.testing.expectEqual(F(1, 1), F(-1, 10).mul(F(-10, 1)));
}

const FracErrors = error{
    UnsupportedType,
    DivisionByZero,
    HasFraction,
};

// Frac contains the fraction a / b
fn Frac(comptime T: type) type {
    return struct {
        const Self = @This();

        a: T,
        b: T,

        pub fn init(a: T, b: T) !Self {
            comptime {
                const info = @typeInfo(T);
                if (info != .int or info.int.signedness != .signed) {
                    @compileError("Frac.init requires a signed integer type");
                }
            }

            if (b == 0) {
                return error.DivisionByZero;
            }
            const res = Self{
                .a = a,
                .b = b,
            };
            return res.normalize();
        }

        pub fn normalize(self: Self) Self {
            var res = Self{
                .a = self.a,
                .b = self.b,
            };
            if (self.b < 0) {
                res.a = -res.a;
                res.b = -res.b;
            }
            const gcd = std.math.gcd(@abs(res.a), @abs(res.b));
            const gcdInt: T = @intCast(gcd);
            res.a = @divExact(res.a, gcdInt);
            res.b = @divExact(res.b, gcdInt);
            return res;
        }

        pub fn div(self: Self, other: anytype) !Self {
            const Other = @TypeOf(other);
            if (Other == Self) {
                return self.mul(other.inv());
            }

            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                const res = Self{
                    .a = self.a,
                    .b = self.b * other,
                };
                return res.normalize();
            }

            // Case 3: everything else
            return error.UnsupportedType;
        }

        pub fn inv(self: Self) Self {
            const res = Self{
                .a = self.b,
                .b = self.a,
            };
            return res.normalize();
        }

        pub fn mul(self: Self, other: anytype) !Self {
            const Other = @TypeOf(other);

            // If the other argument is a fraction...
            if (Other == Self) {
                if (other.b == 0) return error.DivisionByZero;
                const res = Self{
                    .a = self.a * other.a,
                    .b = self.b * other.b,
                };
                return res.normalize();
            }

            // Or if the other argument is an integer
            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                if (other == 0) return error.DivisionByZero;
                const res = Self{
                    .a = self.a * other,
                    .b = self.b,
                };
                return res.normalize();
            }

            // Case 3: everything else
            return error.UnsupportedType;
        }

        pub fn asInt(self: Self, comptime T2: type) !T2 {
            if (self.b != 1) {
                return error.HasFraction;
            }
            return @as(T2, @intCast(self.a));
        }
    };
}
