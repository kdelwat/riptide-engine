const position = @import("./position.zig");
const perft = @import("./perft.zig").perft;
const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

// Martin Sedlak's test positions
// (http://www.talkchess.com/forum/viewtopic.php?t=47318)
// code copied from Evert Glebbeek at http://www.talkchess.com/forum/viewtopic.php?topic_view=threads&p=657840&t=59046

test "starting position" {
    expect(perft(&position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), 5, test_allocator).nodes == 4865609);
}

test "avoid illegal ep" {
    expect(perft(&position.fromFEN("3k4/3p4/8/K1P4r/8/8/8/8 b - - 0 1"), 6, test_allocator).nodes == 1134888);
    expect(perft(&position.fromFEN("8/8/8/8/k1p4R/8/3P4/3K4 w - - 0 1"), 6, test_allocator).nodes == 1134888);
    expect(perft(&position.fromFEN("8/8/4k3/8/2p5/8/B2P2K1/8 w - - 0 1"), 6, test_allocator).nodes == 1015133);
    expect(perft(&position.fromFEN("8/b2p2k1/8/2P5/8/4K3/8/8 b - - 0 1"), 6, test_allocator).nodes == 1015133);
}

test "en passant capture checks opponent" {
    expect(perft(&position.fromFEN("8/8/1k6/2b5/2pP4/8/5K2/8 b - d3 0 1"), 6, test_allocator).nodes == 1440467);
    expect(perft(&position.fromFEN("8/5k2/8/2Pp4/2B5/1K6/8/8 w - d6 0 1"), 6, test_allocator).nodes == 1440467);
}

test "short castling gives check" {
    expect(perft(&position.fromFEN("5k2/8/8/8/8/8/8/4K2R w K - 0 1"), 6, test_allocator).nodes == 661072);
    expect(perft(&position.fromFEN("4k2r/8/8/8/8/8/8/5K2 b k - 0 1"), 6, test_allocator).nodes == 661072);
}

test "long castling gives check" {
    expect(perft(&position.fromFEN("3k4/8/8/8/8/8/8/R3K3 w Q - 0 1"), 6, test_allocator).nodes == 803711);
    expect(perft(&position.fromFEN("r3k3/8/8/8/8/8/8/3K4 b q - 0 1"), 6, test_allocator).nodes == 803711);
}

test "castling (including losing cr due to rook capture)" {
    expect(perft(&position.fromFEN("r3k2r/1b4bq/8/8/8/8/7B/R3K2R w KQkq - 0 1"), 4, test_allocator).nodes == 1274206);
    expect(perft(&position.fromFEN("r3k2r/7b/8/8/8/8/1B4BQ/R3K2R b KQkq - 0 1"), 4, test_allocator).nodes == 1274206);
}

test "castling prevented" {
    expect(perft(&position.fromFEN("r3k2r/8/3Q4/8/8/5q2/8/R3K2R b KQkq - 0 1"), 4, test_allocator).nodes == 1720476);
    expect(perft(&position.fromFEN("r3k2r/8/5Q2/8/8/3q4/8/R3K2R w KQkq - 0 1"), 4, test_allocator).nodes == 1720476);
}

test "promote out of check" {
    expect(perft(&position.fromFEN("2K2r2/4P3/8/8/8/8/8/3k4 w - - 0 1"), 6, test_allocator).nodes == 3821001);
    expect(perft(&position.fromFEN("3K4/8/8/8/8/8/4p3/2k2R2 b - - 0 1"), 6, test_allocator).nodes == 3821001);
}

test "discovered check" {
    expect(perft(&position.fromFEN("8/8/1P2K3/8/2n5/1q6/8/5k2 b - - 0 1"), 5, test_allocator).nodes == 1004658);
    expect(perft(&position.fromFEN("5K2/8/1Q6/2N5/8/1p2k3/8/8 w - - 0 1"), 5, test_allocator).nodes == 1004658);
}

test "promote to give check" {
    expect(perft(&position.fromFEN("4k3/1P6/8/8/8/8/K7/8 w - - 0 1"), 6, test_allocator).nodes == 217342);
    expect(perft(&position.fromFEN("8/k7/8/8/8/8/1p6/4K3 b - - 0 1"), 6, test_allocator).nodes == 217342);
}

test "underpromote to check" {
    expect(perft(&position.fromFEN("8/P1k5/K7/8/8/8/8/8 w - - 0 1"), 6, test_allocator).nodes == 92683);
    expect(perft(&position.fromFEN("8/8/8/8/8/k7/p1K5/8 b - - 0 1"), 6, test_allocator).nodes == 92683);
}

test "self stalemate" {
    expect(perft(&position.fromFEN("K1k5/8/P7/8/8/8/8/8 w - - 0 1"), 6, test_allocator).nodes == 2217);
    expect(perft(&position.fromFEN("8/8/8/8/8/p7/8/k1K5 b - - 0 1"), 6, test_allocator).nodes == 2217);
}

test "stalemate/checkmate" {
    expect(perft(&position.fromFEN("8/k1P5/8/1K6/8/8/8/8 w - - 0 1"), 7, test_allocator).nodes == 567584);
    expect(perft(&position.fromFEN("8/8/8/8/1k6/8/K1p5/8 b - - 0 1"), 7, test_allocator).nodes == 567584);
}

test "double check" {
    expect(perft(&position.fromFEN("8/8/2k5/5q2/5n2/8/5K2/8 b - - 0 1"), 4, test_allocator).nodes == 23527);
    expect(perft(&position.fromFEN("8/5k2/8/5N2/5Q2/2K5/8/8 w - - 0 1"), 4, test_allocator).nodes == 23527);
}

test "short castling impossible although the rook never moved away from its corner" {
    expect(perft(&position.fromFEN("1k6/1b6/8/8/7R/8/8/4K2R b K - 0 1"), 5, test_allocator).nodes == 1063513);
    expect(perft(&position.fromFEN("4k2r/8/8/7r/8/8/1B6/1K6 w k - 0 1"), 5, test_allocator).nodes == 1063513);
}

test "long castling impossible although the rook never moved away from its corner" {
    expect(perft(&position.fromFEN("1k6/8/8/8/R7/1n6/8/R3K3 b Q - 0 1"), 5, test_allocator).nodes == 346695);
    expect(perft(&position.fromFEN("r3k3/8/1N6/r7/8/8/8/1K6 w q - 0 1"), 5, test_allocator).nodes == 346695);
}