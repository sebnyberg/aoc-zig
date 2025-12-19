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

        pub fn nrows(self: *const Self) usize {
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
        fn rref(self: *Self) !void {
            var k: u64 = 0;
            const npivot = @min(self.ncols(), self.nrows());

            for (0..npivot) |pivot| {
                k += 1;

                // Find first non-zero entry to swap into this position
                var found = false;
                outer: for (pivot..self.ncols()) |j| {
                    for (pivot..npivot) |i| {
                        if (!self.lhs[i][j].iszero()) {
                            try self.swapCols(pivot, j);
                            try self.swapRows(pivot, i);
                            found = true;
                            break :outer;
                        }
                    }
                }

                if (!found) {
                    // If there are no non-zero pivots and RHS is zero
                    // -> no solution
                    for (pivot..npivot) |i| {
                        if (!self.rhs[i].iszero()) {
                            self.print();
                            return error.NoSolution;
                        }
                    }

                    // We can safely ignore the rest of the system.
                    // TODO: REMOVE THIS
                    while (self.nrows() > pivot) {
                        try self.removeRow(self.nrows() - 1);
                    }
                    break;
                }

                // Normalize pivot row
                {
                    const factor = self.lhs[pivot][pivot];

                    for (0..self.ncols()) |j| {
                        const val = self.lhs[pivot][j];
                        if (val.equals(0)) {
                            continue;
                        }
                        self.lhs[pivot][j] = try val.div(factor);
                    }
                    // Also normalize the RHS
                    self.rhs[pivot] = try self.rhs[pivot].div(factor);
                }

                // Eliminate entries in this column from other rows by
                // removing this row from other rows as needed.
                for (0..self.nrows()) |rowIdx| {
                    if (rowIdx == pivot or self.lhs[rowIdx][pivot].equals(0)) {
                        continue;
                    }

                    const remove_factor = try self.lhs[rowIdx][pivot].mul(-1);

                    // Eliminate this entry by subtracting the pivot row
                    try self.addRows(rowIdx, pivot, remove_factor);
                }
            }

            // Finally, remove empty rows
            while (self.nrows() > self.ncols()) {
                try self.removeRow(self.nrows() - 1);
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
        var les = LinEqSolver(i16).init(&eq);

        const vals = try std.testing.allocator.alloc(i16, eq.ncols());
        defer std.testing.allocator.free(vals);
        const cost = try les.minimizeCost(vals, GetCostFn(i16));
        std.debug.print("Cost for eq {d}: {d}\n", .{ k, cost });
    }
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

fn LinEqSolver(comptime T: type) type {
    return struct {
        const Self = @This();

        eq: *EquationSystem(T),

        pub fn init(eq: *EquationSystem(T)) Self {
            return Self{ .eq = eq };
        }

        pub fn solve(self: *Self, values: []T) !void {
            const n = self.eq.ncols();
            const m = self.eq.nrows();

            // Starting with the bottom row and moving up, we should be able to derive each value
            // but first, we memset zeroes for the start
            @memset(values[0..m], 0);
            for (0..m) |_i| {
                const i = m - _i - 1; // please zig, why can't we go from high to low in for loops?

                // Figure out rhs
                var val = self.eq.rhs[i];
                for (m..n) |j| {
                    const colval = try self.eq.lhs[i][j].mul(values[j]);
                    val = try val.sub(colval);
                }

                // Check result
                if (!val.isInteger()) {
                    return error.HasFraction;
                }

                // Parse as int and check that it's positive.
                const x = try val.asInt(T);
                if (x < 0) {
                    // Can't have a negative weight.
                    return error.OutOfBounds;
                }

                // Add to list of values
                values[i] = x;
            }
        }

        pub fn minimizeCost(self: *Self, result: []T, costFn: fn ([]T) T) !T {
            const n = self.eq.ncols();
            const m = self.eq.nrows();

            var upperbound: T = 0;
            for (0..m) |i| {
                upperbound = @max(upperbound, self.eq.rhs[i].toCeil() + 1);
            }

            // To solve this linear equation system, we start with converting the systems
            // to reduced row echelon form.
            try self.eq.rref();

            // self.eq.print();

            // Now that we have the reduced equation system, we can brute-force through
            // alternatives.
            const nfree = n - m;

            if (nfree > 0) {
                @memset(result[m..], 0);
                result[m] = upperbound;
            }

            var minCost: T = std.math.maxInt(T);

            // Iterate over all combinations
            for (0..std.math.pow(u64, @intCast(upperbound), @intCast(nfree))) |_x| {
                var x = _x;
                @memset(result[m..], 0);
                for (0..nfree) |k| {
                    const val = @mod(x, @as(u64, @intCast(upperbound)));
                    result[m + k] = @intCast(val);
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
