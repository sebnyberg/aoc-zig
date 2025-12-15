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
    x: i64,
    y: i64,
};

pub fn solve1(points: []const Point) u64 {
    var maxDist: u64 = 0;
    for (0..points.len - 1) |i| {
        for (i + 1..points.len) |j| {
            const ax = points[i].x;
            const ay = points[i].y;
            const bx = points[j].x;
            const by = points[j].y;

            maxDist = @max(maxDist, (@abs(bx - ax) + 1) * (@abs(by - ay) + 1));
        }
    }
    return maxDist;
}

const dirs8 = [_][2]i8{ .{ -1, 1 }, .{ -1, 0 }, .{ -1, -1 }, .{ 0, -1 }, .{ 0, 1 }, .{ 1, -1 }, .{ 1, 0 }, .{ 1, 1 } };

fn swap(comptime T: type, a: T, b: T) struct { T, T } {
    return .{ b, a };
}

fn printSquare(comptime T: type, grid: [][]T, p: Point, q: Point) void {
    const lox = @min(p.x, q.x);
    const loy = @min(p.y, q.y);
    const hix = @max(p.x, q.x);
    const hiy = @max(p.y, q.y);

    for (grid, 0..) |row, i| {
        for (row, 0..) |cell, j| {
            if ((i == loy or i == hiy) and (j >= lox and j <= hix)) {
                // horizontal rows
                if (j == lox or j == hix) {
                    print("X", .{});
                } else {
                    print("-", .{});
                }
            } else if ((j == lox or j == hix) and (i >= loy and i <= hiy)) {
                // vertical rows
                print("|", .{});
            } else if (cell == 1) {
                print("#", .{});
            } else {
                print(".", .{});
            }
        }
        print("\n", .{});
    }
}

fn printGrid(comptime T: type, grid: [][]T) void {
    for (grid) |row| {
        for (row) |cell| {
            if (cell != 1) {
                print(".", .{});
            } else {
                print("#", .{});
            }
        }
        print("\n", .{});
    }
}

