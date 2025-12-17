const std = @import("std");

/// RuntimeStarsAndBars generates all ways to distribute `n` items into `k` buckets
/// where n and k are runtime values. Requires an allocator for dynamic storage.
pub fn RuntimeStarsAndBars(comptime T: type) type {
    return struct {
        buckets: []T,
        result: []T,
        n: T,
        done: bool,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, n: T, k: usize) !Self {
            const buckets = try allocator.alloc(T, k);
            const result = try allocator.alloc(T, k);
            @memset(buckets, 0);
            if (k > 0) buckets[0] = n;
            return Self{
                .buckets = buckets,
                .result = result,
                .n = n,
                .done = false,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buckets);
            self.allocator.free(self.result);
        }

        /// Returns the current combination, or null if iteration is complete.
        pub fn next(self: *Self) ?[]const T {
            if (self.done) return null;

            const k = self.buckets.len;

            // Copy current state to return before modifying
            @memcpy(self.result, self.buckets);

            // Check if we're at the final state (all items in last bucket)
            if (self.buckets[k - 1] == self.n) {
                self.done = true;
                return self.result;
            }

            // Handle single bucket case
            if (k == 1) {
                self.done = true;
                return self.result;
            }

            // Find rightmost non-last bucket that has items
            var i: usize = k - 2;
            while (self.buckets[i] == 0) {
                i -= 1;
            }

            // Move one item from bucket[i] to bucket[i+1], and collect all items
            // from buckets after i+1 back to bucket[i+1]
            var items_after: T = 0;
            for (self.buckets[i + 1 ..]) |v| {
                items_after += v;
            }

            self.buckets[i] -= 1;
            self.buckets[i + 1] = items_after + 1;

            // Zero out everything after position i+1
            for (self.buckets[i + 2 ..]) |*b| {
                b.* = 0;
            }

            return self.result;
        }

        /// Reset the iterator to the beginning.
        pub fn reset(self: *Self) void {
            @memset(self.buckets, 0);
            if (self.buckets.len > 0) self.buckets[0] = self.n;
            self.done = false;
        }
    };
}

/// StarsAndBars generates all ways to distribute `n` items into `k` buckets.
/// Each combination is a slice where each index contains the count of items in that bucket.
/// For example, with n=8 and k=8, one combination might be {0, 4, 1, 0, 2, 1, 0, 0}.
pub fn StarsAndBars(comptime T: type, comptime n: T, comptime k: usize) type {
    return struct {
        buckets: [k]T,
        result: [k]T,
        done: bool,

        const Self = @This();

        pub fn init() Self {
            var buckets: [k]T = .{0} ** k;
            buckets[0] = n; // Start with all items in first bucket
            return Self{
                .buckets = buckets,
                .result = undefined,
                .done = false,
            };
        }

        /// Returns the current combination, or null if iteration is complete.
        pub fn next(self: *Self) ?*const [k]T {
            if (self.done) return null;

            // Copy current state to return before modifying
            self.result = self.buckets;

            // Check if we're at the final state (all items in last bucket)
            if (self.buckets[k - 1] == n) {
                self.done = true;
                return &self.result;
            }

            // Handle single bucket case at comptime to avoid k-2 overflow
            if (k == 1) {
                self.done = true;
                return &self.result;
            }

            // Find rightmost non-last bucket that has items
            var i: usize = k - 2;
            while (self.buckets[i] == 0) {
                i -= 1;
            }

            // Move one item from bucket[i] to bucket[i+1], and collect all items
            // from buckets after i+1 back to bucket[i+1]
            const items_after: T = blk: {
                var sum: T = 0;
                for (i + 1..k) |j| {
                    sum += self.buckets[j];
                }
                break :blk sum;
            };

            self.buckets[i] -= 1;
            self.buckets[i + 1] = items_after + 1;

            // Zero out everything after position i+1
            for (i + 2..k) |j| {
                self.buckets[j] = 0;
            }

            return &self.result;
        }

        /// Reset the iterator to the beginning.
        pub fn reset(self: *Self) void {
            self.buckets = .{0} ** k;
            self.buckets[0] = n;
            self.done = false;
        }
    };
}

