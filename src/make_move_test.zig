const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

const position = @import("./position.zig");
const Move = @import("./move.zig").Move;
const MoveType = @import("./move.zig").MoveType;
const make_move = @import("./make_move.zig");
const debug = @import("./debug.zig");
const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;

fn fromFEN(f: []const u8) !position.Position {
    return position.fromFEN(f, test_allocator);
}

test "Quiet move" {
    var starting_pos = fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2") catch unreachable;
    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2") catch unreachable;
    const m = Move.initQuiet(5, 26, Color.white, PieceType.bishop);

    const artifacts = make_move.makeMove(&starting_pos, m);

    std.testing.expectEqualSlices(u64, starting_pos.board.boards[0..], expected_pos.board.boards[0..]);
    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Capture" {
    var starting_pos = fromFEN("rnbqkb1r/pppp1ppp/5n2/1B2p3/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 3 3") catch unreachable;
    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkb1r/pppp1ppp/8/1B2p3/4n3/8/PPPP1PPP/RNBQK1NR w KQkq - 0 4") catch unreachable;

    const m = Move.initCapture(45, 28, Color.black, PieceType.knight, PieceType.pawn);
    expect(m.is(MoveType.capture));

    const artifacts = make_move.makeMove(&starting_pos, m);
    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);

    expect(starting_pos.eq(starting_pos_saved));
}

test "Double pawn push" {
    var starting_pos = fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1") catch unreachable;
    const m = Move.initDoublePawnPush(12, 28, Color.white);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Promotion" {
    var starting_pos = fromFEN("rnbq1bnr/pppBP1p1/6kp/5p2/3Q4/8/PPP2PPP/RNB1K1NR w KQ - 0 9") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqQbnr/pppB2p1/6kp/5p2/3Q4/8/PPP2PPP/RNB1K1NR b KQ - 0 9") catch unreachable;
    const m = Move.initPromotion(52, 60, Color.white, PieceType.queen);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "En passant capture" {
    var starting_pos = fromFEN("rnbqkbnr/pp1p2pp/5p2/2pPp3/4P3/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkbnr/pp1p2pp/2P2p2/4p3/4P3/8/PPP2PPP/RNBQKBNR b KQkq - 0 4") catch unreachable;
    const m = Move.initEnPassant(35, 42, Color.white);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}


test "Promotion capture" {
    var starting_pos = fromFEN("rnbqkbnr/pP4pp/5p2/3pp3/4P3/8/PPP2PPP/RNBQKBNR w KQkq - 0 6") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnNqkbnr/p5pp/5p2/3pp3/4P3/8/PPP2PPP/RNBQKBNR b KQkq - 0 6") catch unreachable;
    const m = Move.initPromotionCapture(49, 58, Color.white, PieceType.knight, PieceType.bishop);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}


test "Losing castle rights from king" {
    var starting_pos = fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPPKPPP/RNBQ1BNR b kq - 1 2") catch unreachable;
    const m = Move.initQuiet(4, 12, Color.white, PieceType.king);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}


test "Losing castle rights from rook" {
    var starting_pos = fromFEN("rnbqkbnr/ppppppp1/7p/8/8/6PP/PPPPPP2/RNBQKBNR b KQkq - 0 2") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkbn1/pppppppr/7p/8/8/6PP/PPPPPP2/RNBQKBNR w KQq - 1 3") catch unreachable;
    const m = Move.initQuiet(63, 55, Color.black, PieceType.rook);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}


test "Castle queenside" {
    var starting_pos = fromFEN("rnbqkb1r/ppp1pppp/8/3p2B1/3Pn3/2N5/PPPQPPPP/R3KBNR w KQkq - 2 5") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbqkb1r/ppp1pppp/8/3p2B1/3Pn3/2N5/PPPQPPPP/2KR1BNR b kq - 3 5") catch unreachable;
    const m = Move.initQueensideCastle(Color.white);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}


test "Castle kingside" {
    var starting_pos = fromFEN("rnbqk2r/ppp2ppp/3bpB2/3p4/3PN3/8/PPPQPPPP/2KR1BNR b kq - 2 7") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("rnbq1rk1/ppp2ppp/3bpB2/3p4/3PN3/8/PPPQPPPP/2KR1BNR w - - 3 8") catch unreachable;
    const m = Move.initKingsideCastle(Color.black);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Bug: promotion" {
    var starting_pos = fromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q2/PPPBBPpP/2R1K2R b Kkq - 1 2") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q2/PPPBBP1P/2R1K1qR w Kkq - 0 3") catch unreachable;
    const m = Move.initPromotion(14, 6, Color.black, PieceType.queen);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}


test "Bug: king movement" {
    var starting_pos = fromFEN("8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("8/8/8/8/8/1k6/2Kp4/2R5 w - - 2 4") catch unreachable;
    const m = Move.initQuiet(24, 17, Color.black, PieceType.king);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Underpromotion capture" {
    var starting_pos = fromFEN("8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = fromFEN("8/8/8/8/k7/8/2K5/2b5 w - - 0 4") catch unreachable;
    const m = Move.initPromotionCapture(11, 2, Color.black, PieceType.bishop, PieceType.rook);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, m, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}