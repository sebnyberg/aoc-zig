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

const Point = struct {
    x: u64,
    y: u64,
    z: u64,
};

fn dist(a: Point, b: Point) f64 {
    var dx = a.x * a.x + b.x * b.x;
    dx -= 2 * a.x * b.x;
    var dy = a.y * a.y + b.y * b.y;
    dy -= 2 * a.y * b.y;
    var dz = a.z * a.z + b.z * b.z;
    dz -= 2 * a.z * b.z;
    const sum = @as(f64, @floatFromInt(dx + dy + dz));
    return std.math.sqrt(sum);
}

fn DSU(comptime T: type) type {
    return struct {
        const Self = @This();

        parent: []T,
        size: []T,

        fn init(alloc: std.mem.Allocator, num: usize) !Self {
            const parent = try alloc.alloc(T, num);
            const size = try alloc.alloc(T, num);
            for (0..num) |i| {
                size[i] = 1;
                parent[i] = @intCast(i);
            }
            return Self{
                .parent = parent,
                .size = size,
            };
        }

        fn deinit(self: *Self, alloc: std.mem.Allocator) void {
            alloc.free(self.parent);
            alloc.free(self.size);
            self.* = undefined;
        }

        fn find(self: *Self, x: T) T {
            if (self.parent[x] == x) {
                return x;
            }
            const rx = self.find(self.parent[x]);
            self.parent[x] = rx; // path compression
            return rx;
        }

        fn _union(self: *Self, a: T, b: T) void {
            const ra = self.find(a);
            const rb = self.find(b);
            if (ra != rb) {
                // unify
                self.parent[rb] = ra;
                self.size[ra] += self.size[rb];
            }
        }
    };
}

pub fn solve1(pts: []const Point, nconn: u64) !u64 {
    const Dist = struct {
        i: u64,
        j: u64,
        d: f64,

        pub fn lessThan(_: void, lhs: @This(), rhs: @This()) bool {
            return lhs.d < rhs.d;
        }
    };

    // Capture distances
    var distsList = try ArrayList(Dist).initCapacity(gpa, 0);
    defer distsList.deinit(gpa);
    for (0..pts.len - 1) |i| {
        for (i + 1..pts.len) |j| {
            try distsList.append(gpa, .{
                .i = i,
                .j = j,
                .d = dist(pts[i], pts[j]),
            });
        }
    }
    const dists = distsList.items;

    // Sort by dist ascending
    std.mem.sort(Dist, distsList.items, {}, Dist.lessThan);

    // Initialize a DSU
    var dsu = try DSU(u64).init(gpa, pts.len);
    defer dsu.deinit(gpa);

    // For each edge, join the points to their respective clusters
    for (0..@min(nconn, dists.len)) |i| {
        const d = dists[i];
        dsu._union(d.i, d.j);
    }

    // Then capture cluster sizes
    var m = std.AutoHashMap(u64, u64).init(gpa);
    defer m.deinit();
    for (0..pts.len) |i| {
        const root = dsu.find(i);
        try m.put(root, dsu.size[root]);
    }
    var sizes = try ArrayList(u64).initCapacity(gpa, 3);
    {
        var iter = m.iterator();
        while (iter.next()) |entry| {
            const size = entry.value_ptr.*;
            try sizes.append(gpa, size);
        }
    }
    std.mem.sort(u64, sizes.items, {}, std.sort.desc(u64));

    const res = sizes.items[0] * sizes.items[1] * sizes.items[2];
    return res;
}

pub fn solve2(pts: []const Point) !u64 {
    const Dist = struct {
        i: u64,
        j: u64,
        d: f64,

        pub fn lessThan(_: void, lhs: @This(), rhs: @This()) bool {
            return lhs.d < rhs.d;
        }
    };

    // Capture distances
    var distsList = try ArrayList(Dist).initCapacity(gpa, 0);
    defer distsList.deinit(gpa);
    for (0..pts.len - 1) |i| {
        for (i + 1..pts.len) |j| {
            try distsList.append(gpa, .{
                .i = i,
                .j = j,
                .d = dist(pts[i], pts[j]),
            });
        }
    }
    const dists = distsList.items;

    // Sort by dist ascending
    std.mem.sort(Dist, distsList.items, {}, Dist.lessThan);

    // Initialize a DSU
    var dsu = try DSU(u64).init(gpa, pts.len);
    defer dsu.deinit(gpa);

    // For each edge, join the points to their respective clusters
    {
        var i: u64 = 0;
        while (true) : (i += 1) {
            const d = dists[i];
            dsu._union(d.i, d.j);
            if (dsu.size[dsu.find(d.i)] == pts.len) {
                // finally joined all points together.
                return pts[d.i].x * pts[d.j].x;
            }
        }
    }

    unreachable;
}

pub fn main() !void {
    var points = try ArrayList(Point).initCapacity(gpa, 0);
    defer points.deinit(gpa);

    const filepath = "input";
    const nconn = 1000;
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');

    while (lines.next()) |line| {
        var fields = std.mem.tokenizeScalar(u8, line, ',');
        const p: Point = .{
            .x = try std.fmt.parseInt(u64, fields.next().?, 10),
            .y = try std.fmt.parseInt(u64, fields.next().?, 10),
            .z = try std.fmt.parseInt(u64, fields.next().?, 10),
        };
        try points.append(gpa, p);
    }

    print("Result1: {d}\n", .{try solve1(points.items, nconn)});
    print("Result2: {d}\n", .{try solve2(points.items)});
}
