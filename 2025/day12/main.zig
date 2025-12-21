const std = @import("std");

const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const cwd = std.fs.cwd;
const splitScalar = std.mem.splitScalar;
const tokenizeScalar = std.mem.tokenizeScalar;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const eql = std.mem.eql;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
var gpa = gpa_impl.allocator();

const SolveError = error{
    ParseError,
};

const Board = struct {
    m: usize,
    n: usize,
    npresents: [6]u8,
    alloc: std.mem.Allocator,

    const Self = @This();

    fn parse(alloc: std.mem.Allocator, s: []const u8) !Self {
        var fields = std.mem.tokenizeScalar(u8, s, ' ');

        // Parse hi/lo
        var dims = std.mem.tokenizeScalar(u8, fields.next().?, 'x');
        const m_s = dims.next().?;
        const m = try std.fmt.parseInt(usize, m_s, 10);
        var n_s = dims.next().?;
        n_s = n_s[0 .. n_s.len - 1];
        const n = try std.fmt.parseInt(usize, n_s, 10);

        // Parse indices
        var npresents: [6]u8 = undefined;
        var k: usize = 0;
        while (fields.next()) |field| : (k += 1) {
            npresents[k] = try std.fmt.parseInt(u8, field, 10);
        }

        return Self{
            .alloc = alloc,
            .m = m,
            .n = n,
            .npresents = npresents,
        };
    }

    fn deinit(self: *Self) void {
        _ = self;
        // npresents is a fixed array, not allocated memory
    }
};

fn Present(comptime T: type) type {
    return struct {
        patterns: [][3][3]T,
        alloc: std.mem.Allocator,

        const Self = @This();

        fn flipHorizontal(a: [3][3]T) [3][3]T {
            var result = a;
            for (0..3) |i| {
                const temp = result[i][0];
                result[i][0] = result[i][2];
                result[i][2] = temp;
            }
            return result;
        }
        fn flipVertical(a: [3][3]T) [3][3]T {
            var result = a;
            for (0..3) |i| {
                const temp = result[0][i];
                result[0][i] = result[2][i];
                result[2][i] = temp;
            }
            return result;
        }
        fn rotate(a: [3][3]T) [3][3]T {
            var result: [3][3]T = undefined;
            for (0..3) |i| {
                for (0..3) |j| {
                    result[i][j] = a[2 - j][i];
                }
            }
            return result;
        }

        fn _findPatterns(alloc: std.mem.Allocator, pat: [3][3]T) ![][3][3]T {
            var res = ArrayList([3][3]T){};
            try res.append(alloc, pat);

            // There are 4*2*2 possible states, so we should be able to iterate
            // over a variable and determine the final state based on modulo.
            for (0..4 * 2 * 2) |k| {
                var cpy = pat;
                if ((k % 2) == 1) {
                    cpy = Self.flipHorizontal(cpy);
                }
                if ((k >> 1) % 2 == 1) {
                    cpy = Self.flipVertical(cpy);
                }
                for (0..(k >> 2)) |_| {
                    cpy = Self.rotate(cpy);
                }
                if (_isNewPattern(res.items, cpy)) |p| {
                    try res.append(alloc, p);
                }
            }

            return res.toOwnedSlice(alloc);
        }

        fn _isNewPattern(patterns: [][3][3]T, pat: [3][3]T) ?[3][3]T {
            for (patterns) |p| {
                var equal = true;
                for (0..3) |i| {
                    if (!std.mem.eql(T, &p[i], &pat[i])) {
                        equal = false;
                        break;
                    }
                }
                if (equal) {
                    return null;
                }
            }
            return pat;
        }

        fn parse(alloc: std.mem.Allocator, s: [][]const u8) !Self {
            if (s.len != 3) return error.ParseError;
            var pat: [3][3]T = undefined;
            for (s, 0..) |r, i| {
                if (r.len != 3) return error.ParseError;
                for (r, 0..) |ch, j| {
                    pat[i][j] = switch (ch) {
                        '#' => 1,
                        '.' => 0,
                        else => unreachable,
                    };
                }
            }
            return Self{
                .alloc = alloc,
                .patterns = try Self._findPatterns(alloc, pat),
            };
        }

        fn deinit(self: *Self) void {
            self.alloc.free(self.patterns);
        }
    };
}

fn Problem(comptime CellT: type) type {
    return struct {
        alloc: std.mem.Allocator,
        presents: [6]Present(CellT),
        boards: []Board,

        const Self = @This();

        fn parse(alloc: std.mem.Allocator, s: []const u8) !Self {
            var lines = std.mem.tokenizeScalar(u8, s, '\n');

            var presents: [6]Present(CellT) = undefined;

            var boards_list = std.ArrayList(Board){};
            defer boards_list.deinit(alloc);

            var pat_lines: [3][]const u8 = undefined;

            var npresent: usize = 0;
            var nboard: usize = 0;

            while (lines.next()) |line| {
                if (std.mem.eql(u8, line, "")) {
                    continue;
                }
                if (line.len <= 3) {
                    pat_lines[0] = lines.next().?;
                    pat_lines[1] = lines.next().?;
                    pat_lines[2] = lines.next().?;
                    presents[npresent] = try Present(CellT).parse(alloc, &pat_lines);
                    npresent += 1;
                }
                if (line.len > 3) {
                    try boards_list.append(
                        alloc,
                        try Board.parse(alloc, line),
                    );
                    nboard += 1;
                }
            }

            return Self{
                .alloc = alloc,
                .presents = presents,
                .boards = try boards_list.toOwnedSlice(alloc),
            };
        }

        fn deinit(self: *Self) void {
            for (self.boards, 0..) |_, i| {
                self.boards[i].deinit();
            }
            for (self.presents, 0..) |_, i| {
                self.presents[i].deinit();
            }
            self.alloc.free(self.boards);
            // presents is a fixed array, not allocated memory
        }
    };
}

