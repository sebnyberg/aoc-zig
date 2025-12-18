const std = @import("std");

test "frac" {
    const one_10th = try Frac(i16).init(1, 10);
    const one_100th = try Frac(i16).init(1, 100);
    const one_10th_neg = try Frac(i16).init(-1, 10);

    // (1/10)/10 = 1/100
    try std.testing.expectEqual(one_100th, one_10th.div(10));

    // (1/10)*(1/10) = 1/100
    try std.testing.expectEqual(one_100th, one_10th.mul(one_10th));

    // (1/10)/(1/10) = 1
    try std.testing.expectEqual(Frac(i16).init(1, 1), one_10th.div(one_10th));

    // (-1/10)/(-1/10) = 1
    try std.testing.expectEqual(Frac(i16).init(1, 1), one_10th_neg.div(one_10th_neg));

    // (1/10)/(-1/10) = -1
    try std.testing.expectEqual(Frac(i16).init(-1, 1), one_10th.div(one_10th_neg));
}

const FracErrors = error{
    UnsupportedType,
    DivisionByZero,
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
            return .{
                .a = a,
                .b = b,
            };
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
            return Self{
                .a = self.b,
                .b = self.a,
            };
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
    };
}
