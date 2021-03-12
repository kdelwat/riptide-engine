const position = @import("./position.zig");
const move = @import("./move.zig");
const make_move = @import("./make_move.zig");
const movegen = @import("./movegen.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// perft is a performance test for the move generation function. It generates a
// move tree to a given depth, recording various information. This information can
// be compared to known results to determine if the move generation is behaving
// correctly.

pub const PerftResults = struct {
    nodes           : u64,
    quiet           : u64,
    captures        : u64,
    enpassant       : u64,
    promotion       : u64,
    promo_capture    : u64,
    castle_king_side  : u64,
    castle_queen_side : u64,
    pawn_jump        : u64,
    checks          : u64,
};

// Run a perft analysis of the position to the given depth. This function is
// based on the C code at https://chessprogramming.wikispaces.com/Perft
pub fn perft(pos: *position.Position, depth: u64, a: *Allocator) PerftResults {
    var results = PerftResults{
        .nodes = 0,
        .quiet = 0,
        .captures = 0,
        .enpassant = 0,
        .promotion = 0,
        .promo_capture = 0,
        .castle_king_side = 0,
        .castle_queen_side = 0,
        .pawn_jump = 0,
        .checks = 0,
    };

    // If the end of the tree is reached, increment the number of nodes found.
    if (depth == 0) {
        return PerftResults{
           .nodes = 1,
           .quiet = 0,
           .captures = 0,
           .enpassant = 0,
           .promotion = 0,
           .promo_capture = 0,
           .castle_king_side = 0,
           .castle_queen_side = 0,
           .pawn_jump = 0,
           .checks = 0,
       };
    }

    // Generate all moves for the position.
    var moves = ArrayList(u32).init(a);
    defer moves.deinit();
    movegen.generateMoves(&moves, pos.*);

    var checked: u8 = 0;

    // Make each move, recording information about the move.
    // TODO: maybe use generateLegalMoves above and increment checked when move == NULL_MOVE?
    for (moves.items) |m| {
        var current_player = pos.to_move;
        const artifacts = make_move.makeMove(pos, m);

        if (!movegen.isKingInCheck(pos.*, current_player)) {
            if (move.isQuiet(m)) {
                results.quiet += 1;
            } else if (move.isQueenCastle(m)) {
                results.castle_queen_side += 1;
            } else if (move.isKingCastle(m)) {
                results.castle_king_side += 1;
            } else if (move.isPromotionCapture(m)) {
                results.promo_capture += 1;
            } else if (move.isPromotion(m)) {
                results.promotion += 1;
            } else if (move.isEnPassantCapture(m)) {
                results.enpassant += 1;
            } else if (move.isDoublePawnPush(m)) {
                results.pawn_jump += 1;
            } else if (move.isCapture(m)) {
                results.captures += 1;
            }

            const next_level_results = perft(pos, depth - 1, a);
            results.nodes += next_level_results.nodes;
            results.quiet += next_level_results.quiet;
            results.captures += next_level_results.captures;
            results.enpassant += next_level_results.enpassant;
            results.promotion += next_level_results.promotion;
            results.promo_capture += next_level_results.promo_capture;
            results.castle_king_side += next_level_results.castle_king_side;
            results.castle_queen_side += next_level_results.castle_queen_side;
            results.pawn_jump += next_level_results.pawn_jump;
            results.checks += next_level_results.checks;
        } else {
            checked += 1;
        }

        make_move.unmakeMove(pos, m, artifacts);
    }

    // If every move results in a check, return an empty statistics list, since
    // the game has ended and there are no nodes to record.
    if (checked == moves.items.len) {
        return PerftResults{
           .nodes = 0,
           .quiet = 0,
           .captures = 0,
           .enpassant = 0,
           .promotion = 0,
           .promo_capture = 0,
           .castle_king_side = 0,
           .castle_queen_side = 0,
           .pawn_jump = 0,
           .checks = 0,
       };
    }

    return results;
}