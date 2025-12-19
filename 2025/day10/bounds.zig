const std = @import("std");
const Frac = @import("frac.zig").Frac;

pub const Equality = enum {
    LessThanOrEqual,
    LessThan,
    Equal,
    GreaterThanOrEqual,
    GreaterThan,
};

pub fn Variable(comptime T: type) type {
    return struct {
        const Self = @This();

        id: []const u8,
        hi: ?Frac(T) = null,
        lo: ?Frac(T) = null,

        pub fn init(id: []const u8) Self {
            return Self{
                .id = id,
            };
        }

        pub fn flipEq(eq: Equality) Equality {
            return switch (eq) {
                .LessThanOrEqual => .GreaterThanOrEqual,
                .LessThan => .GreaterThan,
                .GreaterThanOrEqual => .LessThanOrEqual,
                .GreaterThan => .LessThan,
                .Equal => .Equal,
            };
        }

        pub fn print(self: Self) !void {
            var buf: [32]u8 = undefined;

            if (self.lo) |lo| {
                const lo_str = try lo.format(&buf);
                std.debug.print("{s} <= {s}", .{ lo_str, self.id });
            } else {
                std.debug.print("{s}", .{self.id});
            }

            if (self.hi) |hi| {
                const hi_str = try hi.format(&buf);
                std.debug.print(" <= {s}", .{hi_str});
            }

            std.debug.print("\n", .{});
        }

        pub fn consider(self: *Self, coeff: Frac(T), _other: Frac(T), _eq: Equality) !bool {
            if (coeff.a == 0) {
                return false;
            }

            // Divide other by coeff.
            const other = try _other.div(coeff);
            var eq: Equality = _eq;

            if (coeff.a < 0) {
                eq = Self.flipEq(eq);
            }

            var changed = false;

            switch (eq) {
                .Equal => {
                    if (self.lo == null) {
                        self.lo = other;
                        changed = true;
                    }
                    if (self.hi == null) {
                        self.hi = other;
                        changed = true;
                    }
                    // Check and update upper bound
                    switch (self.hi.?.cmp(other)) {
                        .less => {
                            return error.OutOfBounds;
                        },
                        .greater => {
                            self.hi = other;
                            changed = true;
                        },
                        .equal => {},
                    }
                    // Check and update lower bound
                    switch (self.lo.?.cmp(other)) {
                        .greater => {
                            return error.OutOfBounds;
                        },
                        .less => {
                            self.lo = other;
                            changed = true;
                        },
                        .equal => {},
                    }
                },
                .LessThanOrEqual => {
                    if (self.hi == null) {
                        self.hi = other;
                        changed = true;
                    }
                    if (self.lo) |lo| {
                        if (lo.cmp(other) == .greater) {
                            return error.OutOfBounds;
                        }
                    }
                    if (self.hi.?.cmp(other) == .greater) {
                        self.hi = other;
                        changed = true;
                    }
                },
                .GreaterThanOrEqual => {
                    if (self.lo == null) {
                        self.lo = other;
                        changed = true;
                    }
                    if (self.hi) |hi| {
                        if (hi.cmp(other) == .less) {
                            return error.OutOfBounds;
                        }
                    }
                    if (self.lo.?.cmp(other) == .less) {
                        self.lo = other;
                        changed = true;
                    }
                },
                else => unreachable,
            }
            return changed;
        }
    };
}

test "Variable.init" {
    const bv = Variable(i16).init("x_0");
    try std.testing.expectEqualStrings("x_0", bv.id);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.lo);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.hi);
}

test "Variable.flipEq" {
    try std.testing.expectEqual(Equality.GreaterThanOrEqual, Variable(i16).flipEq(.LessThanOrEqual));
    try std.testing.expectEqual(Equality.GreaterThan, Variable(i16).flipEq(.LessThan));
    try std.testing.expectEqual(Equality.LessThanOrEqual, Variable(i16).flipEq(.GreaterThanOrEqual));
    try std.testing.expectEqual(Equality.LessThan, Variable(i16).flipEq(.GreaterThan));
    try std.testing.expectEqual(Equality.Equal, Variable(i16).flipEq(.Equal));
}

test "Variable.consider - upper bound" {
    var bv = Variable(i16).init("x_0");

    // Set upper bound: x_0 <= 10 (with coeff 1)
    const changed1 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(10, 1), .LessThanOrEqual);
    try std.testing.expect(changed1);
    try std.testing.expectEqual(try Frac(i16).init(10, 1), bv.hi.?);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.lo);

    // Try to set a higher upper bound: x_0 <= 15 (should not change)
    const changed2 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(15, 1), .LessThanOrEqual);
    try std.testing.expect(!changed2);
    try std.testing.expectEqual(try Frac(i16).init(10, 1), bv.hi.?);

    // Set a lower upper bound: x_0 <= 5 (should change)
    const changed3 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(5, 1), .LessThanOrEqual);
    try std.testing.expect(changed3);
    try std.testing.expectEqual(try Frac(i16).init(5, 1), bv.hi.?);
}

test "Variable.consider - lower bound" {
    var bv = Variable(i16).init("x_1");

    // Set lower bound: x_1 >= 5 (with coeff 1)
    const changed1 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(5, 1), .GreaterThanOrEqual);
    try std.testing.expect(changed1);
    try std.testing.expectEqual(try Frac(i16).init(5, 1), bv.lo.?);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.hi);

    // Try to set a lower lower bound: x_1 >= 2 (should not change)
    const changed2 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(2, 1), .GreaterThanOrEqual);
    try std.testing.expect(!changed2);
    try std.testing.expectEqual(try Frac(i16).init(5, 1), bv.lo.?);

    // Set a higher lower bound: x_1 >= 8 (should change)
    const changed3 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(8, 1), .GreaterThanOrEqual);
    try std.testing.expect(changed3);
    try std.testing.expectEqual(try Frac(i16).init(8, 1), bv.lo.?);
}

