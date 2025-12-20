const std = @import("std");

const parseInt = std.fmt.parseInt;
const cwd = std.fs.cwd;
const splitScalar = std.mem.splitScalar;
const tokenizeScalar = std.mem.tokenizeScalar;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const eql = std.mem.eql;

const Node = struct {
    index: usize,
    name: []const u8,
    next: ArrayList(usize) = ArrayList(usize){},
};

test "Graph" {
    const filepath = "testinput";
    const alloc = std.testing.allocator;
    const contents = try cwd().readFileAlloc(alloc, filepath, 4 << 20);
    defer alloc.free(contents);

    var g = try Graph.parse(alloc, contents);
    defer g.deinit();

    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var k: usize = 0;
    while (lines.next()) |_| {
        k += 1;
    }
    k += 1; // add "out" which does not have forward edges
    try std.testing.expectEqual(k, g.next.len);
}

const Graph = struct {
    names: [][]const u8,
    next: [][]usize,
    name_to_idx: std.StringArrayHashMap(usize),
    alloc: std.mem.Allocator,

    const Self = @This();

    fn parse(alloc: std.mem.Allocator, contents: []const u8) !Self {
        var lines = std.mem.tokenizeScalar(u8, contents, '\n');
        var _names = std.ArrayList([]const u8){};
        var name_to_idx = std.StringArrayHashMap(usize).init(alloc);
        var _next = std.ArrayList(ArrayList(usize)){};

        while (lines.next()) |line| {
            var fields = std.mem.tokenizeScalar(u8, line, ' ');
            var name = fields.next().?;
            name = name[0 .. name.len - 1];

            // Maybe add to names
            const entry = try name_to_idx.getOrPut(name);
            if (!entry.found_existing) {
                entry.value_ptr.* = _names.items.len;
                try _next.append(alloc, ArrayList(usize){});
                try _names.append(alloc, name);
            }
            const index = entry.value_ptr.*;

            var i: usize = 1;
            while (fields.next()) |field| : (i += 1) {
                const r = try name_to_idx.getOrPut(field);
                if (!r.found_existing) {
                    r.value_ptr.* = _names.items.len;
                    try _names.append(alloc, field);
                    try _next.append(alloc, ArrayList(usize){});
                }
                const nextId = r.value_ptr.*;
                try _next.items[index].append(alloc, nextId);
            }
        }

        var next = try alloc.alloc([]usize, _next.items.len);
        for (_next.items, 0..) |*list, i| {
            next[i] = try list.toOwnedSlice(alloc);
        }
        _next.deinit(alloc);
        const names = try _names.toOwnedSlice(alloc);

        return .{
            .alloc = alloc,
            .names = names,
            .name_to_idx = name_to_idx,
            .next = next,
        };
    }

    fn deinit(self: *Self) void {
        self.alloc.free(self.names);
        for (self.next, 0..) |_, i| {
            self.alloc.free(self.next[i]);
        }
        self.alloc.free(self.next);
        self.name_to_idx.deinit();
    }

    fn print(self: Self) void {
        for (self.next, 0..) |adj, i| {
            std.debug.print("{s}({d}) -> [", .{ self.names[i], i });
            for (adj, 0..) |nei, j| {
                if (j > 0) {
                    std.debug.print(", ", .{});
                }
                std.debug.print("{s}({d})", .{ self.names[nei], nei });
            }
            std.debug.print("]\n", .{});
        }
    }
};

fn solve1(alloc: std.mem.Allocator, contents: []const u8) !u64 {
    const g = try Graph.parse(alloc, contents);
    // g.print();

    // Explore all possible paths, memoizing the result and detecting a cycle.
    const m = g.next.len;
    const start_idx = g.name_to_idx.get("you").?;
    const out_index = g.name_to_idx.get("out").?;

    var mem = try alloc.alloc(usize, m);
    defer alloc.free(mem);
    @memset(mem, std.math.maxInt(usize));
    mem[out_index] = 1;

    // Run DFS;
    const res = try dfs1(mem, g.next, start_idx);

    return res;
}

