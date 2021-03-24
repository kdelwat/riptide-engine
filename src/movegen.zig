const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const position = @import("./position.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const Move = @import("./move.zig").Move;
const make_move = @import("./make_move.zig");
const attack = @import("./attack.zig");
const debug = @import("./debug.zig");
const castling = @import("./castling.zig");
usingnamespace @import("./bitboard_ops.zig");

// Generate legal moves for a position.
pub fn generateLegalMoves(moves: *ArrayList(?Move), pos: *position.Position) void {
    const attacker: Color = switch (pos.to_move) {
        Color.white => Color.black,
        Color.black => Color.white,
    };

    generateMoves(moves, pos);

    const current_player = pos.to_move;

    // For each pseudo-legal move, make the move, then see if the king is in
    // check. If it isn't, the move is legal.
    for (moves.items) |opt_m, i| {
        // TODO: additional overhead not needed
        if (opt_m) |m| {
            const artifacts = make_move.makeMove(pos, m);

            const attack_map = attack.generateAttackMap(pos, attacker);
            if (isKingInCheck(pos.*, current_player, attack_map)) {
                moves.items[i] = null;
            }

            make_move.unmakeMove(pos, m, artifacts);
        }
    }
}

pub fn countNonNullMoves(moves: *ArrayList(?Move)) u32 {
    var count: u32 = 0;

    for (moves.items) |opt_m| {
        if (opt_m) |m| {
            count += 1;
        }
    }

    return count;
}

// Generate pseudo-legal moves for a position
pub fn generateMoves(moves: *ArrayList(?Move), pos: *position.Position) void {
    generatePawnMoves(moves, pos) catch unreachable;
    generatePawnCaptures(moves, pos) catch unreachable;
    generateKnightMoves(moves, pos) catch unreachable;
    generateKingMoves(moves, pos) catch unreachable;
    generateCastlingMoves(moves, pos) catch unreachable;
    generateSlidingMoves(moves, pos) catch unreachable;
}

// Generate all non-capture pawn moves, including non-capture promotions
// Works by generating a bitboard for single and double push targets, then converting
// that into a list of moves using a bitscan.
// https://www.chessprogramming.org/Pawn_Pushes_(Bitboards)#PawnPushSetwise
const RANK_4: u64 = 0x00000000FF000000;
const RANK_5: u64 = 0x000000FF00000000;

fn generatePawnMoves(moves: *ArrayList(?Move), pos: *position.Position) !void {
    const empty = pos.board.empty();
    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    var single_push = switch(pos.to_move) {
        Color.white => northOne(pawns) & pos.board.empty(),
        Color.black => southOne(pawns) & pos.board.empty(),
    };

    var double_push = switch(pos.to_move) {
        Color.white => northOne(single_push) & empty & RANK_4,
        Color.black => southOne(single_push) & empty & RANK_5,
    };

    const promotion_rank = switch(pos.to_move) {
        Color.white => @as(u8, 7),
        Color.black => @as(u8, 0),
    };

    // If the single push results in a pawn ending up on the final rank, generate
    // promotion moves. Otherwise generate a quiet push.
    while (single_push != 0) {
        const to = bitscanForwardAndReset(&single_push);
        const from = switch(pos.to_move) {
            Color.white => to - 8,
            Color.black => to + 8,
        };

        if (isOnRank(to, promotion_rank)) {
            try moves.append(Move.initPromotion(from, to, pos.to_move, PieceType.queen));
            try moves.append(Move.initPromotion(from, to, pos.to_move, PieceType.knight));
            try moves.append(Move.initPromotion(from, to, pos.to_move, PieceType.rook));
            try moves.append(Move.initPromotion(from, to, pos.to_move, PieceType.bishop));
        } else {
            try moves.append(Move.initQuiet(from, to, pos.to_move, PieceType.pawn));
        }
    }

    // Generate double push moves.
    while (double_push != 0) {
        const to = bitscanForwardAndReset(&double_push);
        const from = switch(pos.to_move) {
            Color.white => to - 16,
            Color.black => to + 16,
        };
        try moves.append(Move.initDoublePawnPush(from, to, pos.to_move));
    }
}

fn generatePawnCaptures(moves: *ArrayList(?Move), pos: *position.Position) !void {
    var opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    if (pos.en_passant_target != 0) {
        opponent_pieces |= bitboardFromIndex(pos.en_passant_target);
    }

    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    var east_captures = switch(pos.to_move) {
        Color.white => northEastOne(pawns) & opponent_pieces,
        Color.black => southEastOne(pawns) & opponent_pieces,
    };

    var west_captures = switch(pos.to_move) {
        Color.white => northWestOne(pawns) & opponent_pieces,
        Color.black => southWestOne(pawns) & opponent_pieces,
    };

    const promotion_rank = switch(pos.to_move) {
        Color.white => @as(u8, 7),
        Color.black => @as(u8, 0),
    };

    // If the capture results in a pawn ending up on the final rank, generate
    // promotion capture moves. Otherwise generate a capture move.
    while (east_captures != 0) {
        const to = bitscanForwardAndReset(&east_captures);
        const from = switch(pos.to_move) {
            Color.white => to - 9,
            Color.black => to + 7,
        };

        const captured_piece_type = pos.board.getPieceTypeAt(to);

        if (isOnRank(to, promotion_rank)) {
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type));
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type));
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type));
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type));
        } else if (to == pos.en_passant_target) {
            try moves.append(Move.initEnPassant(from, to, pos.to_move));
        } else {
            try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.pawn, captured_piece_type));
        }
    }

    while (west_captures != 0) {
        const to = bitscanForwardAndReset(&west_captures);
        const from = switch(pos.to_move) {
            Color.white => to - 7,
            Color.black => to + 9,
        };

        const captured_piece_type = pos.board.getPieceTypeAt(to);

        if (isOnRank(to, promotion_rank)) {
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type));
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type));
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type));
            try moves.append(Move.initPromotionCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type));
        } else if (to == pos.en_passant_target) {
            try moves.append(Move.initEnPassant(from, to, pos.to_move));
        } else {
            try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.pawn, captured_piece_type));
        }
    }
}

