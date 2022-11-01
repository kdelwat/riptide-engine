const std = @import("std");
const Zobrist = @import("./Zobrist.zig").Zobrist;
const Position = @import("position").Position;
const position = @import("position");
const testing = std.testing;
const test_allocator = std.testing.allocator;

fn initPos(f: []const u8) Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

test "zobrist hashing" {
    var zobrist = Zobrist.init(1);
    var pos = initPos("8/8/8/8/8/8/8/8 w KQkq - 0 1");

    try testing.expectEqual(zobrist.hash(pos), 1);
}
