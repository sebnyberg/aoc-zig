const std = @import("std");

const Frac = @import("frac.zig").Frac;

test "parseExample" {
    var eq = try parseExample(i8, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    const expected_lhs = [4][6]i8{
        .{ 0, 0, 0, 0, 1, 1 },
        .{ 0, 1, 0, 0, 0, 1 },
        .{ 0, 0, 1, 1, 1, 0 },
        .{ 1, 1, 0, 1, 0, 0 },
    };
    const expected_rhs = [4]i8{ 3, 5, 4, 7 };

    try std.testing.expectEqual(@as(usize, 4), eq.lhs.len);
    try std.testing.expectEqual(@as(usize, 6), eq.lhs[0].len);

    for (expected_lhs, 0..) |row, i| {
        for (row, 0..) |cell, j| {
            try std.testing.expectEqual(try Frac(i8).init(cell, 1), eq.lhs[i][j]);
        }
    }
    for (expected_rhs, 0..) |cell, i| {
        try std.testing.expectEqual(try Frac(i8).init(cell, 1), eq.rhs[i]);
    }
}

test "EquationSystem.swapRows" {
    var eq = try parseExample(i16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    // Try an invalid swap first
    try std.testing.expectError(error.OutOfBounds, eq.swapRows(0, eq.nrows() + 10));

    // Swap rows 0 and 2, then verify
    try eq.swapRows(0, 2);

    const expected_lhs = [4][6]i16{
        .{ 0, 0, 1, 1, 1, 0 }, // was row 2
        .{ 0, 1, 0, 0, 0, 1 },
        .{ 0, 0, 0, 0, 1, 1 }, // was row 0
        .{ 1, 1, 0, 1, 0, 0 },
    };
    const expected_rhs = [4]i16{ 4, 5, 3, 7 };

    for (expected_lhs, 0..) |row, i| {
        for (row, 0..) |cell, j| {
            try std.testing.expectEqual(try Frac(i16).init(cell, 1), eq.lhs[i][j]);
        }
    }
    for (expected_rhs, 0..) |cell, i| {
        try std.testing.expectEqual(try Frac(i16).init(cell, 1), eq.rhs[i]);
    }
}

test "EquationSystem.swapCols" {
    var eq = try parseExample(i16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    // Try an invalid swap first
    try std.testing.expectError(error.OutOfBounds, eq.swapCols(0, eq.ncols() + 10));

    // Swap cols 0 and 4, then verify
    try eq.swapCols(0, 4);

    const expected_lhs = [4][6]i16{
        .{ 1, 0, 0, 0, 0, 1 }, // col 0 and 4 swapped
        .{ 0, 1, 0, 0, 0, 1 },
        .{ 1, 0, 1, 1, 0, 0 },
        .{ 0, 1, 0, 1, 1, 0 },
    };
    // RHS unchanged by column swap
    const expected_rhs = [4]i16{ 3, 5, 4, 7 };

    for (expected_lhs, 0..) |row, i| {
        for (row, 0..) |cell, j| {
            try std.testing.expectEqual(try Frac(i16).init(cell, 1), eq.lhs[i][j]);
        }
    }
    for (expected_rhs, 0..) |cell, i| {
        try std.testing.expectEqual(try Frac(i16).init(cell, 1), eq.rhs[i]);
    }
}

const EquationSystemError = error{
    OutOfBounds,
};

fn EquationSystem(comptime T: type) type {
    return struct {
        lhs: [][]Frac(T),
        rhs: []Frac(T),
        alloc: std.mem.Allocator,
        allocated_rows: usize,
        const Self = @This();

        pub fn init(alloc: std.mem.Allocator, num_eqs: usize, num_vars: usize) !Self {
            const zeroFrac = try Frac(T).init(0, 1);

            const lhs = try alloc.alloc([]Frac(T), num_eqs);
            for (lhs, 0..) |_, i| {
                lhs[i] = try alloc.alloc(Frac(T), num_vars);
                for (0..lhs[i].len) |j| {
                    lhs[i][j] = zeroFrac;
                }
            }
            const rhs = try alloc.alloc(Frac(T), num_eqs);
            for (0..rhs.len) |i| {
                rhs[i] = zeroFrac;
            }
            return Self{
                .lhs = lhs,
                .rhs = rhs,
                .alloc = alloc,
                .allocated_rows = num_eqs,
            };
        }

        pub fn nrows(self: *const Self) usize {
            return self.lhs.len;
        }

        pub fn removeRow(self: *Self, idx: usize) !void {
            if (idx >= self.lhs.len) {
                return error.OutOfBounds;
            }
            for (idx..self.lhs.len - 1) |i| {
                self.lhs[i] = self.lhs[i + 1];
                self.rhs[i] = self.rhs[i + 1];
            }
            self.lhs = self.lhs[0 .. self.lhs.len - 1];
            self.rhs = self.rhs[0 .. self.rhs.len - 1];
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
            // Use original allocation pointers and sizes
            const orig_lhs = self.lhs.ptr[0..self.allocated_rows];
            const orig_rhs = self.rhs.ptr[0..self.allocated_rows];

            for (orig_lhs) |row| {
                self.alloc.free(row);
            }
            self.alloc.free(orig_lhs);
            self.alloc.free(orig_rhs);
        }

        pub fn print(self: *Self) void {
            var buf: [32]u8 = undefined;
            std.debug.print("\n", .{});
            for (0..self.nrows()) |i| {
                for (0..self.ncols()) |j| {
                    const str = self.lhs[i][j].format(&buf) catch unreachable;
                    std.debug.print("{s:>6} ", .{str});
                }
                std.debug.print("| ", .{});
                const rhs_str = self.rhs[i].format(&buf) catch unreachable;
                std.debug.print("{s:>6}", .{rhs_str});
                std.debug.print("\n", .{});
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
            eq.lhs[eqIdx][varIdx] = try Frac(T).init(1, 1);
        }
    }

    // Add y
    {
        var iter = std.mem.tokenizeScalar(u8, y, ',');
        var i: usize = 0;
        while (iter.next()) |yStr| : (i += 1) {
            const yVal = try std.fmt.parseInt(T, yStr, 10);
            eq.rhs[i] = try Frac(T).init(yVal, 1);
        }
    }

    return eq;
}

const row13 = "[##.##.....] (1,2,3,4,9) (0,7) (0,3,8,9) (0,2) (0,1,8) (1,2,9) (0,2,3,5,6,7,8) (0,1,3,4,6,7) (7) (0,2,3,4,5,6,7,8) (0,1,3,7,8,9) (0,1,2,3,4,5,8,9) (0,1,3,4,6,7,9) {79,44,43,71,37,21,28,61,55,60}";

test "SolveInput" {
    const contents = try std.fs.cwd().readFileAlloc(std.testing.allocator, "./input", 1024 * 1024);
    defer std.testing.allocator.free(contents);

    var rows = std.mem.tokenizeScalar(u8, contents, '\n');
    var k: u64 = 0;

    const filter = [_]usize{};
    while (rows.next()) |row| : (k += 1) {
        if (filter.len > 0) {
            var ok = false;
            for (filter) |kk| {
                if (kk == k) {
                    ok = true;
                }
            }
            if (!ok) {
                continue;
            }
        }

        var eq = try parseExample(i16, std.testing.allocator, row);
        defer eq.deinit();
        std.debug.print("Eq {d}\n", .{k});
        var les = LinEqSolver(i16).init(&eq);
        try les.rref();
    }
}

test "LinEqSolver" {
    var eq = try parseExample(i16, std.testing.allocator, "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}");
    defer eq.deinit();

    const les = LinEqSolver(i16).init(&eq);
    _ = les; // Solver methods to be implemented
}

test "LinEqSolver.rref" {
    // var eq = try parseExample(i16, std.testing.allocator, row13);
    // defer eq.deinit();
    //
    // var solver = LinEqSolver(i16).init(&eq);
    // try solver.rref();

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
    IntegerDivisionFailed,
    NoPivot,
    NoSolution,
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
            var k: u64 = 0;
            const npivot = @min(self.eq.ncols(), self.eq.nrows());

            for (0..npivot) |pivot| {
                std.debug.print("Iteration {d}\n", .{k});
                k += 1;
                self.eq.print();

                // Find first non-zero entry to swap into this position
                var found = false;
                outer: for (pivot..self.eq.ncols()) |j| {
                    for (pivot..npivot) |i| {
                        if (!self.eq.lhs[i][j].iszero()) {
                            try self.eq.swapCols(pivot, j);
                            try self.eq.swapRows(pivot, i);
                            found = true;
                            break :outer;
                        }
                    }
                }
                if (!found) {
                    // TODO: if the value (RHS) is non-zero, then no solution exists,
                    // but that should never happen, right?
                    for (pivot..npivot) |i| {
                        if (!self.eq.rhs[i].iszero()) {
                            return error.NoSolution;
                        }
                    }

                    // We can safely ignore the rest of the system.
                    while (self.eq.nrows() > pivot) {
                        try self.eq.removeRow(self.eq.nrows() - 1);
                    }
                    break;
                }

                // Normalize pivot row
                {
                    const factor = self.eq.lhs[pivot][pivot];
                    for (0..self.eq.ncols()) |j| {
                        const val = self.eq.lhs[pivot][j];
                        if (val.equals(0)) {
                            continue;
                        }
                        self.eq.lhs[pivot][j] = try val.div(factor);
                    }
                }

                // Eliminate entries in this column from other rows by
                // removing this row from other rows as needed.
                for (0..self.eq.nrows()) |rowIdx| {
                    if (rowIdx == pivot or self.eq.lhs[rowIdx][pivot].equals(0)) {
                        continue;
                    }

                    const remove_factor = self.eq.lhs[rowIdx][pivot];

                    // Eliminate this entry by subtracting the pivot row
                    for (pivot..self.eq.ncols()) |colIdx| {
                        const current = self.eq.lhs[rowIdx][colIdx];

                        const pivot_val = try self.eq.lhs[pivot][colIdx].mul(remove_factor);
                        self.eq.lhs[rowIdx][colIdx] = try current.sub(pivot_val);
                    }
                    const current_rhs = self.eq.rhs[rowIdx];
                    const pivot_rhs = self.eq.rhs[pivot];
                    self.eq.rhs[rowIdx] = try current_rhs.sub(pivot_rhs);
                }
            }
        }
    };
}
