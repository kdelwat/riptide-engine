const std = @import("std");
const zobrist = @import("Zobrist.zig");
const Position = @import("position.zig").Position;
const position = @import("position.zig");
const testing = std.testing;
const test_allocator = std.testing.allocator;

fn initPos(f: []const u8) Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

test "zobrist hashing" {
    var pos = initPos("8/8/8/8/8/8/8/8 w KQkq - 0 1");

    try testing.expectEqual(zobrist.hash(&pos.board, pos.castling, pos.to_move, pos.en_passant_target), 17838612477224877943);
}
