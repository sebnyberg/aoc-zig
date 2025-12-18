const std = @import("std");

const EquationSystemError = error{
    OutOfBounds,
};

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

test "EquationSystem.swapRows" {
    var eq = try parseExample(u16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    // Try an invalid swap first
    try std.testing.expectError(error.OutOfBounds, eq.swapRows(0, eq.neqs() + 10));

    // Swap rows 0 and 2, then verify
    try eq.swapRows(0, 2);

    const expected_lhs = [4][6]u16{
        .{ 0, 0, 1, 1, 1, 0 }, // was row 2
        .{ 0, 1, 0, 0, 0, 1 },
        .{ 0, 0, 0, 0, 1, 1 }, // was row 0
        .{ 1, 1, 0, 1, 0, 0 },
    };
    const expected_rhs = [4]u16{ 4, 5, 3, 7 };

    for (expected_lhs, 0..) |row, i| {
        try std.testing.expectEqualSlices(u16, &row, eq.lhs[i]);
    }
    try std.testing.expectEqualSlices(u16, &expected_rhs, eq.rhs);
}

test "EquationSystem.swapCols" {
    var eq = try parseExample(u16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    // Try an invalid swap first
    try std.testing.expectError(error.OutOfBounds, eq.swapCols(0, eq.nvars() + 10));

    // Swap cols 0 and 4, then verify
    try eq.swapCols(0, 4);

    const expected_lhs = [4][6]u16{
        .{ 1, 0, 0, 0, 0, 1 }, // col 0 and 4 swapped
        .{ 0, 1, 0, 0, 0, 1 },
        .{ 1, 0, 1, 1, 0, 0 },
        .{ 0, 1, 0, 1, 1, 0 },
    };
    // RHS unchanged by column swap
    const expected_rhs = [4]u16{ 3, 5, 4, 7 };

    for (expected_lhs, 0..) |row, i| {
        try std.testing.expectEqualSlices(u16, &row, eq.lhs[i]);
    }
    try std.testing.expectEqualSlices(u16, &expected_rhs, eq.rhs);
}

fn EquationSystem(comptime T: type) type {
    return struct {
        lhs: [][]T,
        rhs: []T,
        alloc: std.mem.Allocator,
        const Self = @This();

        pub fn init(alloc: std.mem.Allocator, num_eqs: usize, num_vars: usize) !Self {
            const lhs = try alloc.alloc([]T, num_eqs);
            for (lhs, 0..) |_, i| {
                lhs[i] = try alloc.alloc(T, num_vars);
                @memset(lhs[i], 0);
            }
            const rhs = try alloc.alloc(T, num_eqs);
            @memset(rhs, 0);
            return Self{
                .lhs = lhs,
                .rhs = rhs,
                .alloc = alloc,
            };
        }

        pub fn neqs(self: *const Self) usize {
            return self.lhs.len;
        }

        pub fn nvars(self: *const Self) usize {
            if (self.lhs.len == 0) return 0;
            return self.lhs[0].len;
        }

        pub fn swapRows(self: *Self, i: usize, j: usize) !void {
            if (@max(i, j) >= self.lhs.len) {
                return error.OutOfBounds;
            }
            const tmp_lhs = self.lhs[i];
            self.lhs[i] = self.lhs[j];
            self.lhs[j] = tmp_lhs;

            const tmp_rhs = self.rhs[i];
            self.rhs[i] = self.rhs[j];
            self.rhs[j] = tmp_rhs;
        }

        pub fn swapCols(self: *Self, i: usize, j: usize) !void {
            if (self.lhs.len == 0) return;
            if (@max(i, j) >= self.lhs[0].len) {
                return error.OutOfBounds;
            }
            for (self.lhs) |row| {
                const tmp = row[i];
                row[i] = row[j];
                row[j] = tmp;
            }
        }

        pub fn deinit(self: *Self) void {
            for (self.lhs) |row| {
                self.alloc.free(row);
            }
            self.alloc.free(self.lhs);
            self.alloc.free(self.rhs);
        }
    };
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
    var eq = try parseExample(u16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    const les = LinEqSolver(u16).init(&eq);
    _ = les; // Solver methods to be implemented
}

fn LinEqSolver(comptime T: type) type {
    return struct {
        const Self = @This();

        eq: *EquationSystem(T),

        pub fn init(eq: *EquationSystem(T)) Self {
            return Self{ .eq = eq };
        }

        // Solving methods will go here (e.g., gaussianElimination, solve, etc.)
    };
}
