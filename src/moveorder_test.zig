const position = @import("./position.zig");
const test_allocator = std.testing.allocator;
const Color = @import("./color.zig").Color;
const expectEqual = std.testing.expectEqual;
const bitboard = @import("./bitboard.zig");
const moveorder = @import("./moveorder.zig");
const piece = @import("./piece.zig");
const Move = @import("./move.zig").Move;
const PieceType = piece.PieceType;
const std = @import("std");

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

const SEETestCase = struct {
    position: []const u8,
    move: Move,
    expected: i64,
};

// Test cases derived from traces at
// https://www.chessprogramming.org/SEE_-_The_Swap_Algorithm
var SEE_TEST_CASES = [2]SEETestCase{
    // Rxe5
    SEETestCase{ .position = "1k1r4/1pp4p/p7/4p3/8/P5P1/1PP4P/2K1R3 w KQkq - 0 1", .move = Move.initCapture(bitboard.bitboardIndex(4, 0), bitboard.bitboardIndex(4, 4), Color.white, PieceType.rook, PieceType.pawn), .expected = 100 },

    // Nxe5
    SEETestCase{ .position = "1k1r3q/1ppn3p/p4b2/4p3/8/P2N2P1/1PP1R1BP/2K1Q3 w KQkq - 0 1", .move = Move.initCapture(bitboard.bitboardIndex(3, 2), bitboard.bitboardIndex(4, 4), Color.white, PieceType.knight, PieceType.pawn), .expected = -200 },
};

test "evaluateCapture" {
    for (SEE_TEST_CASES) |test_case| {
        std.debug.print("evaluateCapture: {s}\n", .{test_case.position});
        var pos = fromFEN(test_case.position);

        const see_value = moveorder.evaluateCapture(&pos, test_case.move);
        try expectEqual(test_case.expected, see_value);
    }
}
