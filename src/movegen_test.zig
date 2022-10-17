const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const test_allocator = std.testing.allocator;
const ArrayList = std.ArrayList;
const Move = @import("./move.zig").Move;
const position = @import("./position.zig");
const MoveGenerator = @import("./movegen.zig").MoveGenerator;
const isKingInCheck = @import("./movegen.zig").isKingInCheck;
const attack = @import("./attack.zig");
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

const LegalMovegenTestCase = struct {
    position: []const u8,
    expected: u64,
};

var LEGAL_MOVE_TEST_CASES = [41]LegalMovegenTestCase{
    // Starting position
    LegalMovegenTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .expected = 20 },
    // King movement
    LegalMovegenTestCase{ .position = "8/5k2/8/8/3K4/8/8/8 w - - 0 1", .expected = 8 },
    // Rook sliding normal
    LegalMovegenTestCase{ .position = "8/5k2/8/8/3R4/8/8/K7 w - - 0 1", .expected = 17 },
    // Rook attacking
    LegalMovegenTestCase{ .position = "3p4/5k2/8/8/1p1R2p1/8/8/K7 w - - 0 1", .expected = 15 },
    // Bishop sliding normal
    LegalMovegenTestCase{ .position = "8/7k/8/8/3B4/8/8/K7 w - - 0 1", .expected = 15 },
    // Queen sliding normal
    LegalMovegenTestCase{ .position = "8/7k/8/8/3Q4/8/8/K7 w - - 0 1", .expected = 29 },
    // Knight in centre
    LegalMovegenTestCase{ .position = "8/7k/8/8/3N4/8/8/K7 w - - 0 1", .expected = 11 },
    // Knight on edge
    LegalMovegenTestCase{ .position = "8/7k/8/8/N7/8/8/K7 w - - 0 1", .expected = 7 },
    // Pawn at start
    LegalMovegenTestCase{ .position = "8/7k/8/8/8/8/3P4/K7 w - - 0 1", .expected = 5 },
    // Pawn after moving
    LegalMovegenTestCase{ .position = "8/7k/8/8/8/3P4/8/K7 w - - 0 1", .expected = 4 },
    // Pawn captures
    LegalMovegenTestCase{ .position = "7k/8/8/8/8/2p1p3/3P4/K7 w - - 0 1", .expected = 6 },
    // En passant capture
    LegalMovegenTestCase{ .position = "8/7k/8/3Pp3/8/8/8/K7 w - e6 0 1", .expected = 5 },
    // Two en passant options
    LegalMovegenTestCase{ .position = "8/7k/8/3PpP2/8/8/8/K7 w - e6 0 1", .expected = 7 },
    // Black pawn at start
    LegalMovegenTestCase{ .position = "k7/4p3/8/8/8/8/8/4K3 b - - 0 1", .expected = 5 },
    // Black pawn captures
    LegalMovegenTestCase{ .position = "k7/4p3/3P1P2/8/8/8/8/4K3 b - - 0 1", .expected = 7 },
    // Black two en passant options
    LegalMovegenTestCase{ .position = "k7/8/8/8/4pPp1/8/8/4K3 b - f3 0 1", .expected = 7 },
    // Promotion
    LegalMovegenTestCase{ .position = "8/2P4k/8/8/8/8/8/K7 w - - 0 1", .expected = 7 },
    // Capture promotion
    LegalMovegenTestCase{ .position = "2q4k/3P4/8/8/8/8/8/K7 w - - 0 1", .expected = 11 },
    // Black promotion
    LegalMovegenTestCase{ .position = "k7/8/8/8/8/8/2p5/4K3 b - - 0 1", .expected = 7 },
    // Kingside castle
    LegalMovegenTestCase{ .position = "8/5k2/8/8/8/8/8/4K2R w K - 0 1", .expected = 15 },
    // Both side castle
    LegalMovegenTestCase{ .position = "8/5k2/8/8/8/8/8/R3K2R w KQ - 0 1", .expected = 26 },
    // No castle
    LegalMovegenTestCase{ .position = "8/5k2/8/8/8/8/8/1R2K1R1 w - - 0 1", .expected = 24 },
    // Black kingside castle
    LegalMovegenTestCase{ .position = "4k2r/8/8/8/8/8/8/4K3 w k - 0 1", .expected = 5 },
    // Black king
    LegalMovegenTestCase{ .position = "8/5k2/8/8/8/8/8/1R2K1R1 b - - 0 1", .expected = 5 },
    // Can't castle through check
    LegalMovegenTestCase{ .position = "k5q1/8/8/8/8/8/8/4K2R w K - 0 1", .expected = 14 },
    // JetChess test cases
    LegalMovegenTestCase{ .position = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", .expected = 48 },
    LegalMovegenTestCase{ .position = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", .expected = 14 },
    LegalMovegenTestCase{ .position = "n1rb4/1p3p1p/1p6/1R5K/8/p3p1PN/1PP1R3/N6k w - - 0 1", .expected = 28 },
    LegalMovegenTestCase{ .position = "5RKb/4P1n1/2p4p/3p2p1/3B2Q1/5B2/r6k/4r3 w - - 0 1", .expected = 47 },
    LegalMovegenTestCase{ .position = "7r/3B4/k7/8/6Qb/8/Kn6/6R1 w - - 0 1", .expected = 41 },
    LegalMovegenTestCase{ .position = "b1N1rb2/3p4/r6p/2Pp1p1K/3Pk3/2PN1p2/2B2P2/8 w - - 0 1", .expected = 17 },
    LegalMovegenTestCase{ .position = "1kN2bb1/4r1r1/Q1P1p3/8/6n1/8/8/2B1K2B w - - 0 1", .expected = 34 },
    LegalMovegenTestCase{ .position = "8/8/7K/6p1/NN5k/8/6PP/8 w - - 0 1", .expected = 16 },
    LegalMovegenTestCase{ .position = "8/2p5/2Pb4/2pp3R/1ppk1pR1/2n2P1p/1B2PPpP/K7 w - - 0 1", .expected = 22 },
    LegalMovegenTestCase{ .position = "8/6pp/8/p5p1/Pp6/1P3p2/pPK4P/krQ4R w - - 0 1", .expected = 18 },
    LegalMovegenTestCase{ .position = "rnbqkbnr/ppp1pppp/8/3p4/2P5/8/PP1PPPPP/RNBQKBNR w KQkq - 0 2", .expected = 23 },
    LegalMovegenTestCase{ .position = "rnbqkbnr/ppp1pppp/8/3p4/Q1P5/8/PP1PPPPP/RNB1KBNR b KQkq - 1 2", .expected = 6 },
    // Checkmate
    LegalMovegenTestCase{ .position = "rnb1kbnr/pppp1ppp/8/4p3/5PPq/8/PPPPP2P/RNBQKBNR w KQkq - 1 3", .expected = 0 },
    // Weird test cases
    LegalMovegenTestCase{ .position = "8/8/8/8/k7/2p5/2KP4/7R b - - 1 2", .expected = 5 },
    LegalMovegenTestCase{ .position = "8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3", .expected = 12 },
    LegalMovegenTestCase{ .position = "rnbqkbnr/ppppppp1/8/7p/6P1/8/PPPPPP1P/RNBQKBNR w KQkq h6 0 1", .expected = 22 },
};

test "generateLegalMoves" {
    for (LEGAL_MOVE_TEST_CASES) |test_case| {
        std.debug.print("generateLegalMoves: {s}\n", .{test_case.position});
        var gen = MoveGenerator.init();
        var pos = fromFEN(test_case.position);

        gen.generate(&pos);
        try expectEqual(test_case.expected, gen.count());
    }
}

const IsKingInCheckTestCase = struct {
    position: []const u8,
    to_move: Color,
    expected: bool,
};

var KING_IN_CHECK_TEST_CASES = [4]IsKingInCheckTestCase{
    IsKingInCheckTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .to_move = Color.white, .expected = false },
    IsKingInCheckTestCase{ .position = "rnbqkb1r/ppp1pp1p/6p1/1B1n4/3P4/2N5/PP2PPPP/R1BQK1NR b KQkq - 0 1", .to_move = Color.black, .expected = true },
    IsKingInCheckTestCase{ .position = "rnbq1b1r/pppkpppp/3pPn2/8/2PP4/8/PP3PPP/RNBQKBNR w KQkq - 0 1", .to_move = Color.white, .expected = false },
    IsKingInCheckTestCase{ .position = "rnbq1b1r/pppkpppp/3pPn2/8/2PP4/8/PP3PPP/RNBQKBNR b KQkq - 0 1", .to_move = Color.black, .expected = true },
};

test "isKingInCheck" {
    for (KING_IN_CHECK_TEST_CASES) |test_case| {
        std.debug.print("isKingInCheck: {s}\n", .{test_case.position});
        var pos = fromFEN(test_case.position);
        var attack_map = attack.generateAttackMap(&pos, color.invert(test_case.to_move));
        try expectEqual(test_case.expected, isKingInCheck(pos, Color.white, attack_map));
    }
}
