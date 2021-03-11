const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const position = @import("./position.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = piece.Color;
const move = @import("./move.zig");
const attack = @import("./attack.zig");

const BOARD_SIZE: u8 = 128;

pub fn generateMoves(moves: *ArrayList(u32), pos: position.Position) void {
    var i: u8 = 0;
    while (i < BOARD_SIZE) {
        if (position.isOnBoard(i) and pos.pieceOn(i)) {
            const p: u8 = pos.board[i];

            if (piece.pieceColor(p) == pos.to_move) {
                if (piece.pieceType(p) == PieceType.pawn) {
                    generatePawnMoves(moves, pos, i) catch unreachable;
                } else {
                    generateRegularMoves(moves, pos, i) catch unreachable;
                }

                if (piece.pieceType(p) == PieceType.king) {
                    generateCastlingMoves(moves, pos) catch unreachable;
                }
            }
        }

        i += 1;
    }
}

fn generatePawnMoves(moves: *ArrayList(u32), pos: position.Position, index: u8) !void {
    // The offset of pawn moves depends on the colour of the pawn, since they
    // can only move forwards.
    const white: bool = pos.to_move == Color.white;

    // If the pawn is on the starting row, it can perform a double push and move
    // forward two spaces.
    if (position.isOnStartingRow(index, pos.to_move)) {
        const new_index: u8  = if (white) index + 32 else index - 32;
        const jump_index: u8 = if (white) index + 16 else index - 16;

        if (!pos.pieceOn(jump_index) and !pos.pieceOn(new_index)) {
            try moves.append(move.createDoublePawnPush(index, new_index));
        }
    }

    // Generate a regular move forwards, and check that the target square is not
    // occupied.
    const new_index: u8 = if (white) index + 16 else index - 16;

    if (!pos.pieceOn(new_index)) {
        // If the pawn is moving to the final rank, generate promotions.
        if (position.isOnFinalRank(new_index, pos.to_move)) {
            try moves.append(move.createPromotionMove(index, new_index, PieceType.knight));
            try moves.append(move.createPromotionMove(index, new_index, PieceType.rook));
            try moves.append(move.createPromotionMove(index, new_index, PieceType.queen));
            try moves.append(move.createPromotionMove(index, new_index, PieceType.bishop));
        } else {
            // Otherwise, generate a quiet move.
            try moves.append(move.createQuietMove(index, new_index));
        }
    }

    // Generate attacks.
    const left_attack: u8 = if (white) index + 15 else index - 15;
    const right_attack: u8 = if (white) index + 17 else index - 17;

    // For each attack, check if a capture is possible.
    if (position.isOnBoard(left_attack) and pos.pieceOn(left_attack) and piece.pieceColor(pos.board[left_attack]) != pos.to_move) {
        // If the pawn is capturing a piece on the final rank, generate
        // promotion captures.
        if (position.isOnFinalRank(left_attack, pos.to_move)) {
            try moves.append(move.createPromotionCaptureMove(index, left_attack, PieceType.knight));
            try moves.append(move.createPromotionCaptureMove(index, left_attack, PieceType.bishop));
            try moves.append(move.createPromotionCaptureMove(index, left_attack, PieceType.rook));
            try moves.append(move.createPromotionCaptureMove(index, left_attack, PieceType.queen));
        } else {
            // Otherwise, generate a regular capture.
            try moves.append(move.createCaptureMove(index, left_attack));
        }
    }
    if (position.isOnBoard(right_attack) and pos.pieceOn(right_attack) and piece.pieceColor(pos.board[right_attack]) != pos.to_move) {
        // If the pawn is capturing a piece on the final rank, generate
        // promotion captures.
        if (position.isOnFinalRank(right_attack, pos.to_move)) {
            try moves.append(move.createPromotionCaptureMove(index, right_attack, PieceType.knight));
            try moves.append(move.createPromotionCaptureMove(index, right_attack, PieceType.bishop));
            try moves.append(move.createPromotionCaptureMove(index, right_attack, PieceType.rook));
            try moves.append(move.createPromotionCaptureMove(index, right_attack, PieceType.queen));
        } else {
            // Otherwise, generate a regular capture.
            try moves.append(move.createCaptureMove(index, right_attack));
        }
    }

    // If the en passant target saved in the current position is capturable by
    // the pawn, generate an en passant move.
    if (pos.isEnPassantTarget(index)) {
        try moves.append(move.createEnPassantCaptureMove(index, pos.en_passant_target));
    }
}

fn generateRegularMoves(moves: *ArrayList(u32), pos: position.Position, index: u8) !void {
    // For each offset in the piece's offset map, attempt to make a move.
    for (piece.MOVE_OFFSETS[@enumToInt(piece.pieceType(pos.board[index]))]) |offset| {
        if (offset == 0) {
            break;
        }

        var new_index: u8 = index;

        // Slide along the offset for as long as possible, generating the attack
        // rays for sliding pieces (such as queens).
        while (true) {
            const new_index_signed: i32 = @intCast(i32, new_index) + offset;
            if (new_index_signed < 0 or new_index_signed > 127) {
                break;
            }

            new_index = @intCast(u8, new_index_signed);

            // If the new position is off the board, stop sliding.
            if (!position.isOnBoard(new_index)) {
                break;
            }

            if (pos.pieceOn(new_index)) {
                // If the sliding piece encounters another piece of its own
                // colour, stop sliding.
                if (piece.pieceColor(pos.board[new_index]) == pos.to_move) {
                    break;
                }

                // If it encounters a piece of a different colour, capture that
                // piece.
                try moves.append(move.createCaptureMove(index, new_index));

                break;
            } else {
                // If there is no piece present, generate a quiet move to the
                // current index.
                try moves.append(move.createQuietMove(index, new_index));
            }

            // If the piece isn't a sliding piece (i.e. the king and knight),
            // only slide once.
            if (!piece.isSlidingPiece(pos.board[index])) {
                break;
            }
        }
    }
}

fn generateCastlingMoves(moves: *ArrayList(u32), pos: position.Position) !void {
    if (pos.hasCastleRight(false) and clearToCastle(pos, move.KING_CASTLE) and !isKingInCheck(pos)) {
        try moves.append(move.KING_CASTLE);
    }

    if (pos.hasCastleRight(true) and clearToCastle(pos, move.QUEEN_CASTLE) and !isKingInCheck(pos)) {
        try moves.append(move.QUEEN_CASTLE);
    }
}

// CASTLING_BLOCKS declares the indices which, if they contain a piece, can block
// castling to that side for each colour.
const CASTLING_BLOCKS = [4][3]u8{
    [_]u8{5, 6, 0}, // White king
    [_]u8{1, 2, 3}, // White queen
    [_]u8{117, 118, 0}, // Black king
    [_]u8{113, 114, 115}, // Black queen
};

// CASTLING_CHECKS declares the indices which, if in check, can block castling.
// Same order as above.
const CASTLING_CHECKS = [4][2]u8{
    [_]u8{5, 6},
    [_]u8{2, 3},
    [_]u8{117, 118},
    [_]u8{114, 115},
};

// Given a position and the side to castle (either KING_CASTLE or QUEEN_CASTLE),
// determine if the side is able to legally castle.
fn clearToCastle(pos: position.Position, side: u32) bool {
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
    // is not attacked. TODO: This could be optimised by only generating the attack
    // map once.
    for (CASTLING_CHECKS[castling_index]) |check_index| {
        if (check_index == 0) {
            break;
        }

        if (attack.isAttacked(pos, check_index)) {
            return false;
        }
    }

    return true;
}

// From the perspective of the to_move player, is their king in check?
fn isKingInCheck(pos: position.Position) bool {
    // Find the index of the king on the board.
    var king_index: u8 = 0;
    for (pos.board) |p, i| {
        if (
            position.isOnBoard(@intCast(u8, i))
            and p != 0
            and piece.pieceType(p) == PieceType.king
            and piece.pieceColor(p) == pos.to_move
        ) {
            king_index = @intCast(u8, i);
            break;
        }
    }

    // Determine whether the index is attacked.
    return attack.isAttacked(pos, king_index);
}



//// Append the contents of b onto a, then deinit b.
//fn append(a: *ArrayList(u32), b: *ArrayList(u32)) !void {
//    // Ensure enough capacity for the appended items
//    // Do this once for performance
//    try a.ensureCapacity(a.capacity + b.capacity);
//
//    for (b.items) |item| {
//        try a.append(item);
//    }
//
//    b.deinit();
//}