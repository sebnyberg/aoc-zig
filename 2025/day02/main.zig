const std = @import("std");
const cwd = std.fs.cwd;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const expect = std.testing.expect;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_impl.allocator();

const Interval = struct {
    from: []const u8,
    to: []const u8,
};

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MiB

fn split(line: []const u8, token: u8) std.mem.TokenIterator(u8, .scalar) {
    return std.mem.tokenizeScalar(u8, line, token);
}

fn getContents(path: []const u8) ![]u8 {
    return try cwd().readFileAlloc(gpa, path, MAX_FILE_SIZE);
}

fn newList(comptime T: type, capacity: usize) !std.ArrayList(T) {
    return std.ArrayList(T).initCapacity(gpa, capacity);
}

fn itoa(x: anytype) ![]const u8 {
    return std.fmt.allocPrint(gpa, "{d}", .{x});
}

fn atoi(comptime T: type, s: []const u8) !T {
    return try std.fmt.parseInt(T, s, 10);
}

test "check" {
    var intervals = try ArrayList(Interval).initCapacity(gpa, 1);
    try intervals.append(gpa, Interval{ .from = "11", .to = "22" });
    try expect(try check("22", intervals) == 1);
    try expect(try check("11", intervals) == 1);
    try expect(try check("33", intervals) == 0);
}

fn check(pat: []const u8, intervals: ArrayList(Interval)) !u64 {
    const x = try atoi(u64, pat);
    var res: u64 = 0;
    for (intervals.items) |interval| {
        const from = try atoi(u64, interval.from);
        const to = try atoi(u64, interval.to);
        if (x >= from and x <= to) {
            print("{s} is between {d} and {d}\n", .{ pat, from, to });
            res += x;
            return res;
        }
    }
    return res;
}

pub fn solve1(contents: []const u8) !u64 {
    // Instead of iterating through ranges, we can iterate through numbers
    // that have repeated symbols in them. We basically need to iterate from
    // 1 to 10^(maxLen(numbers)/2 + 1)-1 to cover all possibilities.
    //
    var intervals = try newList(Interval, 0);

    var lines = split(contents, '\n');
    var fields = split(lines.next().?, ',');
    var maxLen: u64 = 0;

    while (fields.next()) |field| {
        var parts = split(field, '-');
        const ival = Interval{
            .from = parts.next().?,
            .to = parts.next().?,
        };
        try intervals.append(gpa, ival);
        maxLen = @max(maxLen, ival.from.len, ival.to.len);
    }

    // for (intervals.items) |interval| {
    //     print("start: {s}, end: {s}\n", .{ interval.from, interval.to });
    // }
    const endNum = std.math.pow(u64, 10, maxLen / 2 + 1) - 1;

    var buf: [1024]u8 = undefined;
    var res: u64 = 0;

    // For each number
    for (1..endNum) |x| {
        // Repeat it until it is larger than the largest number from the intervals
        var repeated = try std.fmt.bufPrint(&buf, "{d}", .{x});
        while (repeated.len * 2 <= maxLen) {
            repeated = buf[0 .. repeated.len * 2];
            std.mem.copyForwards(u8, repeated[repeated.len / 2 .. repeated.len], repeated[0 .. repeated.len / 2]);

            // expand size of repeated to twice the size + copy pat
            res += try check(repeated, intervals);
        }
    }

    return res;
}

pub fn main() !void {
    const contents = try getContents("input");
    const result1 = try solve1(contents);
    print("Day 1: {d}\n", .{result1});
}
