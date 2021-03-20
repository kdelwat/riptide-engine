const position = @import("./position.zig");
const perft = @import("./perft.zig").perft;
const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f) catch unreachable;
}

test "move generation nodes per second" {
    const timer = std.time.Timer.start() catch unreachable;
    expect(perft(&fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), 5, test_allocator).nodes == 4865609);
    std.debug.print("NPS: {}\n", .{4865609 / (timer.read() / std.time.ns_per_s)});
}
