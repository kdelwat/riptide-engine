const std = @import("std");
const File = std.fs.File;

pub const Logger = struct {
    f: File,
    out: File, // stdout for replying to UCI engine

    pub fn init() Logger {
        return Logger{
            .f = std.io.getStdErr(),
            .out = std.io.getStdOut(),
        };
    }

    pub fn initFile(abs_path: []const u8) !Logger {
        const f: File = try std.fs.createFileAbsolute(
            abs_path,
            .{ .read = true },
        );

        return Logger{
            .f = f,
            .out = std.io.getStdOut(),
        };
    }

    pub fn deinit(self: Logger) void {
        self.f.close();
    }

    pub fn incoming(self: Logger, comptime format: []const u8, args: anytype) !void {
        try self.f.writer().print("==> " ++ format ++ "\n", args);
    }

    pub fn outgoing(self: Logger, comptime format: []const u8, args: anytype) !void {
        try self.f.writer().print("<== " ++ format ++ "\n", args);
        try self.out.writer().print(format ++ "\n", args);
    }

    pub fn log(self: Logger, comptime component: []const u8, comptime format: []const u8, args: anytype) !void {
        try self.f.writer().print("??? [" ++ component ++ "] " ++ format ++ "\n", args);
    }
};