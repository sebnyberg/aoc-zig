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

fn solve1(contents: []const u8) !u64 {
    var lines = tokenizeScalar(u8, contents, '\n');
    defer lines.reset();
    const firstLine = lines.next().?;
    const m = firstLine.len;
    var buf = [_]u8{0} ** 2048;
    var curr = buf[0..m];
    var prev = buf[m .. m * 2];
    @memcpy(curr, firstLine);
    for (firstLine, 0..) |c, i| {
        if (c == 'S') {
            curr[i] = '|';
        }
    }

    var res: u64 = 0;
    while (lines.next()) |line| {
        prev, curr = .{ curr, prev };

        for (line, 0..) |c, i| {
            if (prev[i] == '|') {
                if (c == '^') {
                    // split into two lasers
                    curr[i - 1] = '|';
                    curr[i + 1] = '|';
                    curr[i] = '.';
                    res += 1;
                } else {
                    curr[i] = '|';
                }
            }
        }
    }
    return res;
}

const maxu64: u64 = std.math.maxInt(u64);

fn solve2(contents: []const u8) !u64 {
    var lines = tokenizeScalar(u8, contents, '\n');
    const firstLine = lines.next().?;
    const n = firstLine.len;
    var m: u64 = 1;
    while (lines.next()) |_| {
        m += 1;
    }
    lines.reset();

    // Copy file contents as grid slice
    var gridBuf: [1024][1024]u8 = undefined;
    {
        var i: u64 = 0;
        while (lines.next()) |line| : (i += 1) {
            std.mem.copyForwards(u8, &gridBuf[i], line);
        }
    }

    // Find starting position
    var startJ: u64 = 0;
    for (0..n) |i| {
        if (gridBuf[0][i] == 'S') {
            startJ = i;
            break;
        }
    }
    const grid = gridBuf[1..m]; // remove top row
    m -= 1;

    // Ready to REEECUUURSEEE
    var mem: [1024][1024]u64 = undefined;
    for (0..mem.len) |i| {
        @memset(&mem[i], maxu64);
    }

    return dfs(&mem, grid, 0, startJ, m);
}

fn dfs(mem: *[1024][1024]u64, grid: [][1024]u8, i: u64, j: u64, m: u64) u64 {
    if (i == m) {
        return 1;
    }
    if (mem[i][j] != maxu64) {
        return mem[i][j];
    }
    var res: u64 = 0;
    if (grid[i][j] != '^') { // just continue...
        res += dfs(mem, grid, i + 1, j, m);
    } else {
        res += dfs(mem, grid, i + 1, j - 1, m);
        res += dfs(mem, grid, i + 1, j + 1, m);
    }

    mem[i][j] = res;
    return mem[i][j];
}

pub fn main() !void {
    const filepath = "input";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    defer gpa.free(contents);

    print("Result 1:\n{d}\n\n", .{try solve1(contents)});
    print("Result 2:\n{d}\n\n", .{try solve2(contents)});
}
