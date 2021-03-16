const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

const position = @import("./position.zig");
const move = @import("./move.zig");
const make_move = @import("./make_move.zig");
const debug = @import("./debug.zig");
const piece = @import("./piece.zig");

//    var list = std.ArrayList(u8).init(test_allocator);
  //    defer list.deinit();
  //    debug.toFEN(starting_pos, &list) catch unreachable;
  //    std.debug.print("FEN: {s}\n", .{list.items});

test "Quiet move" {
    var starting_pos = position.fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2") catch unreachable;

    const expected_pos = position.fromFEN("rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2") catch unreachable;
    const m = move.createQuietMove(5, 50);

    _ = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));
}

test "Capture" {
    var starting_pos = position.fromFEN("rnbqkb1r/pppp1ppp/5n2/1B2p3/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 3 3") catch unreachable;
    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqkb1r/pppp1ppp/8/1B2p3/4n3/8/PPPP1PPP/RNBQK1NR w KQkq - 0 4") catch unreachable;
    const m = move.createCaptureMove(85, 52);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createCaptureMove(85, 52), artifacts);

    expect(starting_pos.eq(starting_pos_saved));
}

test "Double pawn push" {
    var starting_pos = position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1") catch unreachable;
    const m = move.createDoublePawnPush(20, 52);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createDoublePawnPush(20, 52), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Promotion" {
    var starting_pos = position.fromFEN("rnbq1bnr/pppBP1p1/6kp/5p2/3Q4/8/PPP2PPP/RNB1K1NR w KQ - 0 9") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqQbnr/pppB2p1/6kp/5p2/3Q4/8/PPP2PPP/RNB1K1NR b KQ - 0 9") catch unreachable;
    const m = move.createPromotionMove(100, 116, piece.PieceType.queen);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createPromotionMove(100, 116, piece.PieceType.queen), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "En passant capture" {
    var starting_pos = position.fromFEN("rnbqkbnr/pp1p2pp/5p2/2pPp3/4P3/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqkbnr/pp1p2pp/2P2p2/4p3/4P3/8/PPP2PPP/RNBQKBNR b KQkq - 0 4") catch unreachable;
    const m = move.createEnPassantCaptureMove(67, 82);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createEnPassantCaptureMove(67, 82), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Promotion capture" {
    var starting_pos = position.fromFEN("rnbqkbnr/pP4pp/5p2/3pp3/4P3/8/PPP2PPP/RNBQKBNR w KQkq - 0 6") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnNqkbnr/p5pp/5p2/3pp3/4P3/8/PPP2PPP/RNBQKBNR b KQkq - 0 6") catch unreachable;
    const m = move.createPromotionCaptureMove(97, 114, piece.PieceType.knight);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createPromotionCaptureMove(97, 114, piece.PieceType.knight), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Losing castle rights from king" {
    var starting_pos = position.fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPPKPPP/RNBQ1BNR b kq - 1 2") catch unreachable;
    const m = move.createQuietMove(4, 20);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createQuietMove(4, 20), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Losing castle rights from rook" {
    var starting_pos = position.fromFEN("rnbqkbnr/ppppppp1/7p/8/8/6PP/PPPPPP2/RNBQKBNR b KQkq - 0 2") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqkbn1/pppppppr/7p/8/8/6PP/PPPPPP2/RNBQKBNR w KQq - 1 3") catch unreachable;
    const m = move.createQuietMove(119, 103);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createQuietMove(119, 103), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Castle queenside" {
    var starting_pos = position.fromFEN("rnbqkb1r/ppp1pppp/8/3p2B1/3Pn3/2N5/PPPQPPPP/R3KBNR w KQkq - 2 5") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbqkb1r/ppp1pppp/8/3p2B1/3Pn3/2N5/PPPQPPPP/2KR1BNR b kq - 3 5") catch unreachable;
    const m = move.QUEEN_CASTLE;

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.QUEEN_CASTLE, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Castle kingside" {
    var starting_pos = position.fromFEN("rnbqk2r/ppp2ppp/3bpB2/3p4/3PN3/8/PPPQPPPP/2KR1BNR b kq - 2 7") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("rnbq1rk1/ppp2ppp/3bpB2/3p4/3PN3/8/PPPQPPPP/2KR1BNR w - - 3 8") catch unreachable;
    const m = move.KING_CASTLE;

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.KING_CASTLE, artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Buggy case" {
    var starting_pos = position.fromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q2/PPPBBPpP/2R1K2R b Kkq - 1 2") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q2/PPPBBP1P/2R1K1qR w Kkq - 0 3") catch unreachable;
    const m = move.createPromotionMove(22, 6, piece.PieceType.queen);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createPromotionMove(22, 6, piece.PieceType.queen), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Another bug" {
    var starting_pos = position.fromFEN("8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("8/8/8/8/8/1k6/2Kp4/2R5 w - - 2 4") catch unreachable;
    const m = move.createQuietMove(48, 33);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createQuietMove(48, 33), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}

test "Underpromotion capture" {
    var starting_pos = position.fromFEN("8/8/8/8/k7/8/2Kp4/2R5 b - - 1 3") catch unreachable;

    const starting_pos_saved = starting_pos;

    const expected_pos = position.fromFEN("8/8/8/8/k7/8/2K5/2b5 w - - 0 4") catch unreachable;
    const m = move.createPromotionCaptureMove(19, 2, piece.PieceType.bishop);

    const artifacts = make_move.makeMove(&starting_pos, m);

    expect(starting_pos.eq(expected_pos));

    make_move.unmakeMove(&starting_pos, move.createPromotionCaptureMove(19, 2, piece.PieceType.bishop), artifacts);
    expect(starting_pos.eq(starting_pos_saved));
}