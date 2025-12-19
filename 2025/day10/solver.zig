const std = @import("std");

const Frac = @import("frac.zig").Frac;
const bounds = @import("bounds.zig");

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
        cmps: []bounds.Comparison,
        alloc: std.mem.Allocator,
        allocated_rows: usize,
        const Self = @This();

        pub fn init(alloc: std.mem.Allocator, num_eqs: usize, num_vars: usize) !Self {
            const zeroFrac = try Frac(T).init(0, 1);

            const lhs = try alloc.alloc([]Frac(T), num_eqs);
            const cmps = try alloc.alloc(bounds.Comparison, num_eqs);
            for (lhs, 0..) |_, i| {
                lhs[i] = try alloc.alloc(Frac(T), num_vars);
                for (0..lhs[i].len) |j| {
                    lhs[i][j] = zeroFrac;
                }
            }
            const rhs = try alloc.alloc(Frac(T), num_eqs);
            for (0..rhs.len) |i| {
                rhs[i] = zeroFrac;
                cmps[i] = .Equal;
            }
            return Self{
                .lhs = lhs,
                .rhs = rhs,
                .cmps = cmps,
                .alloc = alloc,
                .allocated_rows = num_eqs,
            };
        }

        pub fn nrows(self: Self) usize {
            return self.lhs.len;
        }

        /// addRows adds the row "source" factor times to row "target"
        pub fn addRows(self: *Self, target: usize, source: usize, factor: Frac(T)) !void {
            for (0..self.ncols()) |j| {
                const delta = try self.lhs[source][j].mul(factor);
                self.lhs[target][j] = try self.lhs[target][j].add(delta);
            }

            const rhsDelta = try self.rhs[source].mul(factor);
            // std.debug.print("\n", .{});
            // printFrac(T, rhsDelta);
            // std.debug.print("\n", .{});
            self.rhs[target] = try self.rhs[target].add(rhsDelta);
        }

        /// mulRows multiplies a row with a factor
        pub fn mulRow(self: *Self, target: usize, factor: T) !void {
            for (0..self.ncols()) |j| {
                self.lhs[target][j].mul(factor);
            }
            self.rhs[target].mul(factor);

            if (self.cmps[target] == .Equal) {
                return;
            }

            // Check if the factor is negative
            var neg = false;
            const ti = @typeInfo(@TypeOf(factor));
            if (@TypeOf(factor) == Frac(T)) {
                if (factor.a < 0) {
                    neg = true;
                }
            } else if (ti == .int or ti == .comptime_int) {
                if (factor < 0) {
                    neg = true;
                }
            }
            // Flip equality.
            self.cmps[target] = self.cmps[target].flip();
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

        pub fn ncols(self: Self) usize {
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
            const orig_cmps = self.cmps.ptr[0..self.allocated_rows];

            for (orig_lhs) |row| {
                self.alloc.free(row);
            }
            self.alloc.free(orig_lhs);
            self.alloc.free(orig_rhs);
            self.alloc.free(orig_cmps);
        }

        pub fn print(self: *Self) void {
            var buf: [32]u8 = undefined;
            std.debug.print("\n", .{});
            for (0..self.nrows()) |i| {
                for (0..self.ncols()) |j| {
                    const str = self.lhs[i][j].format(&buf) catch unreachable;
                    std.debug.print("{s:>6} ", .{str});
                }
                const sym = self.cmps[i].symbol();
                std.debug.print("{s:>2} ", .{sym});
                const rhs_str = self.rhs[i].format(&buf) catch unreachable;
                std.debug.print("{s:>6}", .{rhs_str});
                std.debug.print("\n", .{});
            }
        }

        /// rref converts the equation system to reduced row echelon form.
        /// This version matches Python's behavior: only row operations, no column swaps.
        pub fn rref(self: *Self) !void {
            const npivot = @min(self.ncols(), self.nrows());
            var pivot_row: usize = 0;

            // Process each column looking for pivots
            for (0..self.ncols()) |col| {
                if (pivot_row >= npivot) break;

                // Find a non-zero entry in this column at or below pivot_row
                var found = false;
                for (pivot_row..self.nrows()) |i| {
                    if (!self.lhs[i][col].iszero()) {
                        // Swap this row with the pivot row
                        try self.swapRows(pivot_row, i);
                        found = true;
                        break;
                    }
                }

                // If no pivot found in this column, move to next column
                if (!found) {
                    continue;
                }

                // Normalize pivot row
                {
                    const factor = self.lhs[pivot_row][col];

                    for (0..self.ncols()) |j| {
                        self.lhs[pivot_row][j] = try self.lhs[pivot_row][j].div(factor);
                    }
                    self.rhs[pivot_row] = try self.rhs[pivot_row].div(factor);
                }

                // Eliminate entries in this column from all other rows
                for (0..self.nrows()) |row_idx| {
                    if (row_idx == pivot_row or self.lhs[row_idx][col].iszero()) {
                        continue;
                    }

                    const remove_factor = try self.lhs[row_idx][col].mul(-1);
                    try self.addRows(row_idx, pivot_row, remove_factor);
                }

                pivot_row += 1;
            }

            // Remove trailing zero rows (for overdetermined systems)
            while (self.nrows() > 0) {
                const last_row = self.nrows() - 1;
                var all_zero = true;

                // Check if last row is all zeros (including RHS)
                for (0..self.ncols()) |j| {
                    if (!self.lhs[last_row][j].iszero()) {
                        all_zero = false;
                        break;
                    }
                }
                if (!self.rhs[last_row].iszero()) {
                    all_zero = false;
                }

                if (all_zero) {
                    try self.removeRow(last_row);
                } else {
                    break;
                }
            }
        }
    };
}

