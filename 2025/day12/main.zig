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

const ChristmasTree = struct {
    lo: usize,
    hi: usize,
    indices: []usize,
    alloc: std.mem.Allocator,

    const Self = @This();

    fn parse(alloc: std.mem.Allocator, s: []const u8) !Self {
        var fields = std.mem.tokenizeScalar(u8, s, ' ');

        // Parse hi/lo
        var dims = std.mem.tokenizeScalar(u8, fields.next().?, 'x');
        const lo_s = dims.next().?;
        const lo = try std.fmt.parseInt(usize, lo_s, 10);
        var hi_s = dims.next().?;
        hi_s = hi_s[0 .. hi_s.len - 1];
        const hi = try std.fmt.parseInt(usize, hi_s, 10);

        // Parse indices
        var indices_al = std.ArrayList(usize){};
        while (fields.next()) |field| {
            try indices_al.append(alloc, try std.fmt.parseInt(usize, field, 10));
        }
        const indices = try indices_al.toOwnedSlice(alloc);

        return Self{
            .alloc = alloc,
            .lo = lo,
            .hi = hi,
            .indices = indices,
        };
    }

    fn deinit(self: *Self) void {
        self.alloc.free(self.indices);
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
        presents: []Present(CellT),
        trees: []ChristmasTree,

        const Self = @This();

        fn parse(alloc: std.mem.Allocator, s: []const u8) !Self {
            var lines = std.mem.tokenizeScalar(u8, s, '\n');

            var presents_list = std.ArrayList(Present(CellT)){};
            defer presents_list.deinit(alloc);

            var trees_list = std.ArrayList(ChristmasTree){};
            defer trees_list.deinit(alloc);

            var pat_lines: [3][]const u8 = undefined;

            var npresent: usize = 0;
            var ntree: usize = 0;

            while (lines.next()) |line| {
                if (std.mem.eql(u8, line, "")) {
                    continue;
                }
                if (line.len <= 3) {
                    pat_lines[0] = lines.next().?;
                    pat_lines[1] = lines.next().?;
                    pat_lines[2] = lines.next().?;
                    try presents_list.append(
                        alloc,
                        try Present(CellT).parse(alloc, &pat_lines),
                    );
                    npresent += 1;
                }
                if (line.len > 3) {
                    try trees_list.append(
                        alloc,
                        try ChristmasTree.parse(alloc, line),
                    );
                    ntree += 1;
                }
            }

            return Self{
                .alloc = alloc,
                .presents = try presents_list.toOwnedSlice(alloc),
                .trees = try trees_list.toOwnedSlice(alloc),
            };
        }

        fn deinit(self: *Self) void {
            for (self.trees, 0..) |_, i| {
                self.trees[i].deinit();
            }
            for (self.presents, 0..) |_, i| {
                self.presents[i].deinit();
            }
            self.alloc.free(self.trees);
            self.alloc.free(self.presents);
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

pub fn solve1(
    comptime CellT: type,
    alloc: std.mem.Allocator,
    contents: []const u8,
) !usize {
    var p = try Problem(CellT).parse(alloc, contents);
    defer p.deinit();
    return 0;
}

pub fn main() !void {
    const filepath = "input";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    print("Result1: {d}\n", .{try solve1(u2, gpa, contents)});
}
