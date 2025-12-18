const std = @import("std");
const dateLogFn = @import("logger.zig").logFn;
const solver = @import("solver.zig");

pub const std_options: std.Options = .{
    .logFn = dateLogFn,
};

const log = std.log;
const parseInt = std.fmt.parseInt;
const cwd = std.fs.cwd;
const splitScalar = std.mem.splitScalar;
const tokenizeScalar = std.mem.tokenizeScalar;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const eql = std.mem.eql;

const RuntimeStarsAndBars = @import("stars_and_bars.zig").RuntimeStarsAndBars;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
var gpa = gpa_impl.allocator();

fn BoundedArray(comptime T: type, comptime cap: usize) type {
    return struct {
        buffer: [cap]T = undefined,
        len: usize = 0,
        const Self = @This();

        pub fn append(self: *Self, item: T) !void {
            if (self.len > cap) return error.Overflow;
            self.buffer[self.len] = item;
            self.len += 1;
        }

        pub fn slice(self: *Self) []T {
            return self.buffer[0..self.len];
        }
    };
}

const Machine = struct {
    want: u32,
    pushEffectBits: []const u32,
    pushEffects: [][]u16,
    power: []u16,
    w: u5,
    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, str: []const u8) !Self {
        var fields = std.mem.tokenizeScalar(u8, str, ' ');

        var pushEffectBits = try std.ArrayList(u32).initCapacity(allocator, 10);
        var pushEffects = try std.ArrayList([]u16).initCapacity(allocator, 10);
        var want: u16 = 0;
        var w: u5 = 0;
        var power: []u16 = undefined;

        defer {
            pushEffectBits.deinit(allocator);
            pushEffects.deinit(allocator);
        }

        while (fields.next()) |field| {
            switch (field[0]) {
                '[' => {
                    for (1..field.len - 1) |j| {
                        want <<= 1;
                        want += if (field[j] == '#') @as(u1, 1) else 0;
                    }
                    w = @as(u5, @intCast(field.len)) - 2;
                },
                '(' => {
                    var pushEffect: u32 = 0;
                    var nums = std.mem.tokenizeScalar(u8, field[1 .. field.len - 1], ',');
                    var indices = try std.ArrayList(u16).initCapacity(allocator, 10);
                    defer indices.deinit(allocator);
                    while (nums.next()) |num| {
                        const x = try std.fmt.parseInt(u5, num, 10);
                        pushEffect |= @as(u32, 1) << (w - x - 1);
                        try indices.append(allocator, x);
                    }
                    try pushEffectBits.append(allocator, pushEffect);
                    try pushEffects.append(allocator, try indices.toOwnedSlice(allocator));
                },
                '{' => {
                    power = try allocator.alloc(u16, w);
                    var nums = std.mem.tokenizeScalar(u8, field[1 .. field.len - 1], ',');
                    var i: u8 = 0;
                    while (nums.next()) |num| : (i += 1) {
                        const x = try std.fmt.parseInt(u16, num, 10);
                        power[i] = x;
                    }
                },
                else => unreachable,
            }
        }

        return Self{
            .want = want,
            .pushEffectBits = try pushEffectBits.toOwnedSlice(allocator),
            .pushEffects = try pushEffects.toOwnedSlice(allocator),
            .power = power,
            .w = w,
        };
    }

    pub fn printContents(self: Self) !void {
        // Convert bitmap to "wantstr"
        const wantStr = bmstr(u32, self.want, self.w)[0..self.w];
        log.info("[{s}]", .{wantStr});

        // Print toggles
        for (self.pushEffectBits) |toggle| {
            const s = bmstr(u32, toggle, self.w)[0..self.w];
            log.info("({s})", .{s});
        }

        // Print energy
        log.info("{any}", .{self.power});
        log.info("", .{});
    }
};

fn solve1(m: Machine) !u32 {
    // Starting with an empty bitset, apply toggles until reaching
    // the wanted state.
    var seen = try gpa.alloc(u1, @as(u64, 1) << m.w);
    for (seen, 0..) |_, i| {
        seen[i] = 0;
    }

    seen[0] = 1;
    var curr = try std.ArrayList(u32).initCapacity(gpa, 1);
    var next = try std.ArrayList(u32).initCapacity(gpa, 1);
    try curr.append(gpa, 0);
    var k: u32 = 1;
    while (curr.items.len > 0) : (k += 1) {
        next.clearRetainingCapacity();

        for (curr.items) |x| {
            for (m.pushEffectBits) |t| {
                const y = x ^ t;
                if (y == m.want) {
                    return k;
                }
                if (seen[y] == 1) {
                    continue;
                }
                seen[y] = 1;
                try next.append(gpa, y);
            }
        }

        const tmp = curr;
        curr = next;
        next = tmp;
    }
    unreachable;
}

