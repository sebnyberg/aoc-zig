const std = @import("std");

const EquationSystemError = error{
    OutOfBounds,
};

fn EquationSystem(comptime T: type) type {
    return struct {
        lhs: [][]T,
        rhs: []T,
        alloc: std.mem.Allocator,
        const Self = @This();

        pub fn init(alloc: std.mem.Allocator, neqs: usize, nvars: usize) !Self {
            const lhs = try alloc.alloc([]T, neqs);
            for (lhs, 0..) |_, i| {
                lhs[i] = try alloc.alloc(T, nvars);
                @memset(lhs[i], 0);
            }
            const rhs = try alloc.alloc(T, neqs);
            @memset(rhs, 0);
            return Self{
                .lhs = lhs,
                .rhs = rhs,
                .alloc = alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.lhs, 0..) |_, i| {
                self.alloc.free(self.lhs[i]);
            }
            self.alloc.free(self.lhs);
            self.alloc.free(self.rhs);
        }
    };
}

test "parseExample" {
    var eq = try parseExample(u8, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    const expected_lhs = [4][6]u8{
        .{ 0, 0, 0, 0, 1, 1 },
        .{ 0, 1, 0, 0, 0, 1 },
        .{ 0, 0, 1, 1, 1, 0 },
        .{ 1, 1, 0, 1, 0, 0 },
    };
    const expected_rhs = [4]u8{ 3, 5, 4, 7 };

    try std.testing.expectEqual(@as(usize, 4), eq.lhs.len);
    try std.testing.expectEqual(@as(usize, 6), eq.lhs[0].len);

    for (expected_lhs, 0..) |row, i| {
        try std.testing.expectEqualSlices(u8, &row, eq.lhs[i]);
    }
    try std.testing.expectEqualSlices(u8, &expected_rhs, eq.rhs);
}

fn parseExample(comptime T: type, alloc: std.mem.Allocator, s: []const u8) !EquationSystem(T) {
    var fieldIter = std.mem.tokenizeScalar(u8, s, ' ');

    // Capture X and y
    var A = std.ArrayList([]const u8){};
    defer A.deinit(alloc);
    var y: []const u8 = undefined;
    while (fieldIter.next()) |field| {
        switch (field[0]) {
            '[' => continue,
            '(' => try A.append(alloc, field[1 .. field.len - 1]),
            '{' => y = field[1 .. field.len - 1],
            else => unreachable,
        }
    }

    const nvars = A.items.len;
    const neq = std.mem.count(u8, y, ",") + 1;
    const eq = try EquationSystem(T).init(alloc, neq, nvars);

    // Add X
    // Each A[i] contains the equation indices where variable i has coefficient 1
    for (A.items, 0..) |idxsStr, varIdx| {
        var numsIter = std.mem.tokenizeScalar(u8, idxsStr, ',');
        while (numsIter.next()) |idxStr| {
            const eqIdx = try std.fmt.parseInt(usize, idxStr, 10);
            eq.lhs[eqIdx][varIdx] = 1;
        }
    }

    // Add y
    {
        var iter = std.mem.tokenizeScalar(u8, y, ',');
        var i: usize = 0;
        while (iter.next()) |yStr| : (i += 1) {
            const yVal = try std.fmt.parseInt(T, yStr, 10);
            eq.rhs[i] = yVal;
        }
    }

    return eq;
}

test "LinEqSolver" {
    // Constants
    const maxSize = 20;

    var eq = try parseExample(u16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();
    const neqs = eq.lhs.len;

    var les = try LinEqSolver(u16, maxSize).init(
        std.testing.allocator,
        eq.lhs,
        eq.rhs,
    );
    defer les.deinit();

    try std.testing.expectError(error.OutOfBounds, les.swapRows(0, neqs + 10));
}

const SolverError = error{
    InvalidDimensions,
    OutOfBounds,
};

fn LinEqSolver(comptime T: type, comptime vectorSize: usize) type {
    return struct {
        const Self = @This();

        eqs: []@Vector(vectorSize, T),
        alloc: std.mem.Allocator,

        fn init(alloc: std.mem.Allocator, lhs: [][]T, rhs: []T) !Self {
            if (lhs.len != rhs.len or lhs.len + 1 > vectorSize) {
                return error.InvalidDimensions;
            }

            var eqs = try alloc.alloc(@Vector(vectorSize, T), lhs.len);

            var arr: [vectorSize]T = [_]T{0} ** vectorSize;
            for (eqs, 0..) |_, i| {
                @memcpy(arr[0..lhs[i].len], lhs[i]);
                eqs[i] = arr;
                eqs[i][vectorSize - 1] = rhs[i];
            }

            return Self{
                .alloc = alloc,
                .eqs = eqs,
            };
        }

        fn swapRows(self: *Self, i: usize, j: usize) !void {
            if (@max(i, j) > self.eqs.len) {
                return error.OutOfBounds;
            }

            const tmp = self.eqs[i];
            self.eqs[i] = self.eqs[j];
            self.eqs[j] = tmp;
        }

        fn deinit(self: *Self) void {
            self.alloc.free(self.eqs);
        }
    };
}
