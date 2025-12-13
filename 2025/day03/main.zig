const std = @import("std");
const print = std.debug.print;
const t = std.testing;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_impl.allocator();

test "find biggest" {
    var buf: [2]u8 = undefined;
    const line = "811119";
    findBiggest(line, 2, &buf);
    try t.expectEqualStrings(
        "89",
        &buf,
    );
}

fn findBiggest(line: []const u8, res: []u8) void {
    const n = res.len;
    if (res.len == 0) {
        return;
    }
    if (line.len == n) {
        // copy remaining items to the result
        std.mem.copyForwards(u8, res, line);
        return;
    }
    // Find largest viable digit
    var largestIdx: u8 = 0;
    var i: u8 = 1;
    while (i <= line.len - n) : (i += 1) {
        if (line[i] > line[largestIdx]) {
            largestIdx = i;
        }
    }
    res[0] = line[largestIdx];
    findBiggest(line[largestIdx + 1 ..], res[1..]);
}

fn solve1(lines: *std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar)) !u32 {
    var res: u32 = 0;
    defer lines.reset();

    while (lines.next()) |line| {
        var buf: [2]u8 = undefined;
        findBiggest(line, &buf);
        res += (buf[0] - '0') * 10 + (buf[1] - '0');
    }

    return res;
}

fn solve2(lines: *std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar)) !u64 {
    var res: u64 = 0;
    defer lines.reset();

    while (lines.next()) |line| {
        var buf: [12]u8 = undefined;
        findBiggest(line, &buf);
        var subRes: u64 = 0;
        for (buf) |c| {
            subRes = subRes * 10 + (c - '0');
        }
        res += subRes;
    }

    return res;
}

pub fn main() !void {
    const contents = try std.fs.cwd().readFileAlloc(gpa, "./input", 1 << 20);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    std.debug.print("Result 1:\n{d}\n\n", .{try solve1(&lines)});
    std.debug.print("Result 2:\n{d}\n", .{try solve2(&lines)});
}
