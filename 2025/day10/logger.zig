const std = @import("std");

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const timestamp: u64 = @intCast(std.time.timestamp());
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = timestamp };
    const epoch_day = epoch_seconds.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch_seconds.getDaySeconds();

    const stderr = std.fs.File.stderr();
    var buf: [4096]u8 = undefined;
    var bw = stderr.writer(&buf);
    bw.interface.print("[{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}] {s}: " ++ format ++ "\n", .{
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
        @tagName(level),
    } ++ args) catch {};
    bw.interface.flush() catch {};
}
