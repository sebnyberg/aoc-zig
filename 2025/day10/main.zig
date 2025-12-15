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

const Machine = struct {
    want: u32,
    toggles: []const u32,
    power: []u32,
    w: u8,
    const Self = @This();

    pub fn fromStr(str: []const u8) !Self {
        var self = Self{
            .want = 0,
            .toggles = undefined,
            .power = undefined,
            .w = 0,
        };

        var fields = std.mem.tokenizeScalar(u8, str, ' ');

        var toggles = try std.ArrayList(u32).initCapacity(gpa, 10);
        while (fields.next()) |field| {
            switch (field[0]) {
                '[' => {
                    for (1..field.len - 1) |j| {
                        self.want <<= 1;
                        self.want += if (field[j] == '#') @as(u1, 1) else 0;
                    }
                    self.w = @as(u8, @intCast(field.len)) - 2;
                },
                '(' => {
                    var toggle: u32 = 0;
                    var nums = std.mem.tokenizeScalar(u8, field[1 .. field.len - 1], ',');
                    while (nums.next()) |num| {
                        const x = try std.fmt.parseInt(u5, num, 10);
                        toggle |= @as(u32, 1) << x;
                    }
                    try toggles.append(gpa, toggle);
                },
                '{' => {
                    self.power = try gpa.alloc(u32, self.w);
                    var nums = std.mem.tokenizeScalar(u8, field[1 .. field.len - 1], ',');
                    var i: u8 = 0;
                    while (nums.next()) |num| : (i += 1) {
                        const x = try std.fmt.parseInt(u8, num, 10);
                        self.power[i] = x;
                    }
                },
                else => unreachable,
            }
        }

        self.toggles = try toggles.toOwnedSlice(gpa);

        return self;
    }

    pub fn print(self: Self) !void {
        // Convert bitmap to "wantstr"
        const wantStr = bmstr(u32, self.want, self.w)[0..self.w];
        std.debug.print("[{s}]\n", .{wantStr});

        // Print toggles
        for (self.toggles) |toggle| {
            const s = bmstr(u32, toggle, self.w)[0..self.w];
            std.debug.print("({s})\n", .{s});
        }

        // Print energy
        std.debug.print("{any} \n", .{self.power});

        std.debug.print("\n", .{});
    }
};

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
    const filepath = "testinput";
    const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        const m = try Machine.fromStr(line);
        try m.print();
    }
    print("{s}\n", .{contents});
}
