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

fn solve1(lines: *std.mem.TokenIterator(u8, .scalar), lastLine: []const u8, n: u64) !u64 {
    defer lines.reset();

    // Capture accumulators for each op
    const Accumulator = struct {
        op: enum { mul, add },
        result: u64 = 0,
        pub fn apply(self: *@This(), x: u64) void {
            if (self.result == 0) {
                self.result = x;
                return;
            }
            self.result = switch (self.op) {
                .mul => self.result * x,
                .add => self.result + x,
            };
        }
    };
    var fields = tokenizeScalar(u8, lastLine, ' ');
    var ops = try ArrayList(Accumulator).initCapacity(gpa, 10);
    while (fields.next()) |field| {
        try ops.append(gpa, switch (field[0]) {
            '*' => .{ .op = .mul },
            '+' => .{ .op = .add },
            else => unreachable,
        });
    }

    // Iterate through the lines, accumulating the result
    for (0..n - 1) |_| {
        const l = lines.next().?;
        fields = tokenizeScalar(u8, l, ' ');
        var i: u64 = 0;
        while (fields.next()) |field| : (i += 1) {
            const x = try parseInt(u64, field, 10);
            ops.items[i].apply(x);
        }
    }

    var result: u64 = 0;
    for (ops.items) |accum| {
        result += accum.result;
    }

    return result;
}

fn solve2(lines: *std.mem.TokenIterator(u8, .scalar), lastLine: []const u8, n: u64) !u64 {
    // This is a bit annoying, basically we need to have a list of numbers for each
    // column, and add the parts of each new number to the list of previous numbers.
    //
    // We can save ourselves some work if we just assume that there will be less than
    // 64 digits per number (which we know is true).
    defer lines.reset();

    // parse operators
    var opsBuf: [1024]enum { mul, add } = undefined;
    var m: u64 = 0;
    var opFields = tokenizeScalar(u8, lastLine, ' ');
    {
        var i: u64 = 0;
        while (opFields.next()) |op| {
            switch (op[0]) {
                '*' => opsBuf[i] = .mul,
                '+' => opsBuf[i] = .add,
                else => unreachable,
            }
            i += 1;
        }
        m = i;
    }
    const ops = opsBuf[0..m];

    var cols: [4096]u64 = undefined;
    @memset(&cols, 0);

    for (0..n - 1) |_| {
        const line = lines.next().?;
        var i: u64 = 0;
        for (line) |c| {
            if (c != ' ') {
                cols[i] = cols[i] * 10 + (c - '0');
            }
            i += 1;
        }
    }

    var resBuf: [1024]u64 = undefined;
    var res = resBuf[0..m];
    @memset(res, 0);

    var i: u64 = 0;

    for (cols) |col| {
        // Move result cursor when col == 0
        if (col == 0) {
            i += 1;
            if (i == m) {
                break;
            }
            continue;
        }

        // Init res[i] when zero and mul
        if (res[i] == 0 and ops[i] == .mul) {
            res[i] = 1;
        }

        switch (ops[i]) {
            .mul => res[i] *= col,
            .add => res[i] += col,
        }
    }

    // collect results
    var total: u64 = 0;
    for (res) |x| {
        total += x;
    }

    return total;
}

pub fn main() !void {
    const filepath = "input";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    var lines = tokenizeScalar(u8, contents, '\n');

    // Find last line
    var lastLine: []const u8 = undefined;
    var n: u64 = 0;
    while (lines.next()) |line| {
        lastLine = line;
        n += 1;
    }
    lines.reset();

    print("Result1: {d}\n", .{try solve1(&lines, lastLine, n)});
    print("Result2: {d}\n", .{try solve2(&lines, lastLine, n)});
}
