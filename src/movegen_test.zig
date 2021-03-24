const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const test_allocator = std.testing.allocator;
const ArrayList = std.ArrayList;
const Move = @import("./move.zig").Move;
const position = @import("./position.zig");
const movegen = @import("./movegen.zig");
const attack = @import("./attack.zig");
const Color = @import("./color.zig").Color;
const generateMoves = movegen.generateMoves;
const generateLegalMoves = movegen.generateLegalMoves;
const isKingInCheck = movegen.isKingInCheck;
const countNonNullMoves = movegen.countNonNullMoves;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

test "generateMoves - Starting position" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 20), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - King movement" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/5k2/8/8/3K4/8/8/8 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 8), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Rook sliding normal" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/5k2/8/8/3R4/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 17), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Rook attacking" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("3p4/5k2/8/8/1p1R2p1/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 15), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Bishop sliding normal" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/8/3B4/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 15), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Queen sliding normal" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/8/3Q4/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 29), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Knight in centre" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/8/3N4/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 11), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Knight on edge" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/8/N7/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Pawn at start" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/8/8/8/3P4/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 5), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Pawn after moving" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/8/8/3P4/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 4), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Pawn captures" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("7k/8/8/8/8/2p1p3/3P4/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - En passant capture" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/3Pp3/8/8/8/K7 w - e6 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 5), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Two en passant options" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/7k/8/3PpP2/8/8/8/K7 w - e6 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Black pawn at start" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("k7/4p3/8/8/8/8/8/4K3 b - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 5), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Black pawn captures" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("k7/4p3/3P1P2/8/8/8/8/4K3 b - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Black two en passant options" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("k7/8/8/8/4pPp1/8/8/4K3 b - f3 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Promotion" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/2P4k/8/8/8/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Capture promotion" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("2q4k/3P4/8/8/8/8/8/K7 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 11), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Black promotion" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("k7/8/8/8/8/8/2p5/4K3 b - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 7), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Kingside castle" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/5k2/8/8/8/8/8/4K2R w K - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 15), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Both side castle" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/5k2/8/8/8/8/8/R3K2R w KQ - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 26), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - No castle" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/5k2/8/8/8/8/8/1R2K1R1 w - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 24), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Black kingside castle" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("r2k4/8/8/8/8/8/8/4K3 b k - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 15), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Black king" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/5k2/8/8/8/8/8/1R2K1R1 b - - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 8), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateMoves - Can't castle through check" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("k5q1/8/8/8/8/8/8/4K2R w K - 0 1");
    generateMoves(&moves, &pos);
    expectEqual(@as(u32, 14), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - JetChess 1" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 48), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - JetChess 2" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 14), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - JetChess 3" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("n1rb4/1p3p1p/1p6/1R5K/8/p3p1PN/1PP1R3/N6k w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 28), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - JetChess 4" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("5RKb/4P1n1/2p4p/3p2p1/3B2Q1/5B2/r6k/4r3 w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 47), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - JetChess 5" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("7r/3B4/k7/8/6Qb/8/Kn6/6R1 w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 41), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - JetChess 6" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("b1N1rb2/3p4/r6p/2Pp1p1K/3Pk3/2PN1p2/2B2P2/8 w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 17), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Jetchess 7" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("1kN2bb1/4r1r1/Q1P1p3/8/6n1/8/8/2B1K2B w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 34), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Jetchess 8" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/8/7K/6p1/NN5k/8/6PP/8 w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 16), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Jetchess 9" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/2p5/2Pb4/2pp3R/1ppk1pR1/2n2P1p/1B2PPpP/K7 w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 22), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Jetchess 10" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/6pp/8/p5p1/Pp6/1P3p2/pPK4P/krQ4R w - - 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 18), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Jetchess 11" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("rnbqkbnr/ppp1pppp/8/3p4/2P5/8/PP1PPPPP/RNBQKBNR w KQkq - 0 2");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 23), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Jetchess 12" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("rnbqkbnr/ppp1pppp/8/3p4/Q1P5/8/PP1PPPPP/RNB1KBNR b KQkq - 1 2");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 6), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Checkmate" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("rnb1kbnr/pppp1ppp/8/4p3/5PPq/8/PPPPP2P/RNBQKBNR w KQkq - 1 3");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 0), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Check from king" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/8/8/8/k7/2p5/2KP4/7R b - - 1 2");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 5), countNonNullMoves(&moves));
    moves.deinit();
}

test "generateLegalMoves - Weird check" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 12), countNonNullMoves(&moves));
    moves.deinit();
}


test "generateLegalMoves - Buggy position" {
    var moves = ArrayList(?Move).init(test_allocator);
    var pos = fromFEN("rnbqkbnr/ppppppp1/8/7p/6P1/8/PPPPPP1P/RNBQKBNR w KQkq h6 0 1");
    generateLegalMoves(&moves, &pos);
    expectEqual(@as(u32, 22), countNonNullMoves(&moves));
    moves.deinit();
}

test "isKingInCheck" {
    var pos = fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    var attack_map = attack.generateAttackMap(&pos, Color.black);
    expect(isKingInCheck(pos, Color.white, attack_map) == false);

    pos = fromFEN("rnbqkb1r/ppp1pp1p/6p1/1B1n4/3P4/2N5/PP2PPPP/R1BQK1NR b KQkq - 0 1");
    attack_map = attack.generateAttackMap(&pos, Color.white);
    expect(isKingInCheck(pos, Color.black, attack_map) == true);

    pos = fromFEN("rnbq1b1r/pppkpppp/3pPn2/8/2PP4/8/PP3PPP/RNBQKBNR w KQkq - 0 1");
    attack_map = attack.generateAttackMap(&pos, Color.black);
    expect(isKingInCheck(pos, Color.white, attack_map) == false);

    pos = fromFEN("rnbq1b1r/pppkpppp/3pPn2/8/2PP4/8/PP3PPP/RNBQKBNR b KQkq - 0 1");
    attack_map = attack.generateAttackMap(&pos, Color.white);
    expect(isKingInCheck(pos, Color.black, attack_map) == true);
}