test "Variable.consider - equality" {
    var bv = Variable(i16).init("x_2");

    // Set equality: x_2 = 7
    const changed = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(7, 1), .Equal);
    try std.testing.expect(changed);
    try std.testing.expectEqual(try Frac(i16).init(7, 1), bv.lo.?);
    try std.testing.expectEqual(try Frac(i16).init(7, 1), bv.hi.?);

    // Setting the same equality again should not change
    const changed2 = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(7, 1), .Equal);
    try std.testing.expect(!changed2);
}

test "Variable.consider - negative coefficient flips inequality" {
    var bv = Variable(i16).init("x_3");

    // -x_3 <= 10 means x_3 >= -10
    const changed1 = try bv.consider(try Frac(i16).init(-1, 1), try Frac(i16).init(10, 1), .LessThanOrEqual);
    try std.testing.expect(changed1);
    try std.testing.expectEqual(try Frac(i16).init(-10, 1), bv.lo.?);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.hi);

    // -x_3 >= 5 means x_3 <= -5
    const changed2 = try bv.consider(try Frac(i16).init(-1, 1), try Frac(i16).init(5, 1), .GreaterThanOrEqual);
    try std.testing.expect(changed2);
    try std.testing.expectEqual(try Frac(i16).init(-5, 1), bv.hi.?);
}

test "Variable.consider - coefficient division" {
    var bv = Variable(i16).init("x_4");

    // 2*x_4 <= 10 means x_4 <= 5
    const changed = try bv.consider(try Frac(i16).init(2, 1), try Frac(i16).init(10, 1), .LessThanOrEqual);
    try std.testing.expect(changed);
    try std.testing.expectEqual(try Frac(i16).init(5, 1), bv.hi.?);
}

test "Variable.consider - fractional coefficients" {
    var bv = Variable(i16).init("x_5");

    // (1/2)*x_5 <= 3 means x_5 <= 6
    const changed = try bv.consider(try Frac(i16).init(1, 2), try Frac(i16).init(3, 1), .LessThanOrEqual);
    try std.testing.expect(changed);
    try std.testing.expectEqual(try Frac(i16).init(6, 1), bv.hi.?);
}

test "Variable.consider - zero coefficient ignored" {
    var bv = Variable(i16).init("x_6");

    // 0*x_6 <= 10 should be ignored
    const changed = try bv.consider(try Frac(i16).init(0, 1), try Frac(i16).init(10, 1), .LessThanOrEqual);
    try std.testing.expect(!changed);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.hi);
    try std.testing.expectEqual(@as(?Frac(i16), null), bv.lo);
}

test "Variable.consider - conflicting upper bound with lower" {
    var bv = Variable(i16).init("x_7");

    // Set lower bound: x_7 >= 10
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(10, 1), .GreaterThanOrEqual);

    // Try to set upper bound: x_7 <= 5 (conflicts with lower bound)
    try std.testing.expectError(error.OutOfBounds, bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(5, 1), .LessThanOrEqual));
}

test "Variable.consider - conflicting lower bound with upper" {
    var bv = Variable(i16).init("x_8");

    // Set upper bound: x_8 <= 5
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(5, 1), .LessThanOrEqual);

    // Try to set lower bound: x_8 >= 10 (conflicts with upper bound)
    try std.testing.expectError(error.OutOfBounds, bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(10, 1), .GreaterThanOrEqual));
}

test "Variable.consider - equality conflicts with upper bound" {
    var bv = Variable(i16).init("x_9");

    // Set upper bound: x_9 <= 5
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(5, 1), .LessThanOrEqual);

    // Try to set equality: x_9 = 10 (conflicts with upper bound)
    try std.testing.expectError(error.OutOfBounds, bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(10, 1), .Equal));
}

test "Variable.consider - multiple constraints narrowing bounds" {
    var bv = Variable(i16).init("x_10");

    // Start with wide bounds
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(100, 1), .LessThanOrEqual);
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(0, 1), .GreaterThanOrEqual);

    try std.testing.expectEqual(try Frac(i16).init(0, 1), bv.lo.?);
    try std.testing.expectEqual(try Frac(i16).init(100, 1), bv.hi.?);

    // Narrow from above
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(50, 1), .LessThanOrEqual);
    try std.testing.expectEqual(try Frac(i16).init(50, 1), bv.hi.?);

    // Narrow from below
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(25, 1), .GreaterThanOrEqual);
    try std.testing.expectEqual(try Frac(i16).init(25, 1), bv.lo.?);

    // Final bounds should be: 25 <= x_10 <= 50
    try std.testing.expectEqual(try Frac(i16).init(25, 1), bv.lo.?);
    try std.testing.expectEqual(try Frac(i16).init(50, 1), bv.hi.?);
}

test "Variable.consider - equality within existing bounds" {
    var bv = Variable(i16).init("x_11");

    // Set bounds: 0 <= x_11 <= 100
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(100, 1), .LessThanOrEqual);
    _ = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(0, 1), .GreaterThanOrEqual);

    // Set equality within bounds: x_11 = 50 (should tighten to exact value)
    const changed = try bv.consider(try Frac(i16).init(1, 1), try Frac(i16).init(50, 1), .Equal);
    try std.testing.expect(changed);
    try std.testing.expectEqual(try Frac(i16).init(50, 1), bv.lo.?);
    try std.testing.expectEqual(try Frac(i16).init(50, 1), bv.hi.?);
}