fn Solver(comptime T: type) type {
    return struct {
        presents: []Present(T),
        npresents: [6]u8,
        n: usize,
        m: usize,
        state: [128][128]T,

        const Self = @This();
        const done = [_]u8{0} ** 6;

        fn init(board: Board, presents: []Present(T)) Self {
            // Let's try naive dfs first.
            var state: [128][128]T = undefined;
            for (&state) |*row| {
                @memset(row, 0);
            }
            return Self{
                .presents = presents,
                .npresents = board.npresents,
                .n = board.n,
                .m = board.m,
                .state = state,
            };
        }

        /// addDelta adds d * pat to the state at the top-left corner of (i,j).
        /// The caller must verify that this is a legal operation.
        inline fn addDelta(state: *[128][128]T, pat: [3][3]T, i: usize, j: usize, d: T) void {
            for (0..3) |di| {
                for (0..3) |dj| {
                    state[i + di][j + dj] +%= d *% pat[di][dj];
                }
            }
        }

        inline fn canPlacePattern(state: *[128][128]T, pat: [3][3]T, i: usize, j: usize) bool {
            for (0..3) |di| {
                for (0..3) |dj| {
                    if (pat[di][dj] != 0 and state[i + di][j + dj] != 0) {
                        return false;
                    }
                }
            }
            return true;
        }

        /// placePresents recursively places presents (their patterns) in the state, returning /
        /// short-circuiting "true" when a solution is found.
        fn placePresents(self: *Self, rem: [6]u8, start_i: usize, start_j: usize) bool {
            if (std.mem.eql(u8, &rem, &done)) {
                return true;
            }

            // OPTIMIZATION: Find the first empty cell instead of trying every position
            // This removes the exponential "skip" branch at each cell
            // To revert: restore the old version that tries skip first, then placement
            var i: usize = start_i;
            var j: usize = start_j;

            // Normalize starting position
            if (i >= self.n) {
                i = 0;
                j += 1;
            }

            // Find first empty cell starting from (i, j)
            var found_empty = false;
            while (j < self.m) {
                while (i < self.n) {
                    if (self.state[i][j] == 0) {
                        found_empty = true;
                        break;
                    }
                    i += 1;
                }
                if (found_empty) break;
                i = 0;
                j += 1;
            }

            // If no empty cells but presents remain, no solution
            if (!found_empty) {
                return false;
            }

            // OPTIMIZATION: Must place something at this empty cell (no skip option)
            // Try placing each present pattern at (i, j)
            for (0..6) |present_idx| {
                if (rem[present_idx] == 0) continue;

                const present = self.presents[present_idx];
                for (present.patterns) |pattern| {
                    // Check bounds
                    if (i + 3 > self.n or j + 3 > self.m) continue;

                    // Check if we can place this pattern
                    if (!Self.canPlacePattern(&self.state, pattern, i, j)) continue;

                    // Place the pattern
                    Self.addDelta(&self.state, pattern, i, j, 1);

                    // Update remaining count
                    var new_rem = rem;
                    new_rem[present_idx] -= 1;

                    // Recurse to next position
                    if (self.placePresents(new_rem, i + 1, j)) {
                        return true;
                    }

                    // Unplace the pattern (subtract 1, which is add 3 in u2 arithmetic)
                    Self.addDelta(&self.state, pattern, i, j, 3);
                }
            }

            return false;
        }
    };
}

pub fn printGrid(comptime T: type, grid: []const []const T) void {
    for (grid) |row| {
        for (row) |cell| {
            if (cell != 0) {
                print("#", .{});
            } else {
                print(".", .{});
            }
        }
        print("\n", .{});
    }
    print("\n", .{});
}

pub fn printGrid3x3(comptime T: type, grid: [3][3]T) void {
    var rows: [3][]const T = undefined;
    for (0..3) |i| {
        rows[i] = &grid[i];
    }
    printGrid(T, &rows);
}

const CellType = u2;

pub fn solve1(
    comptime T: type,
    alloc: std.mem.Allocator,
    contents: []const u8,
) !usize {
    _ = alloc;
    var p = try Problem(T).parse(gpa, contents);
    defer p.deinit();

    // Try DFS on the first board
    var res: usize = 0;
    for (p.boards) |board| {
        var solver = Solver(T).init(board, &p.presents);

        print("Attempting to solve board: {}x{} with presents: {any}\n", .{ board.n, board.m, board.npresents });

        if (solver.placePresents(board.npresents, 0, 0)) {
            print("Found a solution!\n", .{});
            res += 1;
        } else {
            print("No solution found.\n", .{});
        }
    }
    return res;
}

// fn dfs(
//     comptime T: type,
//     npresents: []usize,
//     presents: []Present(T),
//     state: *[100][100]T,
//     i: usize,
//     j: usize,
//     m: usize,
//     n: usize,
// ) bool {
//     _ = npresents;
//     _ = state;
//     _ = i;
//     _ = j;
//     _ = m;
//     _ = n;
//     _ = presents;
//     // Place any
//     return true;
// }

pub fn main() !void {
    const filepath = "testinput";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    print("Result1: {d}\n", .{try solve1(CellType, gpa, contents)});
}
