const position = @import("./position.zig");
const perft = @import("./perft.zig").perft;
const dividePerft = @import("./perft.zig").dividePerft;
const std = @import("std");
const expectEqual = std.testing.expectEqual;
const test_allocator = std.testing.allocator;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

// Martin Sedlak's test positions
// (http://www.talkchess.com/forum/viewtopic.php?t=47318)
// code copied from Evert Glebbeek at http://www.talkchess.com/forum/viewtopic.php?topic_view=threads&p=657840&t=59046

const PerftTestCase = struct {
    position: []const u8,
    depth: u64,
    expected: u64,
};

var PERFT_TEST_CASES = [38]PerftTestCase{
    // starting position nodes
    PerftTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 1, .expected = 20 },
    PerftTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 2, .expected = 400 },
    PerftTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 3, .expected = 8902 },
    PerftTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 4, .expected = 197281 },
    PerftTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 5, .expected = 4865609 },
    PerftTestCase{ .position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .depth = 6, .expected = 119060324 },

    // avoid illegal ep
    PerftTestCase{ .position = "3k4/3p4/8/K1P4r/8/8/8/8 b - - 0 1", .depth = 6, .expected = 1134888 },
    PerftTestCase{ .position = "8/8/8/8/k1p4R/8/3P4/3K4 w - - 0 1", .depth = 6, .expected = 1134888 },
    PerftTestCase{ .position = "8/8/4k3/8/2p5/8/B2P2K1/8 w - - 0 1", .depth = 6, .expected = 1015133 },
    PerftTestCase{ .position = "8/b2p2k1/8/2P5/8/4K3/8/8 b - - 0 1", .depth = 6, .expected = 1015133 },

    // en passant capture checks opponent
    PerftTestCase{ .position = "8/8/1k6/2b5/2pP4/8/5K2/8 b - d3 0 1", .depth = 6, .expected = 1440467 },
    PerftTestCase{ .position = "8/5k2/8/2Pp4/2B5/1K6/8/8 w - d6 0 1", .depth = 6, .expected = 1440467 },

    // short castling gives check
    PerftTestCase{ .position = "5k2/8/8/8/8/8/8/4K2R w K - 0 1", .depth = 6, .expected = 661072 },
    PerftTestCase{ .position = "4k2r/8/8/8/8/8/8/5K2 b k - 0 1", .depth = 6, .expected = 661072 },

    // long castling gives check
    PerftTestCase{ .position = "3k4/8/8/8/8/8/8/R3K3 w Q - 0 1", .depth = 6, .expected = 803711 },
    PerftTestCase{ .position = "r3k3/8/8/8/8/8/8/3K4 b q - 0 1", .depth = 6, .expected = 803711 },

    // castling (including losing cr due to rook capture)
    PerftTestCase{ .position = "r3k2r/1b4bq/8/8/8/8/7B/R3K2R w KQkq - 0 1", .depth = 4, .expected = 1274206 },
    PerftTestCase{ .position = "r3k2r/7b/8/8/8/8/1B4BQ/R3K2R b KQkq - 0 1", .depth = 4, .expected = 1274206 },

    // castling prevented
    PerftTestCase{ .position = "r3k2r/8/3Q4/8/8/5q2/8/R3K2R b KQkq - 0 1", .depth = 4, .expected = 1720476 },
    PerftTestCase{ .position = "r3k2r/8/5Q2/8/8/3q4/8/R3K2R w KQkq - 0 1", .depth = 4, .expected = 1720476 },

    // promote out of check
    PerftTestCase{ .position = "2K2r2/4P3/8/8/8/8/8/3k4 w - - 0 1", .depth = 6, .expected = 3821001 },
    PerftTestCase{ .position = "3K4/8/8/8/8/8/4p3/2k2R2 b - - 0 1", .depth = 6, .expected = 3821001 },

    // discovered check
    PerftTestCase{ .position = "8/8/1P2K3/8/2n5/1q6/8/5k2 b - - 0 1", .depth = 5, .expected = 1004658 },
    PerftTestCase{ .position = "5K2/8/1Q6/2N5/8/1p2k3/8/8 w - - 0 1", .depth = 5, .expected = 1004658 },

    // promote to give check
    PerftTestCase{ .position = "4k3/1P6/8/8/8/8/K7/8 w - - 0 1", .depth = 6, .expected = 217342 },
    PerftTestCase{ .position = "8/k7/8/8/8/8/1p6/4K3 b - - 0 1", .depth = 6, .expected = 217342 },

    // underpromote to check
    PerftTestCase{ .position = "8/P1k5/K7/8/8/8/8/8 w - - 0 1", .depth = 6, .expected = 92683 },
    PerftTestCase{ .position = "8/8/8/8/8/k7/p1K5/8 b - - 0 1", .depth = 6, .expected = 92683 },

    // self stalemate
    PerftTestCase{ .position = "K1k5/8/P7/8/8/8/8/8 w - - 0 1", .depth = 6, .expected = 2217 },
    PerftTestCase{ .position = "8/8/8/8/8/p7/8/k1K5 b - - 0 1", .depth = 6, .expected = 2217 },

    // stalemate/checkmate
    PerftTestCase{ .position = "8/k1P5/8/1K6/8/8/8/8 w - - 0 1", .depth = 7, .expected = 567584 },
    PerftTestCase{ .position = "8/8/8/8/1k6/8/K1p5/8 b - - 0 1", .depth = 7, .expected = 567584 },

    // double check
    PerftTestCase{ .position = "8/8/2k5/5q2/5n2/8/5K2/8 b - - 0 1", .depth = 4, .expected = 23527 },
    PerftTestCase{ .position = "8/5k2/8/5N2/5Q2/2K5/8/8 w - - 0 1", .depth = 4, .expected = 23527 },

    // short castling impossible although the rook never moved away from its corner
    PerftTestCase{ .position = "1k6/1b6/8/8/7R/8/8/4K2R b K - 0 1", .depth = 5, .expected = 1063513 },
    PerftTestCase{ .position = "4k2r/8/8/7r/8/8/1B6/1K6 w k - 0 1", .depth = 5, .expected = 1063513 },

    // long castling impossible although the rook never moved away from its corner
    PerftTestCase{ .position = "1k6/8/8/8/R7/1n6/8/R3K3 b Q - 0 1", .depth = 5, .expected = 346695 },
    PerftTestCase{ .position = "r3k3/8/1N6/r7/8/8/8/1K6 w q - 0 1", .depth = 5, .expected = 346695 },
};

test "perft" {
    for (PERFT_TEST_CASES) |test_case| {
        std.debug.print("perft: {s} {}\n", .{ test_case.position, test_case.depth });
        try expectEqual(test_case.expected, perft(&fromFEN(test_case.position), test_case.depth));
    }
}