pub fn solve2(points: []const Point, fillPoint: Point) !u64 {
    // Perform coordinate compression, storing original coordinates in
    // xs and ys and a mapping from those coords to indices in xidx and yidx.
    var xs = try ArrayList(i64).initCapacity(gpa, 100);
    defer xs.deinit(gpa);
    var ys = try ArrayList(i64).initCapacity(gpa, 100);
    defer ys.deinit(gpa);

    // First round: xidx and yidx are used to capture unique coords.
    var xidx = std.AutoHashMap(i64, i63).init(gpa);
    defer xidx.deinit();
    var yidx = std.AutoHashMap(i64, i63).init(gpa);
    defer yidx.deinit();

    for (points) |point| {
        // capture without index for now
        try xidx.put(point.x, 0);
        try yidx.put(point.y, 0);
    }

    // Store unique x- and y coordinates in the lists
    var xiter = xidx.keyIterator();
    while (xiter.next()) |x| {
        try xs.append(gpa, x.*);
    }
    var yiter = yidx.keyIterator();
    while (yiter.next()) |y| {
        try ys.append(gpa, y.*);
    }

    // Sort coords
    try xs.append(gpa, 0);
    try xs.append(gpa, 2 << 20);
    try ys.append(gpa, 0);
    try ys.append(gpa, 1 << 20);
    std.mem.sort(i64, xs.items, {}, std.sort.asc(i64));
    std.mem.sort(i64, ys.items, {}, std.sort.asc(i64));

    // Store coordinate indices in the maps
    for (xs.items, 0..) |x, i| {
        try xidx.put(x, @as(i63, @intCast(i)));
    }
    for (ys.items, 0..) |y, i| {
        try yidx.put(y, @as(i63, @intCast(i)));
    }

    // Create a compressed grid
    var grid = try gpa.alloc([]u1, ys.items.len);
    defer gpa.free(grid);
    for (grid, 0..) |_, i| {
        grid[i] = try gpa.alloc(u1, xs.items.len);
    }
    defer for (grid, 0..) |_, i| {
        gpa.free(grid[i]);
    };

    // First, let's draw the shape based on the points. Any coordinate that is
    // touched (except the last) has a xor bit set.
    var x = xidx.get(points[0].x).?;
    var y = yidx.get(points[0].y).?;

    for (0..points.len) |i| {
        const nextPoint = points[@rem(i + 1, points.len)];
        const nextX = xidx.get(nextPoint.x).?;
        const nextY = yidx.get(nextPoint.y).?;

        // Capture the direction
        var dx = nextX - x;
        if (dx < 0) {
            dx = -1;
        } else if (dx > 0) {
            dx = 1;
        }

        var dy = nextY - y;
        if (dy < 0) {
            dy = -1;
        } else if (dy > 0) {
            dy = 1;
        }

        // print("x: {d}, y: {d}, nextX: {d}, nextY: {d}\n", .{ x, y, nextX, nextY });

        // add dx and dy until x == nextX and y == nextY
        while (x != nextX or y != nextY) {
            x += dx;
            y += dy;

            // Draw
            grid[@abs(y)][@abs(x)] = 1;
        }
    }

    // Flood-fill
    {
        // I had a look at the rendering and found that we can perform flood fill to mark
        // the valid cells, starting at the manually selected position below
        var curr = try ArrayList(Point).initCapacity(gpa, 1);
        defer curr.deinit(gpa);
        var next = try ArrayList(Point).initCapacity(gpa, 1);
        defer next.deinit(gpa);
        try curr.append(gpa, fillPoint);
        grid[@as(u63, @intCast(fillPoint.y))][@as(u63, @intCast(fillPoint.x))] = 1;

        while (curr.items.len > 0) {
            next.clearRetainingCapacity();

            // For each point
            for (curr.items) |p| {
                // Find points around that point
                for (dirs8) |dir| {
                    const dx = dir[0];
                    const dy = dir[1];
                    const xx = @as(u63, @intCast(p.x + dx));
                    const yy = @as(u63, @intCast(p.y + dy));
                    if (grid[yy][xx] != 1) {
                        grid[yy][xx] = 1;
                        try next.append(gpa, .{ .x = xx, .y = yy });
                    }
                }
            }

            const tmp = next;
            next = curr;
            curr = tmp;
        }
    }

    // Let's create a list of prefix sums to speed up the verification of squares.
    // (Note: list of 1d prefix sums, I CBA to do a 2d presum, too much off-by-one)

    var arena_impl = std.heap.ArenaAllocator.init(gpa);
    var arena = arena_impl.allocator();
    defer arena_impl.deinit();

    var presums = try arena.alloc([]u32, ys.items.len);
    for (presums, 0..) |_, i| {
        presums[i] = try arena.alloc(u32, xs.items.len + 1);
        for (0..xs.items.len) |j| {
            presums[i][j + 1] = presums[i][j] + grid[i][j];
        }
    }

    // Let's test all pairs of points.
    var maxDist: u64 = 0;
    for (0..points.len - 1) |i| {
        outer: for (i + 1..points.len) |j| {
            const ax = points[i].x;
            const ay = points[i].y;
            const bx = points[j].x;
            const by = points[j].y;

            const dist = (@abs(bx - ax) + 1) * (@abs(by - ay) + 1);

            if (dist <= maxDist) {
                continue;
            }

            const axx = xidx.get(points[i].x).?;
            const ayy = yidx.get(points[i].y).?;
            const bxx = xidx.get(points[j].x).?;
            const byy = yidx.get(points[j].y).?;

            // Verify that the square contains only filled points.
            // First, fetch compressed coordinates.
            var lox = @as(u64, @intCast(axx));
            var loy = @as(u64, @intCast(ayy));
            var hix = @as(u64, @intCast(bxx));
            var hiy = @as(u64, @intCast(byy));

            // Sort x and y
            if (lox > hix) {
                lox, hix = swap(u64, lox, hix);
            }
            if (loy > hiy) {
                loy, hiy = swap(u64, loy, hiy);
            }
            // print("lox: {d}, hix: {d}, loy: {d}, hiy: {d}\n", .{ lox, hix, loy, hiy });
            // print("presums, m: {d}, n: {d}\n", .{ presums.len, presums[loy].len });

            // For each row
            const wantSum = (hix - lox + 1);
            for (loy..hiy + 1) |row| {
                const a = presums[row][hix + 1];
                const b = presums[row][lox];
                const sum = a - b;
                if (sum != wantSum) {
                    continue :outer; // go to next point pair
                }
            }
            // print("Found a new box!, size: {d}\n", .{maxDist});
            // printSquare(u1, grid, .{ .x = axx, .y = ayy }, .{ .x = bxx, .y = byy });

            maxDist = dist; // success!
        }
    }
    return maxDist;
}

pub fn main() !void {
    const filepath = "input";

    // Carefull and manually selected points for flood filling
    const fillPoint = Point{ .x = 75, .y = 74 };
    // const fillPoint = Point{ .x = 3, .y = 2 };

    // Parse points
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    var points = try std.ArrayList(Point).initCapacity(gpa, 1024);
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeScalar(u8, line, ',');
        const x = try std.fmt.parseInt(i64, fields.next().?, 10);
        const y = try std.fmt.parseInt(i64, fields.next().?, 10);
        try points.append(gpa, .{ .x = x, .y = y });
    }

    // Find maximum area of any pair of points
    print("Result1:\n{d}\n\n", .{solve1(points.items)});
    print("Result2:\n{d}\n\n", .{try solve2(points.items, fillPoint)});
}