fn dfs1(mem: []usize, next: [][]usize, i: usize) !usize {
    if (mem[i] != std.math.maxInt(usize)) {
        return mem[i];
    }

    // For each next place
    var res: usize = 0;
    for (next[i]) |j| {
        res += try dfs1(mem, next, j);
    }
    mem[i] = res;
    return res;
}

const SolveErrors = error{
    CycleDetected,
};

fn solve2(alloc: std.mem.Allocator, contents: []const u8) !u64 {
    const g = try Graph.parse(alloc, contents);
    // g.print();

    // Explore all possible paths, memoizing the result and detecting a cycle.
    const start_idx = g.name_to_idx.get("svr").?;
    const out_idx = g.name_to_idx.get("out").?;
    const dac_idx = g.name_to_idx.get("dac").?;
    const fft_idx = g.name_to_idx.get("fft").?;
    const seen = try alloc.alloc(bool, g.next.len);
    defer alloc.free(seen);
    @memset(seen, false);

    // Run DFS;
    var pf = try PathFinder.init(
        alloc,
        g,
        out_idx,
        dac_idx,
        fft_idx,
    );
    defer pf.deinit();
    pf.mem[out_idx] = Result{
        .noneCount = 1,
        .dacCount = 0,
        .fftCount = 0,
        .bothCount = 0,
    };
    const res = try pf.countValidPaths(start_idx, 0);

    return res.bothCount;
}

const Result = struct {
    noneCount: usize,
    dacCount: usize,
    fftCount: usize,
    bothCount: usize,
};

const PathFinder = struct {
    g: Graph,
    n: usize,
    end: usize,
    alloc: std.mem.Allocator,
    seen: []bool,
    mem: []?Result,
    dac_id: usize,
    fft_id: usize,

    const Self = @This();

    fn init(
        alloc: std.mem.Allocator,
        g: Graph,
        end: usize,
        dac_id: usize,
        fft_id: usize,
    ) !Self {
        const n = g.next.len;
        const mem = try alloc.alloc(?Result, n);
        @memset(mem, null);
        const seen = try alloc.alloc(bool, n);
        @memset(seen, false);
        return .{
            .alloc = alloc,
            .g = g,
            .n = n,
            .end = end,
            .seen = seen,
            .mem = mem,
            .dac_id = dac_id,
            .fft_id = fft_id,
        };
    }

    fn deinit(self: *Self) void {
        self.alloc.free(self.seen);
        self.alloc.free(self.mem);
    }

    pub fn countValidPaths(
        self: *Self,
        i: usize,
        n_visited: usize,
    ) !Result {
        // Cycle detection
        if (self.seen[i]) {
            return error.CycleDetected;
        }
        self.seen[i] = true;
        defer {
            self.seen[i] = false;
        }

        // If there is a result, use it
        if (self.mem[i]) |res| {
            return res;
        }

        var res = Result{
            .bothCount = 0,
            .dacCount = 0,
            .fftCount = 0,
            .noneCount = 0,
        };
        for (self.g.next[i]) |j| {
            const x = try self.countValidPaths(j, n_visited + 1);
            res.bothCount += x.bothCount;
            res.fftCount += x.fftCount;
            res.dacCount += x.dacCount;
            res.noneCount += x.noneCount;
        }
        if (i == self.dac_id) {
            res.dacCount += res.noneCount;
            res.noneCount = 0;
            res.bothCount += res.fftCount;
            res.fftCount = 0;
        } else if (i == self.fft_id) {
            res.fftCount += res.noneCount;
            res.noneCount = 0;
            res.bothCount += res.dacCount;
            res.dacCount = 0;
        }
        self.mem[i] = res;

        return res;
    }
};

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa_impl.allocator();
    const filepath = "input";
    const contents = try cwd().readFileAlloc(alloc, filepath, 4 << 20);
    // std.debug.print("Result1: {d}\n", .{try solve1(alloc, contents)});
    std.debug.print("Result2: {d}\n", .{try solve2(alloc, contents)});
}