fn generateKnightMoves(moves: *ArrayList(?Move), pos: *position.Position) !void {
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));
    const empty = pos.board.empty();
    var knights = pos.board.get(PieceType.knight, pos.to_move);

    // While there are knights left to process, find the index and generate moves
    // for that knight
    while (knights != 0) {
        const from = bitscanForwardAndReset(&knights);
        const targets = attack.KNIGHT_ATTACKS[from];

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            try moves.append(Move.initQuiet(from, to, pos.to_move, PieceType.knight));
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type));
        }
    }
}

fn generateKingMoves(moves: *ArrayList(?Move), pos: *position.Position) !void {
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));
    const empty = pos.board.empty();
    const from = pos.getIndexOfKing(pos.to_move);

    const targets = attack.KING_ATTACKS[from];
    var quiet = targets & empty;
    var captures = targets & opponent_pieces;

    while (quiet != 0) {
        const to = bitscanForwardAndReset(&quiet);
        try moves.append(Move.initQuiet(from, to, pos.to_move, PieceType.king));
    }

    while (captures != 0) {
        const to = bitscanForwardAndReset(&captures);
        const captured_piece_type = pos.board.getPieceTypeAt(to);
        try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.king, captured_piece_type));
    }
}

// TODO: inefficient, can be improved?
fn generateSlidingMoves(moves: *ArrayList(?Move), pos: *position.Position) !void {
    const empty = pos.board.empty();
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    var queens = pos.board.get(PieceType.queen, pos.to_move);
    var rooks = pos.board.get(PieceType.rook, pos.to_move);
    var bishops = pos.board.get(PieceType.bishop, pos.to_move);

    while (queens != 0) {
        const from = bitscanForwardAndReset(&queens);
        var targets: u64 = 0;
        const bitboard = bitboardFromIndex(from);

        targets |= attack.southAttacks(bitboard, empty);
        targets |= attack.northAttacks(bitboard, empty);
        targets |= attack.eastAttacks(bitboard, empty);
        targets |= attack.westAttacks(bitboard, empty);
        targets |= attack.northEastAttacks(bitboard, empty);
        targets |= attack.northWestAttacks(bitboard, empty);
        targets |= attack.southEastAttacks(bitboard, empty);
        targets |= attack.southWestAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            try moves.append(Move.initQuiet(from, to, pos.to_move, PieceType.queen));
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type));
        }
    }

    while (rooks != 0) {
        const from = bitscanForwardAndReset(&rooks);
        var targets: u64 = 0;
        const bitboard = bitboardFromIndex(from);
        targets |= attack.southAttacks(bitboard, empty);
        targets |= attack.northAttacks(bitboard, empty);
        targets |= attack.eastAttacks(bitboard, empty);
        targets |= attack.westAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            try moves.append(Move.initQuiet(from, to, pos.to_move, PieceType.rook));
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type));
        }
    }

    while (bishops != 0) {
        const from = bitscanForwardAndReset(&bishops);
        var targets: u64 = 0;
        const bitboard = bitboardFromIndex(from);

        targets |= attack.northEastAttacks(bitboard, empty);
        targets |= attack.northWestAttacks(bitboard, empty);
        targets |= attack.southEastAttacks(bitboard, empty);
        targets |= attack.southWestAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            try moves.append(Move.initQuiet(from, to, pos.to_move, PieceType.bishop));
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            try moves.append(Move.initCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type));
        }
    }
}

