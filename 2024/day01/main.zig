const std = @import("std");
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const LineIterator = struct {
    file: std.fs.File,
    fbs: std.io.FixedBufferStream([]u8),
    fn next(self: *LineIterator) ![]u8 {
        try self.fbs.seekTo(0);
        try self.file.reader().streamUntilDelimiter(
            self.fbs.writer(),
            '\n',
            self.fbs.buffer.len,
        );
        return self.fbs.getWritten();
    }
};

fn lineIterator(f: std.fs.File) LineIterator {
    var buf: [4096]u8 = undefined;
    return LineIterator{
        .file = f,
        .fbs = std.io.fixedBufferStream(&buf),
    };
}

pub fn main() void {
    const file = std.fs.cwd().openFile(
        "./2024/day01/input",
        .{ .mode = .read_only },
    ) catch |err| {
        std.debug.print("{any}", .{err});
        return;
    };
    var iter = lineIterator(file);
    // var it = std.mem.split(u8, "abc123", ", ");
    while (iter.next()) |line| {
        std.debug.print("{s}\n", .{line});
    } else |err| {
        switch (err) {
            error.EndOfStream => return,
            else => std.debug.print("Error reading line {any}\n", .{err}),
        }
    }
    defer file.close();
}
