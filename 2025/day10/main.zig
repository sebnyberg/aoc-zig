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
        std.debug.print("[{s}]\n", .{wantStr});

        // Print toggles
        for (self.pushEffectBits) |toggle| {
            const s = bmstr(u32, toggle, self.w)[0..self.w];
            std.debug.print("({s})\n", .{s});
        }

        // Print energy
        std.debug.print("{any} \n", .{self.power});

        std.debug.print("\n", .{});
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
            for (m.pushEffectBits, 0..) |t, i| {
                const y = x ^ t;
                _ = i;
                // print("{s} ^ {s}[{d}] -> {s}", .{
                //     bmstr(u32, x, m.w)[0..m.w],
                //     bmstr(u32, t, m.w)[0..m.w],
                //     i,
                //     bmstr(u32, y, m.w)[0..m.w],
                // });
                if (y == m.want) {
                    // print(" (MATCH!)\n", .{});
                    return k;
                }
                if (seen[y] == 1) {
                    // print(" (Seen)\n", .{});
                    continue;
                }
                // print(" (New)\n", .{});
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

pub fn solve2(m: Machine) !struct {
    score: f64,
    res: u32,
} {
    // This part has two phases:
    //
    // 1. Find the most effective search order. The most effective search order
    //    minimizes the number of power indices to consider at each position.
    //
    // 2. Execute the search.
    //

    // var powerPushIndices = gpa.alloc(ArrayList)
    const plan = try solve2_findSearchPlan(gpa, m);

    print("Running search for score {d}\n", .{plan.score});
    const result = try solve2_minimizeSteps(gpa, m, plan.plan);
    print("Result!! {d}\n", .{result});

    return .{
        .score = plan.score,
        .res = result,
    };
}

fn solve2_minimizeSteps(allocator: std.mem.Allocator, m: Machine, searchPlan: []SearchStep) !u32 {
    var mem = std.AutoHashMap([16]u16, u32).init(allocator);
    defer mem.deinit();
    var wantPower: [16]u16 = .{0} ** 16;
    for (0..m.power.len) |i| {
        wantPower[i] = m.power[i];
    }
    const currPower: [16]u16 = .{0} ** 16;
    var pushPowerDelta: [16][16]u1 = undefined;
    for (m.pushEffects, 0..) |powerIndices, i| {
        pushPowerDelta[i] = .{0} ** 16;
        for (powerIndices) |powerIdx| {
            pushPowerDelta[i][powerIdx] = 1;
        }
    }

    return solve2_minimizeSteps_dfs(&mem, 0, m.w, currPower, &wantPower, searchPlan, &pushPowerDelta);
}

fn addArrays(comptime T1: type, comptime T2: type, comptime n: usize, a: [n]T1, b: [n]T2) [n]T1 {
    var res: [n]T1 = .{0} ** n;
    for (0..n) |i| {
        res[i] = a[i] + b[i];
    }
    return res;
}

fn solve2_minimizeSteps_dfs(
    mem: *std.AutoHashMap([16]u16, u32),
    planIdx: usize,
    npower: usize,
    currPower: [16]u16,
    wantPower: *[16]u16,
    plan: []SearchStep,
    pushPowerDelta: *[16][16]u1,
) !u32 {
    if (planIdx == plan.len) {
        print("Found a result!\n", .{});
        return 0;
    }
    // print("npushes: {d}\n", .{plan[planIdx].npushes});
    // print("plan[planIdx] = plan[{d}] = {any}\n", .{ planIdx, plan[planIdx] });
    if (mem.get(currPower)) |res| {
        // print("curr Power seen!\n", .{});
        return res;
    }

    var res: u32 = std.math.maxInt(u30);
    const step = plan[planIdx];

    // Check if we don't need to perform any actions
    if (currPower[step.powerIdx] == wantPower[step.powerIdx]) {
        // print("Done with powerIdx {d}\n", .{step.powerIdx});
        // continue to next step of the plan.
        return try solve2_minimizeSteps_dfs(mem, planIdx + 1, npower, currPower, wantPower, plan, pushPowerDelta);
    }

    if (currPower[step.powerIdx] > wantPower[step.powerIdx]) {
        return std.math.maxInt(u30);
    }

    // At this stage, we need to push some buttons.
    // But maybe we can't?
    if (step.npushes == 0) {
        return std.math.maxInt(u30);
    }

    // Or we can, in which case, let's push any button!
    for (step.pushIndices[0..step.npushes]) |pushIdx| {
        const nextPower = addArrays(u16, u1, 16, currPower, pushPowerDelta[pushIdx]);

        // Delta was OK, let's push the button and continue
        var subRes = try solve2_minimizeSteps_dfs(mem, planIdx, npower, nextPower, wantPower, plan, pushPowerDelta);
        subRes += 1;
        res = @min(
            res,
            subRes,
        );
    }

    // Try taking each step available in the plan.
    try mem.put(currPower, res);
    return res;
}

const invalidPushIdx = 1337;

const SearchStep = struct {
    powerIdx: usize,
    npushes: u32,
    pushIndices: [11]usize,
};

fn solve2_findSearchPlan(
    allocator: std.mem.Allocator,
    m: Machine,
) !struct {
    score: f64,
    plan: []SearchStep,
} {
    // To find the most effective search order, we can perform dfs.
    const visited = try allocator.alloc(bool, m.w);
    defer allocator.free(visited);
    @memset(visited, false);

    const pushUsed = try allocator.alloc(bool, m.pushEffects.len);
    defer allocator.free(pushUsed);
    @memset(pushUsed, false);

    const bestSearchPlan = try allocator.alloc(SearchStep, m.w);
    @memset(bestSearchPlan, .{
        .powerIdx = 100,
        .npushes = 0,
        .pushIndices = .{invalidPushIdx} ** 11,
    });

    const currentSearchPlan: []SearchStep = try allocator.dupe(SearchStep, bestSearchPlan);
    defer allocator.free(currentSearchPlan);

    // Convert push indices to map from power indices to push indices
    var powerToPushIdxBuf: [16][16]usize = undefined;
    var powerToPushLen: [16]usize = .{0} ** 16;
    for (m.pushEffects, 0..) |powerIndices, pushIdx| {
        for (powerIndices) |powerIdx| {
            powerToPushIdxBuf[powerIdx][powerToPushLen[powerIdx]] = pushIdx;
            powerToPushLen[powerIdx] += 1;
        }
    }

    const powerToPushIdx: [][]usize = try allocator.alloc([]usize, m.w);
    for (powerToPushIdx, 0..) |*pushIndices, i| {
        pushIndices.* = powerToPushIdxBuf[i][0..powerToPushLen[i]];
    }

    var bestScore: f64 = std.math.floatMax(f64);

    try solve2_findSearchPlan_dfs(
        visited,
        pushUsed,
        powerToPushIdx,
        currentSearchPlan,
        bestSearchPlan,
        &bestScore,
        0,
        1,
    );

    return .{
        .score = bestScore,
        .plan = bestSearchPlan,
    };
}

fn fac(x: u64) f64 {
    var res: f64 = 1;
    for (1..x) |i| {
        res *= @floatFromInt(i);
    }
    return res;
}

fn solve2_findSearchPlan_dfs(
    visited: []bool,
    pushUsed: []bool,
    powerPushIndices: [][]usize,
    currentSearchPlan: []SearchStep,
    bestSearchPlan: []SearchStep,
    bestScore: *f64,
    searchIdx: usize,
    score: f64,
) !void {
    if (score >= bestScore.*) {
        return; // no point continuing
    }
    const npower = powerPushIndices.len;
    if (searchIdx == npower) {
        // Score is smaller than before + no more power needed.
        // Capture search order
        for (0..currentSearchPlan.len) |i| {
            bestSearchPlan[i] = currentSearchPlan[i];
        }
        bestScore.* = score;
        // print("Found a new lowest score: {d}\n", .{score});
        return;
    }

    // For each power index
    for (0..npower) |powerIdx| {
        if (visited[powerIdx]) {
            continue;
        }
        visited[powerIdx] = true;

        currentSearchPlan[searchIdx].powerIdx = powerIdx;

        // Add unused push indices to the search order
        var pushInsertIdx: u64 = 0;
        for (powerPushIndices[powerIdx]) |pushIdx| {
            if (pushUsed[pushIdx]) {
                continue;
            }
            currentSearchPlan[searchIdx].pushIndices[pushInsertIdx] = pushIdx;
            pushInsertIdx += 1;
            pushUsed[pushIdx] = true;
        }
        // print("currentSearchPlan: {any}\n", .{currentSearchPlan[searchIdx]});
        // print("currentSearchPlan[searchIdx][0]: {any}\n", .{currentSearchPlan[searchIdx].pushIndices[0]});
        // print("visited: {any}\n", .{visited});
        // print("pushUsed: {any}\n", .{pushUsed});
        currentSearchPlan[searchIdx].npushes = @truncate(pushInsertIdx);
        const npushes = pushInsertIdx;

        // Try visiting this power index at this time
        try solve2_findSearchPlan_dfs(
            visited,
            pushUsed,
            powerPushIndices,
            currentSearchPlan,
            bestSearchPlan,
            bestScore,
            searchIdx + 1,
            score * fac(npushes + 1),
        );

        // Reset changes
        visited[powerIdx] = false;

        // print("currentSearchPlan[searchIdx]: {any}\n", .{currentSearchPlan[searchIdx]});
        for (0..npushes) |i| {
            const pushIdx = currentSearchPlan[searchIdx].pushIndices[i];
            pushUsed[pushIdx] = false;
            currentSearchPlan[searchIdx].pushIndices[i] = invalidPushIdx;
        }
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
    var res2: u64 = 0;

    var n: usize = 0;
    while (lines.next()) |_| {
        n += 1;
    }
    lines.reset();

    var i: usize = 1;
    while (lines.next()) |line| {
        print("Finding result for machine {d} of {d}\n", .{ i, n });
        const m = try Machine.parse(gpa, line);
        // try m.printContents();
        res1 += try solve1(m);
        const resStruct = try solve2(m);
        res2 += resStruct.res;
        maxScore = @max(maxScore, resStruct.score);
        i += 1;
    }
    print("MaxScore:\n{d}\n", .{maxScore});
    print("Result1:\n{d}\n", .{res1});
    print("Result2:\n{d}\n", .{res2});
}
