const position = @import("./position.zig");
const perft = @import("./perft.zig").perft;
const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const evaluate = @import("evaluate.zig").evaluate;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

test "move generation nodes per second" {
    const timer = std.time.Timer.start() catch unreachable;
    expect(perft(&fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), 5) == 4865609);

    std.debug.print("NPS: {}\n", .{@floatToInt(u64, @intToFloat(f64, 4865609) / (@intToFloat(f64, timer.read()) / @intToFloat(f64, std.time.ns_per_s)))});
}

test "evaluation nodes per second" {
    const timer = std.time.Timer.start() catch unreachable;

    var pos = position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", test_allocator) catch unreachable;

    var i: u64 = 0;
    while (i < 1000000) {
        _ = evaluate(&pos);
        i += 1;
    }

    std.debug.print("EPS: {}\n", .{@floatToInt(u64, @intToFloat(f64, 1000000) / (@intToFloat(f64, timer.read()) / @intToFloat(f64, std.time.ns_per_s)))});
}
