const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const ArrayList = std.ArrayList;

const position = @import("./position.zig");
const movegen = @import("./movegen.zig");
const generateMoves = movegen.generateMoves;

test "generateMoves - Starting position" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"));
    expect(moves.items.len == 20);
    moves.deinit();
}

test "generateMoves - King movement" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/5k2/8/8/3K4/8/8/8 w - - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Rook sliding normal" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/5k2/8/8/3R4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 14);
    moves.deinit();
}

test "generateMoves - Rook attacking" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("3p4/5k2/8/8/1p1R2p1/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 12);
    moves.deinit();
}

test "generateMoves - Bishop sliding normal" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/8/3B4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 13);
    moves.deinit();
}

test "generateMoves - Queen sliding normal" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/8/3Q4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 27);
    moves.deinit();
}

test "generateMoves - Knight in centre" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/8/3N4/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Knight on edge" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/8/N7/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Pawn at start" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/8/8/8/3P4/8 w KQkq - 0 1"));
    expect(moves.items.len == 2);
    moves.deinit();
}

test "generateMoves - Pawn after moving" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/8/8/3P4/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 1);
    moves.deinit();
}

test "generateMoves - Pawn captures" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("7k/8/8/8/8/2p1p3/3P4/8 w KQkq - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - En passant capture" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/3Pp3/8/8/8/8 w KQkq e6 0 1"));
    expect(moves.items.len == 2);
    moves.deinit();
}

test "generateMoves - Two en passant options" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/7k/8/3PpP2/8/8/8/8 w KQkq e6 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Black pawn at start" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/4p3/8/8/8/8/8/4K3 b - - 0 1"));
    expect(moves.items.len == 2);
    moves.deinit();
}

test "generateMoves - Black pawn captures" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/4p3/3P1P2/8/8/8/8/4K3 b - - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Black two en passant options" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/8/8/8/4pPp1/8/8/4K3 b - f3 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Promotion" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/2P4k/8/8/8/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Capture promotion" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("2q4k/3P4/8/8/8/8/8/8 w KQkq - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Black promotion" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/8/8/8/8/8/2p5/4K3 b - - 0 1"));
    expect(moves.items.len == 4);
    moves.deinit();
}

test "generateMoves - Kingside castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/5k2/8/8/8/8/8/4K2R w K - 0 1"));
    expect(moves.items.len == 15);
    moves.deinit();
}

test "generateMoves - Both side castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/5k2/8/8/8/8/8/R3K2R w KQ - 0 1"));
    expect(moves.items.len == 26);
    moves.deinit();
}

test "generateMoves - No castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/5k2/8/8/8/8/8/1R2K1R1 w - - 0 1"));
    expect(moves.items.len == 24);
    moves.deinit();
}

test "generateMoves - Black kingside castle" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("r2k4/8/8/8/8/8/8/4K3 b k - 0 1"));
    expect(moves.items.len == 15);
    moves.deinit();
}

test "generateMoves - Black king" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("8/5k2/8/8/8/8/8/1R2K1R1 b - - 0 1"));
    expect(moves.items.len == 8);
    moves.deinit();
}

test "generateMoves - Can't castle through check" {
    var moves = ArrayList(u32).init(test_allocator);
    generateMoves(&moves, position.fromFEN("6q1/8/8/8/8/8/8/4K2R w Kkq - 0 1"));
    expect(moves.items.len == 14);
    moves.deinit();
}

