const std = @import("std");
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

const LineIterator = struct {
    reader: *std.Io.Reader,
    line_buf: []u8,

    pub fn next(self: *LineIterator) !?[]const u8 {
        // Your existing logic here
        // Return null at EOF
        var r = self.reader;
        var w: std.Io.Writer = .fixed(self.line_buf);
        const bytes_read = try r.streamDelimiterEnding(&w, '\n');
        if (bytes_read == 0) return null; // EOF
        const line = w.buffered();
        // Only toss if we successfully peeked (not at EOF)
        _ = r.peek(1) catch return line; // EOF check
        r.toss(1); // Skip delimiter
        return line;
    }
};

const FileLines = struct {
    file: std.fs.File,
    reader_obj: std.fs.File.Reader,
    iterator: LineIterator,

    pub fn init(path: []const u8, read_buf: []u8, line_buf: []u8) !FileLines {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        const reader_obj = file.reader(read_buf);

        return FileLines{
            .file = file,
            .reader_obj = reader_obj,
            .iterator = LineIterator{
                .reader = undefined, // Will be set by setupIterator
                .line_buf = line_buf,
            },
        };
    }

    pub fn setupIterator(self: *FileLines) void {
        self.iterator.reader = &self.reader_obj.interface;
    }

    pub fn deinit(self: *FileLines) void {
        self.file.close();
    }
};

pub fn main() !void {
    var read_buf: [4096]u8 = undefined;
    var line_buf: [1024]u8 = undefined;
    var file_lines = try FileLines.init("2025/day01/testinput", read_buf[0..], line_buf[0..]);
    file_lines.setupIterator(); // Set the pointer to the correct location
    defer file_lines.deinit();

    while (try file_lines.iterator.next()) |line| {
        std.debug.print("Line: {s}\n", .{line});
    }
}