test "StarsAndBars basic" {
    // Test distributing 3 items into 2 buckets
    // Should give: {3,0}, {2,1}, {1,2}, {0,3}
    const SAB = StarsAndBars(u8, 3, 2);
    var iter = SAB.init();

    const expected = [_][2]u8{
        .{ 3, 0 },
        .{ 2, 1 },
        .{ 1, 2 },
        .{ 0, 3 },
    };

    var count: usize = 0;
    while (iter.next()) |combo| {
        try std.testing.expectEqualSlices(u8, &expected[count], combo);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), count);
}

test "StarsAndBars count" {
    // The number of ways to distribute n items into k buckets is C(n+k-1, k-1)
    // For n=5, k=3: C(7,2) = 21
    const SAB = StarsAndBars(u8, 5, 3);
    var iter = SAB.init();

    var count: usize = 0;
    while (iter.next()) |combo| {
        // Verify sum is always n
        var sum: u8 = 0;
        for (combo) |v| sum += v;
        try std.testing.expectEqual(@as(u8, 5), sum);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 21), count);
}

test "StarsAndBars single bucket" {
    // With only 1 bucket, there's exactly 1 way: all items in that bucket
    const SAB = StarsAndBars(u8, 10, 1);
    var iter = SAB.init();

    const combo = iter.next();
    try std.testing.expect(combo != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{10}, combo.?);

    // Should be done after one iteration
    try std.testing.expectEqual(@as(?*const [1]u8, null), iter.next());
}

test "StarsAndBars zero items" {
    // Distributing 0 items into 3 buckets: only one way {0,0,0}
    const SAB = StarsAndBars(u8, 0, 3);
    var iter = SAB.init();

    const combo = iter.next();
    try std.testing.expect(combo != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0 }, combo.?);

    // Should be done after one iteration
    try std.testing.expectEqual(@as(?*const [3]u8, null), iter.next());
}

test "StarsAndBars reset" {
    const SAB = StarsAndBars(u8, 2, 2);
    var iter = SAB.init();

    // Exhaust the iterator
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), count); // {2,0}, {1,1}, {0,2}

    // Reset and iterate again
    iter.reset();
    count = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "StarsAndBars three buckets exact sequence" {
    // Distributing 2 items into 3 buckets
    // C(4,2) = 6 combinations
    const SAB = StarsAndBars(u8, 2, 3);
    var iter = SAB.init();

    const expected = [_][3]u8{
        .{ 2, 0, 0 },
        .{ 1, 1, 0 },
        .{ 1, 0, 1 },
        .{ 0, 2, 0 },
        .{ 0, 1, 1 },
        .{ 0, 0, 2 },
    };

    var count: usize = 0;
    while (iter.next()) |combo| {
        try std.testing.expectEqualSlices(u8, &expected[count], combo);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 6), count);
}

test "StarsAndBars no duplicates" {
    const SAB = StarsAndBars(u8, 4, 3);
    var iter = SAB.init();

    var seen = std.AutoHashMap([3]u8, void).init(std.testing.allocator);
    defer seen.deinit();

    while (iter.next()) |combo| {
        const key = combo.*;
        // Should not have seen this combination before
        try std.testing.expect(!seen.contains(key));
        try seen.put(key, {});
    }

    // C(6,2) = 15 unique combinations
    try std.testing.expectEqual(@as(usize, 15), seen.count());
}

test "StarsAndBars different integer type u16" {
    const SAB = StarsAndBars(u16, 100, 2);
    var iter = SAB.init();

    // First should be {100, 0}
    const first = iter.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(@as(u16, 100), first.?[0]);
    try std.testing.expectEqual(@as(u16, 0), first.?[1]);

    // Count all - should be 101 (from {100,0} to {0,100})
    var count: usize = 1;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 101), count);
}

