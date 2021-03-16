const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const ArrayList = std.ArrayList;

const position = @import("./position.zig");
const movegen = @import("./movegen.zig");
const Color = @import("./piece.zig").Color;
const generateMoves = movegen.generateMoves;
const generateLegalMoves = movegen.generateLegalMoves;
const isKingInCheck = movegen.isKingInCheck;
const countNonNullMoves = movegen.countNonNullMoves;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f) catch unreachable;
}

test "generateMoves - Starting position" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"));
    expect(moves.items.len == 20);
    moves.deinit();
}

test "generateMoves - King movement" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/5k2/8/8/3K4/8/8/8 w - - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Rook sliding normal" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/5k2/8/8/3R4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 14);
    moves.deinit();
}

test "generateMoves - Rook attacking" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("3p4/5k2/8/8/1p1R2p1/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 12);
    moves.deinit();
}

test "generateMoves - Bishop sliding normal" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/8/3B4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 13);
    moves.deinit();
}

test "generateMoves - Queen sliding normal" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/8/3Q4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 27);
    moves.deinit();
}

test "generateMoves - Knight in centre" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/8/3N4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Knight on edge" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/8/N7/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Pawn at start" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/8/8/8/3P4/8 w KQkq - 0 1"));
    expect(moves.items.len == 2);
    moves.deinit();
}

test "generateMoves - Pawn after moving" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/8/8/3P4/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 1);
    moves.deinit();
}

test "generateMoves - Pawn captures" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("7k/8/8/8/8/2p1p3/3P4/8 w KQkq - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - En passant capture" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/3Pp3/8/8/8/8 w KQkq e6 0 1"));
    expect(moves.items.len == 2);
    moves.deinit();
}

test "generateMoves - Two en passant options" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/7k/8/3PpP2/8/8/8/8 w KQkq e6 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Black pawn at start" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/4p3/8/8/8/8/8/4K3 b - - 0 1"));
    expect(moves.items.len == 2);
    moves.deinit();
}

test "generateMoves - Black pawn captures" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/4p3/3P1P2/8/8/8/8/4K3 b - - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Black two en passant options" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/8/8/8/4pPp1/8/8/4K3 b - f3 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Promotion" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/2P4k/8/8/8/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Capture promotion" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("2q4k/3P4/8/8/8/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Black promotion" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/8/8/8/8/8/2p5/4K3 b - - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Kingside castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/5k2/8/8/8/8/8/4K2R w K - 0 1"));
    expect(moves.items.len == 15);
    moves.deinit();
}

test "generateMoves - Both side castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/5k2/8/8/8/8/8/R3K2R w KQ - 0 1"));
    expect(moves.items.len == 26);
    moves.deinit();
}

test "generateMoves - No castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/5k2/8/8/8/8/8/1R2K1R1 w - - 0 1"));
    expect(moves.items.len == 24);
    moves.deinit();
}

test "generateMoves - Black kingside castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("r2k4/8/8/8/8/8/8/4K3 b k - 0 1"));
    expect(moves.items.len == 15);
    moves.deinit();
}

test "generateMoves - Black king" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("8/5k2/8/8/8/8/8/1R2K1R1 b - - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Can't castle through check" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, fromFEN("6q1/8/8/8/8/8/8/4K2R w Kkq - 0 1"));
    expect(moves.items.len == 14);
    moves.deinit();
}

test "generateLegalMoves - JetChess 1" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"));
    expect(countNonNullMoves(&moves) == 48);
    moves.deinit();
}

test "generateLegalMoves - JetChess 2" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"));
    expect(countNonNullMoves(&moves) == 14);
    moves.deinit();
}

test "generateLegalMoves - JetChess 3" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("n1rb4/1p3p1p/1p6/1R5K/8/p3p1PN/1PP1R3/N6k w - - 0 1"));
    expect(countNonNullMoves(&moves) == 28);
    moves.deinit();
}

test "generateLegalMoves - JetChess 4" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("5RKb/4P1n1/2p4p/3p2p1/3B2Q1/5B2/r6k/4r3 w - - 0 1"));
    expect(countNonNullMoves(&moves) == 47);
    moves.deinit();
}

test "generateLegalMoves - JetChess 5" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("7r/3B4/k7/8/6Qb/8/Kn6/6R1 w - - 0 1"));
    expect(countNonNullMoves(&moves) == 41);
    moves.deinit();
}

test "generateLegalMoves - JetChess 6" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("b1N1rb2/3p4/r6p/2Pp1p1K/3Pk3/2PN1p2/2B2P2/8 w - - 0 1"));
    expect(countNonNullMoves(&moves) == 17);
    moves.deinit();
}

test "generateLegalMoves - Jetchess 7" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("1kN2bb1/4r1r1/Q1P1p3/8/6n1/8/8/2B1K2B w - - 0 1"));
    expect(countNonNullMoves(&moves) == 34);
    moves.deinit();
}

test "generateLegalMoves - Jetchess 8" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("8/8/7K/6p1/NN5k/8/6PP/8 w - - 0 1"));
    expect(countNonNullMoves(&moves) == 16);
    moves.deinit();
}

test "generateLegalMoves - Jetchess 9" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("8/2p5/2Pb4/2pp3R/1ppk1pR1/2n2P1p/1B2PPpP/K7 w - - 0 1"));
    expect(countNonNullMoves(&moves) == 22);
    moves.deinit();
}

test "generateLegalMoves - Jetchess 10" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("8/6pp/8/p5p1/Pp6/1P3p2/pPK4P/krQ4R w - - 0 1"));
    expect(countNonNullMoves(&moves) == 18);
    moves.deinit();
}

test "generateLegalMoves - Jetchess 11" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("rnbqkbnr/ppp1pppp/8/3p4/2P5/8/PP1PPPPP/RNBQKBNR w KQkq - 0 2"));
    expect(countNonNullMoves(&moves) == 23);
    moves.deinit();
}

test "generateLegalMoves - Jetchess 12" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("rnbqkbnr/ppp1pppp/8/3p4/Q1P5/8/PP1PPPPP/RNB1KBNR b KQkq - 1 2"));
    expect(countNonNullMoves(&moves) == 6);
    moves.deinit();
}

test "generateLegalMoves - Checkmate" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("rnb1kbnr/pppp1ppp/8/4p3/5PPq/8/PPPPP2P/RNBQKBNR w KQkq - 1 3"));
    expect(countNonNullMoves(&moves) == 0);
    moves.deinit();
}

test "generateLegalMoves - Check from king" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("8/8/8/8/k7/2p5/2KP4/7R b - - 1 2"));
    expect(countNonNullMoves(&moves) == 5);
    moves.deinit();
}

test "generateLegalMoves - Weird check" {
    var moves = ArrayList(u32).init(test_allocator);
    generateLegalMoves(&moves, &fromFEN("8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3"));
    expect(countNonNullMoves(&moves) == 12);
    moves.deinit();
}

test "isKingInCheck" {
    expect(isKingInCheck(fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), Color.white) == false);
    expect(isKingInCheck(fromFEN("rnbqkb1r/ppp1pp1p/6p1/1B1n4/3P4/2N5/PP2PPPP/R1BQK1NR b KQkq - 0 1"), Color.black) == true);
    expect(isKingInCheck(fromFEN("rnbq1b1r/pppkpppp/3pPn2/8/2PP4/8/PP3PPP/RNBQKBNR w KQkq - 0 1"), Color.white) == false);
    expect(isKingInCheck(fromFEN("rnbq1b1r/pppkpppp/3pPn2/8/2PP4/8/PP3PPP/RNBQKBNR b KQkq - 0 1"), Color.black) == true);
}