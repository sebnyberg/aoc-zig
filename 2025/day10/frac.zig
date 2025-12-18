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

test "frac zero" {
    const F = mustInitFrac(i16).init;

    // Always init to 0/1
    try std.testing.expectEqual(F(0, 1), F(0, 18));

    // Refuse to inverse
    try std.testing.expectError(error.DivisionByZero, F(0, 1).inv());

    // Refuse to div with another 0/1
    try std.testing.expectError(error.DivisionByZero, F(0, 1).div(F(0, 1)));
}

test "frac mul" {
    const F = mustInitFrac(i16).init;

    try std.testing.expectEqual(F(1, 1), F(-1, 10).mul(F(-10, 1)));

    try std.testing.expectEqual(F(0, 1), F(1, 10).mul(F(0, 1)));
}

test "frac add" {
    const F = mustInitFrac(i16).init;

    try std.testing.expectEqual(F(1, 1), F(0, 10).add(1));
    try std.testing.expectEqual(F(47 * 2 + 7, 47), F(7, 47).add(2));
}

test "frac format" {
    const F = mustInitFrac(i16).init;
    var buf: [32]u8 = undefined;

    // Whole number (denominator = 1)
    const str1 = try F(5, 1).format(&buf);
    try std.testing.expectEqualStrings("5", str1);

    // Negative whole number
    const str2 = try F(-10, 1).format(&buf);
    try std.testing.expectEqualStrings("-10", str2);

    // Fraction
    const str3 = try F(3, 4).format(&buf);
    try std.testing.expectEqualStrings("3/4", str3);

    // Negative fraction
    const str4 = try F(-7, 12).format(&buf);
    try std.testing.expectEqualStrings("-7/12", str4);

    // Zero
    const str5 = try F(0, 1).format(&buf);
    try std.testing.expectEqualStrings("0", str5);
}

test "frac equals" {
    const F = mustInitFrac(i16).init;

    // Compare fractions with fractions
    try std.testing.expect(F(1, 2).equals(F(1, 2)));
    try std.testing.expect(F(2, 4).equals(F(1, 2))); // Both normalize to 1/2
    try std.testing.expect(!F(1, 2).equals(F(1, 3)));
    try std.testing.expect(!F(1, 2).equals(F(2, 1)));

    // Compare fractions with integers
    try std.testing.expect(F(5, 1).equals(5));
    try std.testing.expect(F(-10, 1).equals(-10));
    try std.testing.expect(F(0, 1).equals(0));
    try std.testing.expect(!F(1, 2).equals(1));
    try std.testing.expect(!F(3, 4).equals(0));

    // Compare with comptime integers
    try std.testing.expect(F(42, 1).equals(42));
    try std.testing.expect(!F(1, 2).equals(0));
}

const FracErrors = error{
    UnsupportedType,
    DivisionByZero,
    HasFraction,
};

// Frac contains the fraction a / b
pub fn Frac(comptime T: type) type {
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
                return self.mul(try other.inv());
            }

            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                const res = Self{
                    .a = self.a,
                    .b = self.b * other,
                };
                return res.normalize();
            }

            // Not supported
            return error.UnsupportedType;
        }

        pub fn inv(self: Self) !Self {
            if (self.a == 0) {
                return error.DivisionByZero;
            }
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

            // Or if the other argument is a signed integer
            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                if (other == 0) return error.DivisionByZero;
                const res = Self{
                    .a = self.a * other,
                    .b = self.b,
                };
                return res.normalize();
            }

            // Not supported
            return error.UnsupportedType;
        }

        pub fn add(self: Self, other: anytype) !Self {
            const Other = @TypeOf(other);

            // If the other argument is a fraction...
            if (Other == Self) {
                const res = Self{
                    .a = self.a * other.b + other.a * self.b,
                    .b = self.b * other.b,
                };
                return res.normalize();
            }

            // Or if the other argument is a signed integer
            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                const res = Self{
                    .a = self.a + other * self.b,
                    .b = self.b,
                };
                return res.normalize();
            }

            // Not supported
            return error.UnsupportedType;
        }

        pub fn sub(self: Self, other: anytype) !Self {
            const Other = @TypeOf(other);

            // If the other argument is a fraction...
            if (Other == Self) {
                const res = Self{
                    .a = self.a * other.b - other.a * self.b,
                    .b = self.b * other.b,
                };
                return res.normalize();
            }

            // Or if the other argument is a signed integer
            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                const res = Self{
                    .a = self.a - other * self.b,
                    .b = self.b,
                };
                return res.normalize();
            }

            // Not supported
            return error.UnsupportedType;
        }

        pub fn asInt(self: Self, comptime T2: type) !T2 {
            if (self.b != 1) {
                return error.HasFraction;
            }
            return @as(T2, @intCast(self.a));
        }

        pub fn iszero(self: Self) bool {
            return self.a == 0;
        }

        /// Compare this fraction with another fraction or signed integer.
        /// Since fractions are normalized, comparison is straightforward.
        pub fn equals(self: Self, other: anytype) bool {
            const Other = @TypeOf(other);

            // If comparing with another Frac
            if (Other == Self) {
                return self.a == other.a and self.b == other.b;
            }

            // If comparing with a signed integer
            const info = @typeInfo(Other);
            if (info == .int or info == .comptime_int) {
                return self.b == 1 and self.a == other;
            }

            return false;
        }

        /// Format the fraction as a string. Returns just the numerator if denominator is 1,
        /// otherwise returns "numerator/denominator".
        pub fn format(self: Self, buf: []u8) ![]const u8 {
            if (self.b == 1) {
                return std.fmt.bufPrint(buf, "{d}", .{self.a});
            } else {
                return std.fmt.bufPrint(buf, "{d}/{d}", .{ self.a, self.b });
            }
        }
    };
}
