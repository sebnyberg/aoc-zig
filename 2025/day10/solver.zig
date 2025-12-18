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

const EquationSystemError = error{
    OutOfBounds,
};

pub fn EquationSystem(comptime T: type) type {
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

        pub fn print(self: *const Self) void {
            for (self.lhs, 0..) |row, i| {
                std.debug.print("[", .{});
                for (row) |val| {
                    std.debug.print("{d:3},", .{val});
                }
                std.debug.print("] = {d}\n", .{self.rhs[i]});
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
    // 4 equations, 6 variables (underdetermined)
    // [0, 0, 0, 0, 1, 1] = 3
    // [0, 1, 0, 0, 0, 1] = 5
    // [0, 0, 1, 1, 1, 0] = 4
    // [1, 1, 0, 1, 0, 0] = 7
    const example = "[##.....##.] (0,1,3,4,7,8,9) (0,2,3) (0,1,2,4,5,6,7,9) (0,1,7,8) (4,6) (0,3,5,9) (1,2,4,6,7,8) (1,8,9) (1,2,3,4,6,8,9) (3,4,7) (2,3,5,7,8) (1,2,3,5,6,8) (0,2,7,8,9) {69,83,238,251,80,189,59,241,253,61}";
    var eq = try parseExample(i64, std.testing.allocator, example);
    // var eq = try parseExample(i16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    //
    defer eq.deinit();

    var les = try LinEqSolver(i64).init(std.testing.allocator, &eq);
    defer les.deinit();

    if (try les.solveMinSum(200)) |solution| {
        defer std.testing.allocator.free(solution);
        var sum: i64 = 0;
        for (solution) |v| sum += v;
        std.debug.print("\nMin-sum solution (sum={d}):\n", .{sum});
        std.debug.print("  {any}\n", .{solution});
    } else {
        std.debug.print("\nNo solution found\n", .{});
    }

    std.debug.print("\nAfter RREF:\n", .{});
    eq.print();
    std.debug.print("col_order: {any}\n", .{les.col_order});
}

test "LinEqSolver.rref" {
    // Simple 3x3 system that needs row swaps and XOR elimination
    // Initial matrix:
    //   [0, 1, 1]  -> 5
    //   [1, 1, 0]  -> 3
    //   [1, 0, 1]  -> 4
    //
    // After RREF:
    //   [1, 0, 0]  -> 1  (x = 1)
    //   [0, 1, 0]  -> 2  (y = 2)
    //   [0, 0, 1]  -> 3  (z = 3)
    var eq = try parseExample(i16, std.testing.allocator, "[...] (1,2) (0,1) (0,2) {5,3,4}");
    defer eq.deinit();

    var solver = try LinEqSolver(i16).init(std.testing.allocator, &eq);
    defer solver.deinit();

    try solver.rref();

    // After full RREF with XOR elimination, we should have identity matrix
    const expected_lhs = [3][3]i16{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    };
    const expected_rhs = [3]i16{ 1, 2, 3 };

    for (expected_lhs, 0..) |row, i| {
        try std.testing.expectEqualSlices(i16, &row, eq.lhs[i]);
    }
    try std.testing.expectEqualSlices(i16, &expected_rhs, eq.rhs);
}

const LinEqSolverErrors = error{
    EmptyColumn,
    IntegerDivisionFailed,
};

pub fn LinEqSolver(comptime T: type) type {
    return struct {
        const Self = @This();

        eq: *EquationSystem(T),
        col_order: []usize,
        alloc: std.mem.Allocator,

        pub fn init(alloc: std.mem.Allocator, eq: *EquationSystem(T)) !Self {
            const col_order = try alloc.alloc(usize, eq.nvars());
            for (0..eq.nvars()) |i| {
                col_order[i] = i;
            }
            return Self{ .eq = eq, .col_order = col_order, .alloc = alloc };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.col_order);
        }

        /// Finds the non-negative integer solution that minimizes sum(variables).
        /// Returns solution indexed by original variable order, or null if no solution exists.
        pub fn solveMinSum(self: *Self, max_free_val: usize) !?[]T {
            try self.rref();

            const neqs = self.eq.neqs();
            const nvars = self.eq.nvars();

            // Handle overdetermined or exactly determined systems (no free variables)
            if (nvars <= neqs) {
                var solution = try self.alloc.alloc(T, nvars);
                for (0..nvars) |i| {
                    const val = self.eq.rhs[i];
                    if (val < 0) {
                        self.alloc.free(solution);
                        return null; // No non-negative solution
                    }
                    const orig_var = self.col_order[i];
                    solution[orig_var] = val;
                }
                return solution;
            }

            const nfree = nvars - neqs;

            // Allocate solution array
            var solution = try self.alloc.alloc(T, nvars);
            var best_solution: ?[]T = null;
            var best_sum: ?T = null;

            // Brute force over free variable combinations
            // Free variables are in RREF columns neqs..nvars
            var free_vals = try self.alloc.alloc(T, nfree);
            defer self.alloc.free(free_vals);
            @memset(free_vals, 0);

            while (true) {
                // Compute pivot variables from free variables
                var valid = true;
                var total_sum: T = 0;

                // Set free variables in solution
                for (0..nfree) |i| {
                    const orig_var = self.col_order[neqs + i];
                    solution[orig_var] = free_vals[i];
                    total_sum += free_vals[i];
                }

                // Compute pivot variables: pivot[i] = rhs[i] - sum(lhs[i][j] * free[j])
                for (0..neqs) |i| {
                    var val = self.eq.rhs[i];
                    for (0..nfree) |j| {
                        val -= self.eq.lhs[i][neqs + j] * free_vals[j];
                    }
                    if (val < 0) {
                        valid = false;
                        break;
                    }
                    const orig_var = self.col_order[i];
                    solution[orig_var] = val;
                    total_sum += val;
                }

                // Check if this is the best solution
                if (valid) {
                    if (best_sum == null or total_sum < best_sum.?) {
                        best_sum = total_sum;
                        if (best_solution == null) {
                            best_solution = try self.alloc.alloc(T, nvars);
                        }
                        @memcpy(best_solution.?, solution);
                    }
                }

                // Increment free variables (like counting in base max_free_val)
                var carry = true;
                for (0..nfree) |i| {
                    if (carry) {
                        free_vals[i] += 1;
                        if (free_vals[i] > max_free_val) {
                            free_vals[i] = 0;
                        } else {
                            carry = false;
                        }
                    }
                }
                if (carry) break; // All combinations exhausted
            }

            self.alloc.free(solution);
            return best_solution;
        }

        fn rref(self: *Self) !void {
            const npivot = @min(self.eq.nvars(), self.eq.neqs());
            for (0..npivot) |pivot| {
                // Find pivot entry in remaining submatrix (row >= pivot, col >= pivot)
                // Prefer ±1 to avoid integer division issues
                var sourceRowIdx: ?usize = null;
                var sourceColIdx: ?usize = null;

                // First pass: look for ±1
                outer: for (pivot..self.eq.nvars()) |colIdx| {
                    for (pivot..self.eq.neqs()) |rowIdx| {
                        const cell = self.eq.lhs[rowIdx][colIdx];
                        if (cell == 1 or cell == -1) {
                            sourceRowIdx = rowIdx;
                            sourceColIdx = colIdx;
                            break :outer;
                        }
                    }
                }

                // Second pass: any non-zero if no ±1 found
                if (sourceRowIdx == null) {
                    outer2: for (pivot..self.eq.nvars()) |colIdx| {
                        for (pivot..self.eq.neqs()) |rowIdx| {
                            const cell = self.eq.lhs[rowIdx][colIdx];
                            if (cell != 0) {
                                sourceRowIdx = rowIdx;
                                sourceColIdx = colIdx;
                                break :outer2;
                            }
                        }
                    }
                }

                // Swap rows and columns to bring pivot into position
                if (sourceRowIdx) |rowIdx| {
                    try self.eq.swapRows(pivot, rowIdx);
                } else {
                    // No more pivots found - remaining rows are all zeros
                    return;
                }

                if (sourceColIdx) |colIdx| {
                    try self.eq.swapCols(pivot, colIdx);
                    // Track the column permutation
                    const tmp = self.col_order[pivot];
                    self.col_order[pivot] = self.col_order[colIdx];
                    self.col_order[colIdx] = tmp;
                }

                // Normalize pivot row so pivot element becomes 1
                const pivotVal = self.eq.lhs[pivot][pivot];
                for (0..self.eq.nvars()) |j| {
                    const val = self.eq.lhs[pivot][j];
                    if (val == 0) {
                        continue;
                    }
                    if (@rem(val, pivotVal) != 0) {
                        return error.IntegerDivisionFailed;
                    }
                    self.eq.lhs[pivot][j] = @divTrunc(val, pivotVal);
                }
                if (@rem(self.eq.rhs[pivot], pivotVal) != 0) {
                    return error.IntegerDivisionFailed;
                }
                self.eq.rhs[pivot] = @divTrunc(self.eq.rhs[pivot], pivotVal);

                // Eliminate entries in this column from other rows by
                // subtracting (factor * pivot_row) from each row.
                for (0..self.eq.neqs()) |rowIdx| {
                    const factor = self.eq.lhs[rowIdx][pivot];
                    if (rowIdx == pivot or factor == 0) {
                        continue;
                    }

                    // Eliminate this entry by subtracting factor * pivot row
                    for (pivot..self.eq.nvars()) |colIdx| {
                        self.eq.lhs[rowIdx][colIdx] -= factor * self.eq.lhs[pivot][colIdx];
                    }
                    self.eq.rhs[rowIdx] -= factor * self.eq.rhs[pivot];
                }
            }
        }
    };
}
