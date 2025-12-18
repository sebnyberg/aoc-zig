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
            const lhs = try alloc.alloc([]u8, neqs);
            for (lhs, 0..) |_, i| {
                lhs[i] = try alloc.alloc(u8, nvars);
                @memset(lhs[i], 0);
            }
            const rhs = try alloc.alloc(u8, neqs);
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

// test "LinEqSolver.swapRows() out of bounds" {
//     var eq = try EquationSystem(u8).init(std.testing.allocator, 10, 10);
//     defer eq.deinit();
//
//     try std.testing.expectError(error.OutOfBounds, eq.swapRows(0, 11));
// }

test "LinEqSolver.init() invalid dimensions" {
    // Constants
    const neqs = 8;
    const nvars = 10;
    const maxSize = 20;

    var eq = try EquationSystem(u8).init(std.testing.allocator, neqs, nvars);
    defer eq.deinit();

    var les = try LinEqSolver(u8, maxSize).init(
        std.testing.allocator,
        eq.lhs,
        eq.rhs,
    );
    defer les.deinit();
}

const SolverError = error{
    InvalidDimensions,
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

        fn deinit(self: *Self) void {
            self.alloc.free(self.eqs);
        }
    };
}
