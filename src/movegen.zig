const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const position = @import("./position.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = @import("./color.zig").Color;
const move = @import("./move.zig");
const make_move = @import("./make_move.zig");
const attack = @import("./attack.zig");
const debug = @import("./debug.zig");

// Generate legal moves for a position.
pub fn generateLegalMoves(moves: *ArrayList(u32), pos: *position.Position) void {
    const attacker: Color = switch (pos.to_move) {
        Color.white => Color.black,
        Color.black => Color.white,
    };

    generateMoves(moves, pos.*);

    const current_player = pos.to_move;

    // For each pseudo-legal move, make the move, then see if the king is in
    // check. If it isn't, the move is legal.
    for (moves.items) |m, i| {
        const artifacts = make_move.makeMove(pos, m);

        const attack_map = attack.generateAttackMap(&pos, attacker);
        if (isKingInCheck(pos.*, current_player, attack_map)) {
            moves.items[i] = move.NULL_MOVE;
        }

        make_move.unmakeMove(pos, m, artifacts);
    }
}

pub fn countNonNullMoves(moves: *ArrayList(u32)) u32 {
    var count: u32 = 0;

    for (moves.items) |m| {
        if (m != move.NULL_MOVE) count += 1;
    }

    return count;
}

// Generate pseudo-legal moves for a position
pub fn generateMoves(moves: *ArrayList(u32), pos: position.Position) void {
    generatePawnMoves(moves, pos);
    generatePawnCaptures(moves, pos);
    generateKnightMoves(moves, pos);
    generateKingMoves(moves, pos);
    generateCastlingMoves(moves, pos);
    generateSlidingMoves(moves, pos);
}

// Generate all non-capture pawn moves, including non-capture promotions
// Works by generating a bitboard for single and double push targets, then converting
// that into a list of moves using a bitscan.
// https://www.chessprogramming.org/Pawn_Pushes_(Bitboards)#PawnPushSetwise
const RANK_4: u64 = 0x00000000FF000000;
const RANK_5: u64 = 0x000000FF00000000;

fn generatePawnMoves(moves: *ArrayList(u32), pos: position.Position) !void {
    const empty = pos.board.empty();
    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    const single_push = switch(pos.to_move) {
        Color.white => northOne(pawns) & pos.board.empty(),
        Color.black => southOne(pawns) & pos.board.empty(),
    };

    const double_push = switch(pos.to_move) {
        Color.white => northOne(single_push) & empty & RANK_4,
        Color.black => southOne(single_push) & empty & RANK_5,
    };

    const promotion_rank = switch(pos.to_move) {
        Color.white => 7,
        Color.black => 0,
    };

    // If the single push results in a pawn ending up on the final rank, generate
    // promotion moves. Otherwise generate a quiet push.
    while (single_push) {
        const to = bitScanAndReset(&single_push);
        const from = to - 8;

        if (bitboard.isOnRank(to, promotion_rank)) {
            try moves.append(move.createPromotionMove(from, to, PieceType.queen));
            try moves.append(move.createPromotionMove(from, to, PieceType.knight));
            try moves.append(move.createPromotionMove(from, to, PieceType.rook));
            try moves.append(move.createPromotionMove(from, to, PieceType.bishop));
        } else {
            try moves.append(move.createQuietMove(from, to));
        }
    }

    // Generate double push moves.
    while (double_push) {
        const to = bitScanAndReset(&double_push);
        const from = to - 16;
        try moves.append(move.createDoublePawnPush(from, to));
    }
}

fn generatePawnCaptures(moves: *ArrayList(u32), pos: position.Position) !void {
    var opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    if (pos.en_passant_target) {
        opponent_pieces |= (1 << pos.en_passant_target);
    }

    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    const east_captures = switch(pos.to_move) {
        Color.white => northEastOne(pawns) & opponent_pieces,
        Color.black => southEastOne(pawns) & opponent_pieces,
    };

    const west_captures = switch(pos.to_move) {
        Color.white => northWestOne(pawns) & opponent_pieces,
        Color.black => southWestOne(pawns) & opponent_pieces,
    };

    const promotion_rank = switch(pos.to_move) {
        Color.white => 7,
        Color.black => 0,
    };

    // If the capture results in a pawn ending up on the final rank, generate
    // promotion capture moves. Otherwise generate a capture move.
    while (east_captures) {
        const to = bitScanAndReset(&east_captures);
        const from = to - 7; // TODO: might be wrong way around

        if (bitboard.isOnRank(to, promotion_rank)) {
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.queen));
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.knight));
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.rook));
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.bishop));
        } else if (to == pos.en_passant_target) {
            try moves.append(move.createEnPassantCaptureMove(from, to));
        } else {
            try moves.append(move.createCaptureMove(from, to));
        }
    }

    while (west_captures) {
        const to = bitScanAndReset(&west_captures);
        const from = to - 9; // TODO: might be wrong way around

        if (bitboard.isOnRank(to, promotion_rank)) {
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.queen));
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.knight));
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.rook));
            try moves.append(move.createPromotionCaptureMove(from, to, PieceType.bishop));
        } else if (to == pos.en_passant_target) {
            try moves.append(move.createEnPassantCaptureMove(from, to));
        } else {
            try moves.append(move.createCaptureMove(from, to));
        }
    }
}

