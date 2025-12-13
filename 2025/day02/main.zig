const std = @import("std");
const cwd = std.fs.cwd;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const expect = std.testing.expect;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_impl.allocator();

const Interval = struct { from: u64, to: u64 };

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MiB

fn split(line: []const u8, token: u8) std.mem.TokenIterator(u8, .scalar) {
    return std.mem.tokenizeScalar(u8, line, token);
}

fn getContents(path: []const u8) ![]u8 {
    return try cwd().readFileAlloc(gpa, path, MAX_FILE_SIZE);
}

fn itoa(x: anytype) ![]const u8 {
    return std.fmt.allocPrint(gpa, "{d}", .{x});
}

fn atoi(comptime T: type, s: []const u8) !T {
    return try std.fmt.parseInt(T, s, 10);
}

test "check" {
    var intervals = try ArrayList(Interval).initCapacity(gpa, 1);
    try intervals.append(gpa, Interval{ .from = 11, .to = 22 });
    try expect(try check(22, intervals) == 1);
    try expect(try check(11, intervals) == 1);
    try expect(try check(33, intervals) == 0);
}

fn check(pat: []const u8, intervals: ArrayList(Interval)) !u64 {
    const x = try atoi(u64, pat);
    var res: u64 = 0;
    for (intervals.items) |interval| {
        const from = interval.from;
        const to = interval.to;
        if (x >= from and x <= to) {
            // print("{s} is between {d} and {d}\n", .{ pat, from, to });
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
    var intervals = try ArrayList(Interval).initCapacity(0);
    defer intervals.deinit();

    var lines = split(contents, '\n');
    var fields = split(lines.next().?, ',');
    var maxLen: u64 = 0;

    while (fields.next()) |field| {
        var parts = split(field, '-');
        const fromStr = parts.next().?;
        const toStr = parts.next().?;
        const ival = Interval{ .from = try atoi(u64, fromStr), .to = try atoi(u64, toStr) };
        try intervals.append(gpa, ival);
        maxLen = @max(maxLen, fromStr.len, toStr.len);
    }

    var buf: [1024]u8 = undefined;
    var res: u64 = 0;
    const endNum = std.math.pow(u64, 10, (maxLen / 2));

    // For each number
    for (1..endNum) |x| {

        // Check if the pattern exists in any interval
        const pat = try std.fmt.bufPrint(&buf, "{d}{d}", .{ x, x });
        res += try check(pat, intervals);
    }

    return res;
}

pub fn solve2(contents: []const u8) !u64 {
    var intervals = try ArrayList(Interval).initCapacity(0);
    defer intervals.deinit();

    var lines = split(contents, '\n');
    var fields = split(lines.next().?, ',');
    var maxLen: u64 = 0;

    while (fields.next()) |field| {
        var parts = split(field, '-');
        const fromStr = parts.next().?;
        const toStr = parts.next().?;
        const ival = Interval{ .from = try atoi(u64, fromStr), .to = try atoi(u64, toStr) };
        try intervals.append(gpa, ival);
        maxLen = @max(maxLen, fromStr.len, toStr.len);
    }

    var buf: [1024]u8 = undefined;
    var res: u64 = 0;
    const endNum = std.math.pow(u64, 10, (maxLen / 2));

    var map = std.AutoHashMap(u64, bool).init(gpa);
    defer map.deinit();

    // For each number
    for (1..endNum) |x| {

        // Initialize pattern
        const pat = try std.fmt.bufPrint(&buf, "{d}", .{x});
        var repeated = buf[0..pat.len];

        // Keep copying pattern and try matching until the pattern is too large.
        while (repeated.len + pat.len <= maxLen) {
            repeated = buf[0 .. repeated.len + pat.len];
            std.mem.copyForwards(u8, repeated[repeated.len - pat.len .. repeated.len], pat);
            const val = try atoi(u64, repeated);
            if (map.contains(val)) {
                // Already processed this number before
                continue;
            }
            try map.put(val, true);

            // expand size of repeated to twice the size + copy pat
            res += try check(repeated, intervals);
        }
    }

    return res;
}

pub fn main() !void {
    const contents = try getContents("input");
    const result1 = try solve1(contents);
    const result2 = try solve2(contents);
    print("Day 1: {d}\n", .{result1});
    print("Day 2: {d}\n", .{result2});
}
