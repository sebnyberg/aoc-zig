const std = @import("std");

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
    try std.testing.expectError(error.OutOfBounds, eq.swapRows(0, eq.nrows() + 10));

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
    try std.testing.expectError(error.OutOfBounds, eq.swapCols(0, eq.ncols() + 10));

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

const EquationSystemError = error{
    OutOfBounds,
};

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

        pub fn nrows(self: *const Self) usize {
            return self.lhs.len;
        }

        pub fn ncols(self: *const Self) usize {
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

        pub fn print(self: *Self) void {
            std.debug.print("\n", .{});
            for (0..self.nrows()) |i| {
                for (0..self.ncols()) |j| {
                    std.debug.print("{d:3} ", .{self.lhs[i][j]});
                }
                std.debug.print("= {d:3}\n", .{self.rhs[i]});
            }
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

test "LinEqSolver.rref" {
    var eq = try parseExample(i16, std.testing.allocator, "[...] (1,2) (0,1) (0,2) {5,3,4}");
    defer eq.deinit();

    var solver = LinEqSolver(i16).init(&eq);
    try solver.rref();

    // // After full RREF with XOR elimination, we should have identity matrix
    // const expected_lhs = [3][3]i16{
    //     .{ 1, 0, 0 },
    //     .{ 0, 1, 0 },
    //     .{ 0, 0, 1 },
    // };
    // const expected_rhs = [3]i16{ 2, 1, 4 };
    //
    // for (expected_lhs, 0..) |row, i| {
    //     try std.testing.expectEqualSlices(i16, &row, eq.lhs[i]);
    // }
    // try std.testing.expectEqualSlices(i16, &expected_rhs, eq.rhs);
}

const LinEqSolverErrors = error{
    EmptyColumn,
    IntegerDivisionFailed,
};

fn LinEqSolver(comptime T: type) type {
    return struct {
        const Self = @This();

        eq: *EquationSystem(T),

        pub fn init(eq: *EquationSystem(T)) Self {
            return Self{ .eq = eq };
        }

        pub fn solve(self: *Self) ![]T {
            // To solve this linear equation system, we start with converting the systems
            // to reduced row echelon form.
            self.rref();
        }

        fn rref(self: *Self) !void {
            const npivot = @min(self.eq.ncols(), self.eq.nrows());
            self.eq.print();
            for (0..npivot) |pivot| {
                // Find first non-zero entry in this column
                var sourceRowIdx: ?usize = null;
                for (pivot..npivot) |rowIdx| {
                    const cell = self.eq.lhs[rowIdx][pivot];
                    if (cell != 0) {
                        sourceRowIdx = rowIdx;
                        break;
                    }
                }

                // Swap
                if (sourceRowIdx) |idx| {
                    // Move this row (this might be a noop)
                    try self.eq.swapRows(pivot, idx);
                } else {
                    return error.EmptyColumn;
                }

                // Normalize pivot row
                const factor = self.eq.lhs[pivot][pivot];
                for (0..self.eq.ncols()) |j| {
                    const val = self.eq.lhs[pivot][j];
                    if (val == 0) {
                        continue;
                    }
                    if (@rem(val, factor) != 0) {
                        return error.IntegerDivisionFailed;
                    }
                    self.eq.lhs[pivot][j] = @divTrunc(val, factor);
                }

                // Eliminate entries in this column from other rows by
                // removing this row from other rows as needed.
                for (0..self.eq.nrows()) |rowIdx| {
                    if (rowIdx == pivot or self.eq.lhs[rowIdx][pivot] == 0) {
                        continue;
                    }

                    // Eliminate this entry by subtracting the pivot row
                    for (pivot..self.eq.ncols()) |colIdx| {
                        self.eq.lhs[rowIdx][colIdx] -= self.eq.lhs[pivot][colIdx];
                    }
                    self.eq.rhs[rowIdx] -= self.eq.rhs[pivot];
                }
            }
        }
    };
}