fn generateCastlingMoves(moves: *ArrayList(?Move), pos: *position.Position) !void {
    // Return early if no castling is possible; this saves the attack generation cost
    if (!castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.king)
        and !castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.queen)) {
        return;
    }

    // Generate an attack map for the opponent, to test for check and castling through
    // check
    const attack_map = pos.generateAttackMap(color.invert(pos.to_move));

    // TODO: can do a faster check here? That doesn't involve creating an attack map if not necessary
    if (isKingInCheck(pos.*, pos.to_move, attack_map)) {
        return;
    }

    // Kingside castle
    if (castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.king) and clearToCastle(pos, castling.CastleSide.king, attack_map)) {
        try moves.append(Move.initKingsideCastle(pos.to_move));
    }

    if (castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.queen) and clearToCastle(pos, castling.CastleSide.queen, attack_map)) {
        try moves.append(Move.initQueensideCastle(pos.to_move));
    }
}

// CASTLING_BLOCKS declares the indices which, if they contain a piece, can block
// castling to that side for each colour.
const CASTLING_BLOCKS = [4][3]u8{
    [_]u8{5, 6, 0}, // White king
    [_]u8{1, 2, 3}, // White queen
    [_]u8{61, 62, 0}, // Black king
    [_]u8{57, 58, 59}, // Black queen
};

// CASTLING_CHECKS declares the indices which, if in check, can block castling.
// Same order as above.
const CASTLING_CHECKS = [4][2]u8{
    [_]u8{5, 6},
    [_]u8{2, 3},
    [_]u8{61, 62},
    [_]u8{58, 59},
};

// Given a position, the side to castle (either KING_CASTLE or QUEEN_CASTLE), and an attack map from the opponent,
// determine if the side is able to legally castle.
// TODO: this can be sped up by precomputing bitboards for the blocked and checked squares, then doing an intersection
// with the occupied and attack maps respectively
fn clearToCastle(pos: *position.Position, side: castling.CastleSide, attack_map: u64) bool {
    const castling_index: u8 = switch (side) {
            .king => @as(u8, 0),
            .queen => @as(u8, 1),
        } + if (pos.to_move == Color.black) @intCast(u8, 2) else @intCast(u8, 0);

    // For each index in the potential blockers, check that there is no piece
    // present.
    for (CASTLING_BLOCKS[castling_index]) |block_index| {
        if (block_index == 0) {
            break;
        }

        if (pos.pieceOn(block_index)) {
            return false;
        }
    }

    // For each index in the potentially-checked indices, ensure that the index
    // is not attacked.
    for (CASTLING_CHECKS[castling_index]) |check_index| {
        if (check_index == 0) {
            break;
        }

        if (attack.isSquareAttacked(attack_map, check_index)) {
            return false;
        }
    }

    return true;
}

pub fn isKingInCheck(pos: position.Position, side: Color, attack_map: u64) bool {
    const king_index = pos.king_indices[@enumToInt(side)];

    return attack.isSquareAttacked(attack_map, king_index);
}
