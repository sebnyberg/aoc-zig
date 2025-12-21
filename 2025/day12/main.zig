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

// Bitmask representation: u4096 = 64x64 grid
const BitMask = u4096;
const GRID_WIDTH = 64;

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
        area: usize, // Number of cells covered by this present (# cells)
        pattern_masks: []BitMask, // Bitmask for each pattern at position (0,0)

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
            var area: usize = 0;
            for (s, 0..) |r, i| {
                if (r.len != 3) return error.ParseError;
                for (r, 0..) |ch, j| {
                    pat[i][j] = switch (ch) {
                        '#' => blk: {
                            area += 1;
                            break :blk 1;
                        },
                        '.' => 0,
                        else => unreachable,
                    };
                }
            }

            const patterns = try Self._findPatterns(alloc, pat);

            // Create bitmasks for each pattern at position (0,0) in a 64x64 grid
            var pattern_masks = try alloc.alloc(BitMask, patterns.len);
            for (patterns, 0..) |pattern, idx| {
                var mask: BitMask = 0;
                for (0..3) |i| {
                    for (0..3) |j| {
                        if (pattern[i][j] != 0) {
                            const bit_pos = i * GRID_WIDTH + j;
                            mask |= @as(BitMask, 1) << @intCast(bit_pos);
                        }
                    }
                }
                pattern_masks[idx] = mask;
            }

            return Self{
                .alloc = alloc,
                .patterns = patterns,
                .area = area,
                .pattern_masks = pattern_masks,
            };
        }

        fn deinit(self: *Self) void {
            self.alloc.free(self.patterns);
            self.alloc.free(self.pattern_masks);
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
        state: BitMask,
        available_area: usize, // Track available empty cells

        const Self = @This();
        const done = [_]u8{0} ** 6;

        fn init(board: Board, presents: []Present(T)) Self {
            // Initialize state with 1s in all out-of-bounds positions
            var state: BitMask = 0;
            for (0..GRID_WIDTH) |i| {
                for (0..GRID_WIDTH) |j| {
                    // Mark out-of-bounds cells as occupied
                    if (i >= board.n or j >= board.m) {
                        const bit_pos: u12 = @intCast(i * GRID_WIDTH + j);
                        state |= @as(BitMask, 1) << bit_pos;
                    }
                }
            }

            return Self{
                .presents = presents,
                .npresents = board.npresents,
                .n = board.n,
                .m = board.m,
                .state = state,
                .available_area = board.n * board.m,
            };
        }

        /// Calculate how many cells are needed for remaining presents
        fn getRemainingArea(self: *const Self, rem: [6]u8) usize {
            var area: usize = 0;
            for (0..6) |i| {
                area += @as(usize, rem[i]) * self.presents[i].area;
            }
            return area;
        }

        /// placePresents recursively places presents (their patterns) in the state, returning
        /// short-circuiting "true" when a solution is found.
        /// This uses a present-based DFS with bitmask operations for fast collision detection.
        fn placePresents(self: *Self, rem: [6]u8) bool {
            // Base case: all presents placed
            if (std.mem.eql(u8, &rem, &done)) {
                return true;
            }

            // Early pruning: if we need more area than available, impossible
            const needed_area = self.getRemainingArea(rem);
            if (needed_area > self.available_area) {
                return false;
            }

            // Find the next present type that still needs placing
            var next_present: ?usize = null;
            for (0..6) |i| {
                if (rem[i] > 0) {
                    next_present = i;
                    break;
                }
            }

            if (next_present == null) {
                return false;
            }

            const present_idx = next_present.?;
            const present = self.presents[present_idx];

            // Try placing this present at every valid position on the board
            for (0..self.n) |i| {
                for (0..self.m) |j| {
                    // Check bounds for 3x3 pattern
                    if (i + 3 > self.n or j + 3 > self.m) continue;

                    // Try all pattern variations (rotations/flips)
                    for (present.pattern_masks, 0..) |pattern_mask, mask_idx| {
                        _ = mask_idx;
                        // Shift the pattern to position (i, j)
                        const shift_amount: u12 = @intCast(i * GRID_WIDTH + j);
                        const shifted_mask = pattern_mask << shift_amount;

                        // Check for collision using bitwise AND
                        if ((self.state & shifted_mask) != 0) continue;

                        // Place the pattern using bitwise OR
                        self.state |= shifted_mask;
                        self.available_area -= present.area;

                        // Update remaining count
                        var new_rem = rem;
                        new_rem[present_idx] -= 1;

                        // Recurse
                        if (self.placePresents(new_rem)) {
                            return true;
                        }

                        // Backtrack: remove the pattern using bitwise XOR and restore available area
                        self.state ^= shifted_mask;
                        self.available_area += present.area;
                    }
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

        if (solver.placePresents(board.npresents)) {
            print("Found a solution!\n", .{});
            res += 1;
        } else {
            print("No solution found.\n", .{});
        }
    }
    return res;
}

pub fn main() !void {
    const filepath = "input";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    print("Result1: {d}\n", .{try solve1(CellType, gpa, contents)});
}