pub fn parseExample(comptime T: type, alloc: std.mem.Allocator, s: []const u8) !EquationSystem(T) {
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

test "SolveInput" {
    const contents = try std.fs.cwd().readFileAlloc(std.testing.allocator, "./input", 1024 * 1024);
    defer std.testing.allocator.free(contents);

    var rows = std.mem.tokenizeScalar(u8, contents, '\n');
    var k: u64 = 0;

    const filter = [_]usize{};
    var total: i16 = 0;
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
        var les = LinEqSolver(i16).init(&eq);

        const vals = try std.testing.allocator.alloc(i16, eq.ncols());
        defer std.testing.allocator.free(vals);
        const cost = try les.minimizeCost(vals, GetCostFn(i16));
        total += cost;
        std.debug.print("Cost for eq {d}: {d}\n", .{ k, cost });
    }
    std.debug.print("Total cost: {d}\n", .{total});
}

fn GetCostFn(comptime T: type) fn ([]T) T {
    return struct {
        fn f(xs: []T) T {
            var res: T = 0;
            for (xs) |x| res += x;
            return res;
        }
    }.f;
}

const LinEqSolverErrors = error{
    IntegerDivisionFailed,
    NoPivot,
    NoSolution,
};

fn printFrac(comptime T: type, a: Frac(T)) void {
    var buf = [_]u8{0} ** 128;
    const s = a.format(&buf) catch unreachable;
    std.debug.print("{s}", .{s});
}

pub fn LinEqSolver(comptime T: type) type {
    return struct {
        const Self = @This();

        eq: *EquationSystem(T),

        pub fn init(eq: *EquationSystem(T)) Self {
            return Self{ .eq = eq };
        }

        pub fn solve(self: *Self, values: []T) !void {
            const n = self.eq.ncols();
            const m = self.eq.nrows();

            // Solve for each row from bottom to top
            // For each row, find the pivot column (leading 1) and solve for that variable
            for (0..m) |_i| {
                const i = m - _i - 1;

                // Find pivot column in this row (first non-zero entry)
                var pivot_col: ?usize = null;
                for (0..n) |j| {
                    if (!self.eq.lhs[i][j].iszero()) {
                        pivot_col = j;
                        break;
                    }
                }

                if (pivot_col == null) {
                    // All-zero row, skip
                    continue;
                }

                const pcol = pivot_col.?;

                // Calculate rhs - sum of (coefficient * value) for all other columns
                var val = self.eq.rhs[i];
                for (0..n) |j| {
                    if (j == pcol) continue;
                    const colval = try self.eq.lhs[i][j].mul(values[j]);
                    val = try val.sub(colval);
                }

                // Divide by the pivot coefficient to get the value
                val = try val.div(self.eq.lhs[i][pcol]);

                // Check result
                if (!val.isInteger()) {
                    return error.HasFraction;
                }

                // Parse as int and check that it's positive
                const x = try val.asInt(T);
                if (x < 0) {
                    return error.OutOfBounds;
                }

                values[pcol] = x;
            }
        }

        pub fn minimizeCost(self: *Self, result: []T, costFn: fn ([]T) T) !T {
            const upperbound: T = 274;

            // Convert to RREF
            try self.eq.rref();
            @memset(result, 0);

            const n = self.eq.ncols();
            const m = self.eq.nrows();

            // Identify pivot columns by finding the leading 1 in each row
            var is_pivot = [_]bool{false} ** 64; // Max 64 columns
            for (0..m) |i| {
                for (0..n) |j| {
                    if (!self.eq.lhs[i][j].iszero()) {
                        is_pivot[j] = true;
                        break;
                    }
                }
            }

            // Build list of free variable columns
            var free_cols: [64]usize = undefined;
            var nfree: usize = 0;
            for (0..n) |j| {
                if (!is_pivot[j]) {
                    free_cols[nfree] = j;
                    nfree += 1;
                }
            }

            // If no free variables, solve directly
            if (nfree == 0) {
                try self.solve(result);
                return costFn(result);
            }

            var minCost: T = std.math.maxInt(T);

            // Iterate over all combinations of free variable values
            const ncombs = std.math.pow(u64, @intCast(upperbound), @intCast(nfree));
            std.debug.print("Going through {d} combs\n", .{ncombs});
            for (0..ncombs) |_x| {
                var x = _x;
                @memset(result, 0);

                // Set free variable values
                for (0..nfree) |k| {
                    const val = @mod(x, @as(u64, @intCast(upperbound)));
                    result[free_cols[k]] = @intCast(val);
                    x = @divTrunc(x, @as(u64, @intCast(upperbound)));
                }

                if (self.solve(result)) |_| {
                    minCost = @min(minCost, costFn(result));
                } else |_| {}
            }

            return minCost;
        }
    };
}