fn generateKnightMoves(moves: *ArrayList(u32), pos: position.Position) !void {
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));
    const empty = pos.board.empty();
    const knights = pos.board.get(PieceType.knight, pos.to_move);

    // While there are knights left to process, find the index and generate moves
    // for that knight
    while (knights) {
        const from = bitScanAndReset(&knights);
        const targets = attack.KNIGHT_ATTACKS[from];

        const quiet = targets & empty;
        const captures = targets & opponent_pieces;

        while (quiet) {
            const to = bitScanAndReset(&quiet);
            try moves.append(move.createQuietMove(from, to));
        }

        while (captures) {
            const to = bitScanAndReset(&captures);
            try moves.append(move.createCaptureMove(from, to));
        }
    }
}

fn generateKingMoves(moves: *ArrayList(u32), pos: position.Position) !void {
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));
    const empty = pos.board.empty();
    const from = pos.getIndexOfKing(pos.to_move);

    const targets = attack.KING_ATTACKS[from];
    var quiet = targets & empty;
    var captures = targets & opponent_pieces;

    while (quiet) {
        const to = bitScanAndReset(&quiet);
        try moves.append(move.createQuietMove(from, to));
    }

    while (captures) {
        const to = bitScanAndReset(&captures);
        try moves.append(move.createCaptureMove(from, to));
    }
}

// TODO: inefficient, can be improved?
fn generateSlidingMoves(moves: *ArrayList(u32), pos: position.Position) !void {
    const empty = pos.board.empty();
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    var queens = pos.get(PieceType.queen, pos.to_move);
    var rooks = pos.get(PieceType.queen, pos.to_move);
    var bishops = pos.get(PieceType.queen, pos.to_move);

    while (queens) {
        const from = bitScanAndReset(&queens);
        var targets = 0;
        targets |= attack.south_attacks(queens, empty);
        targets |= attack.north_attacks(queens, empty);
        targets |= attack.east_attacks(queens, empty);
        targets |= attack.west_attacks(queens, empty);
        targets |= attack.north_east_attacks(queens, empty);
        targets |= attack.north_west_attacks(queens, empty);
        targets |= attack.south_east_attacks(queens, empty);
        targets |= attack.south_west_attacks(queens, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet) {
            const to = bitScanAndReset(&quiet);
            try moves.append(move.createQuietMove(from, to));
        }

        while (captures) {
            const to = bitScanAndReset(&captures);
            try moves.append(move.createCaptureMove(from, to));
        }
    }

    while (rooks) {
        const from = bitScanAndReset(&rooks);
        var targets = 0;
        targets |= attack.south_attacks(rooks, empty);
        targets |= attack.north_attacks(rooks, empty);
        targets |= attack.east_attacks(rooks, empty);
        targets |= attack.west_attacks(rooks, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet) {
            const to = bitScanAndReset(&quiet);
            try moves.append(move.createQuietMove(from, to));
        }

        while (captures) {
            const to = bitScanAndReset(&captures);
            try moves.append(move.createCaptureMove(from, to));
        }
    }

    while (bishops) {
        const from = bitScanAndReset(&bishops);
        var targets = 0;
        targets |= attack.north_east_attacks(bishops, empty);
        targets |= attack.north_west_attacks(bishops, empty);
        targets |= attack.south_east_attacks(bishops, empty);
        targets |= attack.south_west_attacks(bishops, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet) {
            const to = bitScanAndReset(&quiet);
            try moves.append(move.createQuietMove(from, to));
        }

        while (captures) {
            const to = bitScanAndReset(&captures);
            try moves.append(move.createCaptureMove(from, to));
        }
    }
}

fn generateCastlingMoves(moves: *ArrayList(u32), pos: position.Position) !void {
    // Return early if no castling is possible; this saves the attack generation cost
    if (!pos.hasCastleRight(false) and !pos.hasCastleRight(true)) {
        return;
    }

    // Generate an attack map for the opponent, to test for check and castling through
    // check
    const attack_map = pos.generateAttackMap(color.invert(pos.to_move));

    // TODO: can do a faster check here? That doesn't involve creating an attack map if not necessary
    if (isKingInCheck(pos, pos.to_move, attack_map)) {
        return;
    }

    // Kingside castle
    if (pos.hasCastleRight(false) and clearToCastle(pos, move.KING_CASTLE, attack_map)) {
        try moves.append(move.KING_CASTLE);
    }

    if (pos.hasCastleRight(true) and clearToCastle(pos, move.QUEEN_CASTLE, attack_map)) {
        try moves.append(move.QUEEN_CASTLE);
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
fn clearToCastle(pos: position.Position, side: u32, attack_map: u64) bool {
    const castling_index: u8 = switch (side) {
            move.KING_CASTLE => 0,
            move.QUEEN_CASTLE => 1,
            else => @intCast(u8, 0),
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