test "StarsAndBars larger count verification" {
    // C(n+k-1, k-1) formula verification
    // n=10, k=4: C(13, 3) = 286
    const SAB = StarsAndBars(u8, 10, 4);
    var iter = SAB.init();

    var count: usize = 0;
    while (iter.next()) |combo| {
        var sum: u16 = 0;
        for (combo) |v| sum += v;
        try std.testing.expectEqual(@as(u16, 10), sum);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 286), count);
}

test "StarsAndBars first and last" {
    const SAB = StarsAndBars(u8, 5, 4);
    var iter = SAB.init();

    // First combination should be all items in first bucket
    const first = iter.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 0, 0, 0 }, first.?);

    // Exhaust iterator to find last
    var last: [4]u8 = undefined;
    while (iter.next()) |combo| {
        last = combo.*;
    }

    // Last combination should be all items in last bucket
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 5 }, &last);
}

// ============ Runtime version tests ============

test "RuntimeStarsAndBars basic" {
    const RSAB = RuntimeStarsAndBars(u8);
    var iter = try RSAB.init(std.testing.allocator, 3, 2);
    defer iter.deinit();

    const expected = [_][2]u8{
        .{ 3, 0 },
        .{ 2, 1 },
        .{ 1, 2 },
        .{ 0, 3 },
    };

    var count: usize = 0;
    while (iter.next()) |combo| {
        try std.testing.expectEqualSlices(u8, &expected[count], combo);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), count);
}

test "RuntimeStarsAndBars with runtime values" {
    const RSAB = RuntimeStarsAndBars(u8);

    // Simulate runtime values
    var n: u8 = 5;
    var k: usize = 3;
    n += 0; // prevent comptime evaluation
    k += 0;

    var iter = try RSAB.init(std.testing.allocator, n, k);
    defer iter.deinit();

    var count: usize = 0;
    while (iter.next()) |combo| {
        var sum: u8 = 0;
        for (combo) |v| sum += v;
        try std.testing.expectEqual(@as(u8, 5), sum);
        try std.testing.expectEqual(@as(usize, 3), combo.len);
        count += 1;
    }
    // C(7,2) = 21
    try std.testing.expectEqual(@as(usize, 21), count);
}

test "RuntimeStarsAndBars single bucket" {
    const RSAB = RuntimeStarsAndBars(u8);
    var iter = try RSAB.init(std.testing.allocator, 10, 1);
    defer iter.deinit();

    const combo = iter.next();
    try std.testing.expect(combo != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{10}, combo.?);
    try std.testing.expectEqual(@as(?[]const u8, null), iter.next());
}

test "RuntimeStarsAndBars zero items" {
    const RSAB = RuntimeStarsAndBars(u8);
    var iter = try RSAB.init(std.testing.allocator, 0, 3);
    defer iter.deinit();

    const combo = iter.next();
    try std.testing.expect(combo != null);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0 }, combo.?);
    try std.testing.expectEqual(@as(?[]const u8, null), iter.next());
}

test "RuntimeStarsAndBars reset" {
    const RSAB = RuntimeStarsAndBars(u8);
    var iter = try RSAB.init(std.testing.allocator, 2, 2);
    defer iter.deinit();

    var count: usize = 0;
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 3), count);

    iter.reset();
    count = 0;
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "RuntimeStarsAndBars larger type u32" {
    const RSAB = RuntimeStarsAndBars(u32);
    var iter = try RSAB.init(std.testing.allocator, 1000, 2);
    defer iter.deinit();

    // First should be {1000, 0}
    const first = iter.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(@as(u32, 1000), first.?[0]);
    try std.testing.expectEqual(@as(u32, 0), first.?[1]);

    // Count all - should be 1001
    var count: usize = 1;
    while (iter.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 1001), count);
}
