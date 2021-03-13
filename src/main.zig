const std = @import("std");
const File = std.fs.File;

// From https://ziglearn.org/chapter-2/#readers-and-writers
fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    var line: []const u8 = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;

    if (std.builtin.Target.current.os.tag == .windows) {
        line = std.mem.trimRight(u8, line[0..], "\r");
    }

    return line;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();
    const stdin = std.io.getStdIn();

    var quit: bool = false;

    var buffer: [300]u8 = undefined;

    while (!quit) {
        const input = (try nextLine(stdin.reader(), &buffer)).?;
        try stderr.writer().print(
            "Command: \"{s}\"\n",
            .{input},
        );

        if (std.mem.eql(u8, input, "quit")) {
            quit = true;
        }

        try handleCommand(input, stdout);
    }
}

fn handleCommand(input: []const u8, stdout: File) !void {
    if (std.mem.eql(u8, input, "uci")) {
        try stdout.writer().print(
            "id name Riptide\nid author Cadel Watson\nuciok\n",
            .{},
        );
    }
}
