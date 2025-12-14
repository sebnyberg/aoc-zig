const std = @import("std");
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
var gpa = gpa_impl.allocator();

const Range = struct {
    start: u64,
    end: u64,
};

fn solve1(ranges: ArrayList(Range), ingredients: ArrayList(u64)) !u64 {
    var count: u64 = 0;
    for (ingredients.items) |x| {
        for (ranges.items) |r| {
            if (x >= r.start and x <= r.end) {
                count += 1;
                break;
            }
        }
    }
    return count;
}

fn solve2(ranges: ArrayList(Range)) !u64 {
    // The idea is to introduce a list of "changes" which contain the
    // index of a change and the change (entered a range = +1, leave = -1).
    //
    // Then we can iterate through these changes to calculate unique
    // ids.

    const Change = struct {
        idx: u64,
        change: i2,

        pub fn lessThan(_: void, lhs: @This(), rhs: @This()) bool {
            if (lhs.idx != rhs.idx) {
                return lhs.idx < rhs.idx;
            }
            return lhs.change > rhs.change;
        }
    };

    var changes = try ArrayList(Change).initCapacity(gpa, 2 * ranges.items.len);
    defer changes.deinit(gpa);

    for (ranges.items) |r| {
        try changes.append(gpa, .{ .idx = r.start, .change = 1 });
        try changes.append(gpa, .{ .idx = r.end, .change = -1 });
    }

    var activeRanges: i16 = 0;
    std.sort.heap(Change, changes.items, {}, Change.lessThan);

    var j: u64 = 0;
    var res: u64 = 0;
    for (changes.items) |change| {
        activeRanges += change.change;
        if (change.change == 1 and activeRanges == 1) {
            j = change.idx;
        } else if (activeRanges == 0) {
            res += change.idx - j + 1;
        }
    }

    return res;
}

pub fn main() !void {
    // const res = 1;
    const filename = "input";
    const contents = try std.fs.cwd().readFileAlloc(gpa, filename, 4 << 20);
    var lines = std.mem.splitScalar(u8, contents, '\n');

    // Parse ranges
    var ranges = try ArrayList(Range).initCapacity(gpa, 0);
    defer ranges.deinit(gpa);

    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "")) {
            break;
        }
        var fields = std.mem.splitScalar(u8, line, '-');
        const start = try parseInt(u64, fields.next().?, 10);
        const end = try parseInt(u64, fields.next().?, 10);
        try ranges.append(gpa, .{ .start = start, .end = end });
    }

    // Parse ingredients
    var ingredients = try ArrayList(u64).initCapacity(gpa, 0);
    defer ingredients.deinit(gpa);

    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, "")) {
            break;
        }
        try ingredients.append(gpa, try parseInt(u64, line, 10));
    }

    // Solve
    print("Result1: {d}\n", .{try solve1(ranges, ingredients)});
    print("Result2: {d}\n", .{try solve2(ranges)});
}
