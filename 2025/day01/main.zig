const std = @import("std");
const ArrayList = std.ArrayList;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const file = std.fs.cwd().openFile(
        "./2025/day01/input",
        .{ .mode = .read_only },
    ) catch |err| {
        std.debug.print("{any}", .{err});
        return;
    };

    var read_buf: [4096]u8 = undefined;
    var line_buf: [1024]u8 = undefined;

    var reader_obj = file.reader(&read_buf);
    var r = &reader_obj.interface;

    while (true) {
        var w: std.Io.Writer = .fixed(&line_buf);

        const bytes_read = try r.streamDelimiterEnding(&w, '\n');

        if (bytes_read == 0) break; // EOF
        const line = w.buffered();
        std.debug.print("Line: {s}\n", .{line});

        // Only toss if we successfully peeked (not at EOF)
        _ = r.peek(1) catch break; // EOF check
        r.toss(1); // Skip delimiter
    }

    defer file.close();
}
