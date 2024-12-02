const std = @import("std");

pub fn main() void {
    const file = std.fs.cwd().openFile("./2024/day01/testinput", .{ .mode = .read_only }) catch |err| {
        std.debug.print("{any}", .{err});
        return;
    };
    defer file.close();

    var arr: [100]u8 = undefined;
    while (file.reader().readUntilDelimiterOrEof(&arr, '\n')) |result| {
        if (result != null) {
            std.debug.print("{s}\n", .{result.?});
        }
    } else |err| {
        std.debug.print("{any}", .{err});
    }
}