const Solve2Result = struct {
    res: u64,
    maxPushGroupSize: u32,
    score: f64,
};

fn solve2(m: Machine, machineIdx: usize) Solve2Result {
    // Build equation system from machine:
    // - neqs = number of rows (m.w)
    // - nvars = number of buttons (m.pushEffects.len)
    // - lhs[row][button] = 1 if button affects row
    // - rhs[row] = power[row]
    const neqs = m.w;
    const nvars = m.pushEffects.len;

    var eq = solver.EquationSystem(i64).init(gpa, neqs, nvars) catch {
        log.err("Failed to initialize equation system", .{});
        return Solve2Result{ .res = 0, .maxPushGroupSize = 0, .score = 0 };
    };
    defer eq.deinit();

    // Fill in the coefficients
    for (m.pushEffects, 0..) |effects, button| {
        for (effects) |row| {
            eq.lhs[row][button] = 1;
        }
    }

    // Fill in the RHS
    for (0..neqs) |row| {
        eq.rhs[row] = m.power[row];
    }

    // Solve using LinEqSolver
    var les = solver.LinEqSolver(i64).init(gpa, &eq) catch {
        log.err("Failed to initialize LinEqSolver", .{});
        return Solve2Result{ .res = 0, .maxPushGroupSize = 0, .score = 0 };
    };
    defer les.deinit();

    const maybeSolution = les.solveMinSum(500) catch |err| {
        if (err == error.IntegerDivisionFailed) {
            log.err("IntegerDivisionFailed for machine {d}:", .{machineIdx});
            log.err("  neqs={d}, nvars={d}", .{ neqs, nvars });
            log.err("  Current equation state:", .{});
            eq.print();
            log.err("  col_order: {any}", .{les.col_order});
        } else {
            log.err("Solver error: {any}", .{err});
        }
        return Solve2Result{ .res = 0, .maxPushGroupSize = 0, .score = 0 };
    };

    if (maybeSolution) |solution| {
        defer gpa.free(solution);
        var sum: u64 = 0;
        var maxVal: u64 = 0;
        for (solution) |v| {
            sum += @intCast(v);
            maxVal = @max(maxVal, @as(u64, @intCast(v)));
        }
        return Solve2Result{
            .res = sum,
            .maxPushGroupSize = @intCast(maxVal),
            .score = @floatFromInt(sum),
        };
    } else {
        log.err("No solution found for machine", .{});
        return Solve2Result{ .res = 0, .maxPushGroupSize = 0, .score = 0 };
    }
}

pub fn bmstr(comptime T: type, bm: T, w: T) [@bitSizeOf(T)]u8 {
    var buf: [@bitSizeOf(T)]u8 = undefined;
    var cpy = bm;
    for (0..w) |i| {
        buf[w - 1 - i] = if (cpy & 1 == 1) '#' else '.';
        cpy >>= 1;
    }
    return buf;
}

pub fn main() !void {
    const filepath = "input";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var res1: u64 = 0;
    // var res2: u64 = 0;
    var maxScore: f64 = 0;
    var maxPushGroupSize: u32 = 0;
    var res2: u64 = 0;

    var n: usize = 0;
    while (lines.next()) |_| {
        n += 1;
    }
    lines.reset();

    var maxStates: f64 = 0;
    while (lines.next()) |line| {
        const m = try Machine.parse(gpa, line);
        var res: f64 = 1;
        for (m.power) |p| {
            res *= @floatFromInt(p);
        }
        maxStates = @max(maxStates, res);
    }
    log.info("Max states: {e}\n", .{maxStates});
    lines.reset();

    var i: usize = 1;
    while (lines.next()) |line| {
        log.info("Finding result for machine {d} of {d}", .{ i, n });
        const m = try Machine.parse(gpa, line);
        // try m.printContents();
        res1 += try solve1(m);
        const resStruct = solve2(m);
        res2 += resStruct.res;
        maxPushGroupSize = @max(maxPushGroupSize, resStruct.maxPushGroupSize);
        maxScore = @max(maxScore, resStruct.score);
        i += 1;
    }
    log.info("MaxScore: {d}", .{maxScore});
    log.info("MaxPushGroupSize: {d}", .{maxPushGroupSize});
    log.info("Result1: {d}", .{res1});
    log.info("Result2: {d}", .{res2});
}
