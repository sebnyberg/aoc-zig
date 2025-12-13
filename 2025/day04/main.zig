const std = @import("std");
const print = std.debug.print;
const t = std.testing;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_impl.allocator();

fn parseGrid(filename: []const u8, grid: *[1024][1024]u8) !struct { m: u64, n: u64 } {
    // Parse grid
    const contents = try std.fs.cwd().readFileAlloc(gpa, filename, 4 << 20);
    defer gpa.free(contents);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var m: u64 = 0;
    var n: u64 = 0;
    while (lines.next()) |line| {
        std.mem.copyForwards(u8, grid[m + 1][1..], line);
        m += 1;
        n = line.len;
    }
    print("# lines: {d}\n", .{m});
    print("line length: {d}\n", .{n});
    return .{ .m = m, .n = n };
}

const dirs8 = [_][2]i8{ .{ -1, 1 }, .{ -1, 0 }, .{ -1, -1 }, .{ 0, -1 }, .{ 0, 1 }, .{ 1, -1 }, .{ 1, 0 }, .{ 1, 1 } };

fn solve1(grid: [1024][1024]u8, m: u64, n: u64) !u64 {
    var res: u64 = 0;

    for (1..m + 1) |i| {
        for (1..n + 1) |j| {
            var count: u8 = 0;
            if (grid[i][j] != '@') {
                continue;
            }
            for (dirs8) |dir| {
                const di = dir[0];
                const dj = dir[1];
                const ii: usize = @intCast(@as(i32, @intCast(i)) + di);
                const jj: usize = @intCast(@as(i32, @intCast(j)) + dj);
                if (grid[ii][jj] == '@') {
                    count += 1;
                }
            }
            if (count < 4) {
                res += 1;
            }
        }
    }

    return res;
}

fn removeRolls(grid: *[1024][1024]u8, m: u64, n: u64) !u64 {
    var res: u64 = 0;

    for (1..m + 1) |i| {
        for (1..n + 1) |j| {
            var count: u8 = 0;
            if (grid[i][j] != '@') {
                continue;
            }
            for (dirs8) |dir| {
                const di = dir[0];
                const dj = dir[1];
                const ii: usize = @intCast(@as(i32, @intCast(i)) + di);
                const jj: usize = @intCast(@as(i32, @intCast(j)) + dj);
                if (grid[ii][jj] == '@') {
                    count += 1;
                }
            }
            if (count < 4) {
                res += 1;
                grid[i][j] = '.';
            }
        }
    }

    return res;
}

fn solve2(grid: *[1024][1024]u8, m: u64, n: u64) !u64 {
    var res: u64 = 0;
    while (true) {
        const removed = try removeRolls(grid, m, n);
        res += removed;
        if (removed == 0) {
            break;
        }
    }
    return res;
}

pub fn main() !void {
    const filename = "input";
    var grid: [1024][1024]u8 = undefined;
    const dim = try parseGrid(filename, &grid);
    print("Result 1: {d}\n", .{try solve1(grid, dim.m, dim.n)});
    print("Result 2: {d}\n", .{try solve2(&grid, dim.m, dim.n)});
}
