const Move = @import("./move.zig").Move;
const MoveType = @import("./move.zig").MoveType;
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const position = @import("./position.zig");
const zobrist = @import("Zobrist.zig");
const castling = @import("./castling.zig");
const CastleSide = @import("./castling.zig").CastleSide;
const b = @import("./bitboard_ops.zig");
const std = @import("std");

// When making a move, some information about the previous state cannot be
// recovered from the next state. The moveArtifacts type contains this information.
pub const MoveArtifacts = struct {
    halfmove: u64,
    castling: u4,
    en_passant_position: u8,

    // Old hash is a copy of the Zobrist hash before making the move.
    // Theoretically this could be computed in unmakeMove, but I don't
    // think it will be much faster than just storing it here.
    old_hash: u64,
};

// Makes a quiet move (a regular move with no captures) given the position,
// origin, and destination.
// This is symmetrical, passing in the same move will unmake the move.
fn makeQuietMove(pos: *position.Position, m: Move) void {
    const from_bitboard = b.bitboardFromIndex(m.from);
    const to_bitboard = b.bitboardFromIndex(m.to);
    const from_to_bitboard = from_bitboard ^ to_bitboard;

    pos.board.boards[@enumToInt(m.piece_color)] ^= from_to_bitboard;
    pos.board.boards[@enumToInt(m.piece_type)] ^= from_to_bitboard;

    pos.hash.flip_piece(m.from, m.piece_type, m.piece_color);
    pos.hash.flip_piece(m.to, m.piece_type, m.piece_color);
}

// This is symmetrical, passing in the same move will unmake the move.
fn makeCapture(pos: *position.Position, m: Move) void {
    const from_bitboard = b.bitboardFromIndex(m.from);
    const to_bitboard = b.bitboardFromIndex(m.to);
    const from_to_bitboard = from_bitboard ^ to_bitboard;

    pos.board.boards[@enumToInt(m.piece_color)] ^= from_to_bitboard;
    pos.board.boards[@enumToInt(m.piece_type)] ^= from_to_bitboard;
    pos.board.boards[@enumToInt(m.captured_piece_color)] ^= to_bitboard;
    pos.board.boards[@enumToInt(m.captured_piece_type)] ^= to_bitboard;

    pos.hash.flip_piece(m.from, m.piece_type, m.piece_color);
    pos.hash.flip_piece(m.to, m.captured_piece_type, m.captured_piece_color);
    pos.hash.flip_piece(m.to, m.piece_type, m.piece_color);
}

fn makeCastle(pos: *position.Position, m: Move) void {
    // Determine the starting and ending location of the pieces involved.
    const king_origin: u8 = if (m.piece_color == Color.white) 4 else 60;
    const rook_origin: u8 = if (m.is(MoveType.queenside_castle)) king_origin - 4 else king_origin + 3;
    const king_final: u8 = if (m.is(MoveType.queenside_castle)) king_origin - 2 else king_origin + 2;
    const rook_final: u8 = if (m.is(MoveType.queenside_castle)) king_origin - 1 else king_origin + 1;

    // Swap the pieces in the board.
    pos.board.set(PieceType.king, m.piece_color, king_final);
    pos.board.set(PieceType.rook, m.piece_color, rook_final);
    pos.board.unset(PieceType.king, m.piece_color, king_origin);
    pos.board.unset(PieceType.rook, m.piece_color, rook_origin);

    pos.hash.flip_piece(king_final, PieceType.king, m.piece_color);
    pos.hash.flip_piece(king_origin, PieceType.king, m.piece_color);
    pos.hash.flip_piece(rook_final, PieceType.rook, m.piece_color);
    pos.hash.flip_piece(rook_origin, PieceType.rook, m.piece_color);

    // If the king is moving, update the king index
    pos.king_indices[@enumToInt(m.piece_color)] = king_final;
}

fn makePromoCapture(pos: *position.Position, m: Move) void {
    const from_bitboard = b.bitboardFromIndex(m.from);
    const to_bitboard = b.bitboardFromIndex(m.to);

    const promotion_piece = m.getPromotedPiece();

    pos.board.boards[@enumToInt(m.piece_color)] ^= from_bitboard;
    pos.board.boards[@enumToInt(m.piece_type)] ^= from_bitboard;
    pos.board.boards[@enumToInt(m.captured_piece_color)] ^= to_bitboard;
    pos.board.boards[@enumToInt(m.captured_piece_type)] ^= to_bitboard;
    pos.board.boards[@enumToInt(promotion_piece)] ^= to_bitboard;
    pos.board.boards[@enumToInt(m.piece_color)] ^= to_bitboard;

    pos.hash.flip_piece(m.from, m.piece_type, m.piece_color);
    pos.hash.flip_piece(m.to, m.captured_piece_type, m.captured_piece_color);
    pos.hash.flip_piece(m.to, promotion_piece, m.piece_color);
}

fn makePromo(pos: *position.Position, m: Move) void {
    const from_bitboard = b.bitboardFromIndex(m.from);
    const to_bitboard = b.bitboardFromIndex(m.to);

    const promotion_piece = m.getPromotedPiece();

    pos.board.boards[@enumToInt(m.piece_color)] ^= from_bitboard;
    pos.board.boards[@enumToInt(m.piece_type)] ^= from_bitboard;
    pos.board.boards[@enumToInt(promotion_piece)] ^= to_bitboard;
    pos.board.boards[@enumToInt(m.piece_color)] ^= to_bitboard;

    pos.hash.flip_piece(m.from, m.piece_type, m.piece_color);
    pos.hash.flip_piece(m.to, promotion_piece, m.piece_color);
}

fn makeEnPassant(pos: *position.Position, m: Move) void {
    const from_bitboard = b.bitboardFromIndex(m.from);
    const to_bitboard = b.bitboardFromIndex(m.to);

    const from_to_bitboard = from_bitboard ^ to_bitboard;

    pos.board.boards[@enumToInt(m.piece_color)] ^= from_to_bitboard;
    pos.board.boards[@enumToInt(m.piece_type)] ^= from_to_bitboard;

    // Determine the en passant target, depending on the direction of
    // movement.
    const capture_index = if (m.piece_color == Color.white) m.to - 8 else m.to + 8;

    pos.board.unset(m.captured_piece_type, m.captured_piece_color, capture_index);

    pos.hash.flip_piece(m.from, m.piece_type, m.piece_color);
    pos.hash.flip_piece(m.to, m.piece_type, m.piece_color);
    pos.hash.flip_piece(capture_index, m.captured_piece_type, m.captured_piece_color);
}

// Performs a move on the given position. This function takes a pointer to the
// current position, so it modifies it in-place. While this isn't ideal from a
// debugging point of view, it would be impossible to copy the position each
// time due to memory constraints.
// makeMove returns the artifacts required to reverse the move later.
pub fn makeMove(pos: *position.Position, m: Move) MoveArtifacts {
    // Record the current state in artifacts.
    var artifacts = MoveArtifacts{ .halfmove = pos.halfmove, .castling = pos.castling, .en_passant_position = pos.en_passant_target, .old_hash = pos.hash.hash };

    // The new position by default has no en passant target.
    pos.en_passant_target = 0;

    // The halfmove counter is reset on a capture, and incremented otherwise.
    if (m.isCapture()) {
        pos.halfmove = 0;
    } else {
        pos.halfmove += 1;
    }

    // If the king or rook are moving, remove castling rights
    if (m.piece_type == PieceType.king) {
        pos.castling = castling.updateCastling(pos.castling, CastleSide.king, m.piece_color, false);
        pos.castling = castling.updateCastling(pos.castling, CastleSide.queen, m.piece_color, false);

        // If the king is moving, update the king index
        // TODO: can remove this?
        pos.king_indices[@enumToInt(m.piece_color)] = m.to;
    }

    if (m.piece_type == PieceType.rook) {
        if (m.from == 0 or m.from == 56) {
            pos.castling = castling.updateCastling(pos.castling, CastleSide.queen, m.piece_color, false);
        } else if (m.from == 7 or m.from == 63) {
            pos.castling = castling.updateCastling(pos.castling, CastleSide.king, m.piece_color, false);
        }
    }

    // Determine which type of move to make.
    if (m.is(MoveType.quiet)) {
        makeQuietMove(pos, m);

        // A quiet move resets the halfmove counter if it is made by a pawn.
        if (m.piece_type == PieceType.pawn) {
            pos.halfmove = 0;
        }
    } else if (m.isCastle()) {
        // If the player is castling, remove all castle rights in the future.
        pos.castling = castling.updateCastling(pos.castling, CastleSide.queen, m.piece_color, false);
        pos.castling = castling.updateCastling(pos.castling, CastleSide.king, m.piece_color, false);

        makeCastle(pos, m);
    } else if (m.isPromotionCapture()) {
        makePromoCapture(pos, m);
    } else if (m.isPromotion()) {
        makePromo(pos, m);
        // The halfmove counter is reset on a promotion.
        pos.halfmove = 0;
    } else if (m.is(MoveType.en_passant)) {
        makeEnPassant(pos, m);
    } else if (m.is(MoveType.double_pawn_push)) {
        makeQuietMove(pos, m);

        // A double pawn push creates an en passant target, which must be
        // saved in the new position.
        pos.en_passant_target = (m.from + m.to) / 2;
        pos.halfmove = 0;
    } else if (m.is(MoveType.capture)) {
        makeCapture(pos, m);
    } else {
        unreachable;
    }

    // If the rook was captured, remove castling rights for that side.
    if (m.captured_piece_type != PieceType.empty) {
        if (m.captured_piece_type == PieceType.rook) {
            const captured_color = m.captured_piece_color;

            if (castling.hasCastlingRight(pos.castling, color.invert(pos.to_move), CastleSide.queen)) {
                if (captured_color == Color.white and m.to == 0) {
                    pos.castling = castling.updateCastling(pos.castling, CastleSide.queen, Color.white, false);
                } else if (captured_color == Color.black and m.to == 56) {
                    pos.castling = castling.updateCastling(pos.castling, CastleSide.queen, Color.black, false);
                }
            }

            if (castling.hasCastlingRight(pos.castling, color.invert(pos.to_move), CastleSide.king)) {
                if (captured_color == Color.white and m.to == 7) {
                    pos.castling = castling.updateCastling(pos.castling, CastleSide.king, Color.white, false);
                } else if (captured_color == Color.black and m.to == 63) {
                    pos.castling = castling.updateCastling(pos.castling, CastleSide.king, Color.black, false);
                }
            }
        }
    }

    // Increment the fullmove counter when black finishes their turn.
    if (pos.to_move == Color.white) {
        pos.to_move = Color.black;
    } else {
        pos.to_move = Color.white;
        pos.fullmove += 1;
    }

    pos.hash.update_castling(artifacts.castling, pos.castling);
    pos.hash.update_en_passant(artifacts.en_passant_position, pos.en_passant_target);
    pos.hash.update_side(pos.to_move);

    return artifacts;
}

// Reverses a move on the given position. This function takes a position, the move
// which was applied, and the artifacts generated by makeMove, and restores the
// position in-place to the state before the move was applied.
pub fn unmakeMove(pos: *position.Position, m: Move, artifacts: MoveArtifacts) void {
    // Restore state information from artifacts.
    pos.halfmove = artifacts.halfmove;
    pos.castling = artifacts.castling;
    pos.en_passant_target = artifacts.en_passant_position;

    // Decrement the fullmove counter if black made the last move.
    if (pos.to_move == Color.white) {
        pos.fullmove -= 1;
        pos.to_move = Color.black;
    } else {
        pos.to_move = Color.white;
    }

    // Reset king position
    if (m.piece_type == PieceType.king) {
        pos.king_indices[@enumToInt(m.piece_color)] = m.from;
    }

    const from_bitboard = b.bitboardFromIndex(m.from);
    const to_bitboard = b.bitboardFromIndex(m.to);

    if (m.is(MoveType.quiet)) {
        makeQuietMove(pos, m);
    } else if (m.isCastle()) {
        // Determine the starting and ending location of the pieces involved.
        const king_origin: u8 = if (pos.to_move == Color.white) 4 else 60;
        const rook_origin: u8 = if (m.is(MoveType.queenside_castle)) king_origin - 4 else king_origin + 3;
        const king_final: u8 = if (m.is(MoveType.queenside_castle)) king_origin - 2 else king_origin + 2;
        const rook_final: u8 = if (m.is(MoveType.queenside_castle)) king_origin - 1 else king_origin + 1;

        // Swap the pieces in the board.
        pos.board.set(PieceType.king, m.piece_color, king_origin);
        pos.board.set(PieceType.rook, m.piece_color, rook_origin);
        pos.board.unset(PieceType.king, m.piece_color, king_final);
        pos.board.unset(PieceType.rook, m.piece_color, rook_final);

        pos.king_indices[@enumToInt(m.piece_color)] = king_origin;
    } else {
        if (m.isPromotionCapture()) {
            pos.board.boards[@enumToInt(m.piece_color)] ^= from_bitboard;
            pos.board.boards[@enumToInt(m.piece_type)] ^= from_bitboard;
            pos.board.boards[@enumToInt(m.captured_piece_color)] ^= to_bitboard;
            pos.board.boards[@enumToInt(m.captured_piece_type)] ^= to_bitboard;

            const promotion_piece = m.getPromotedPiece();
            pos.board.boards[@enumToInt(promotion_piece)] ^= to_bitboard;
            pos.board.boards[@enumToInt(m.piece_color)] ^= to_bitboard;
        } else if (m.isPromotion()) {
            pos.board.boards[@enumToInt(m.piece_color)] ^= from_bitboard;
            pos.board.boards[@enumToInt(m.piece_type)] ^= from_bitboard;

            const promotion_piece = m.getPromotedPiece();
            pos.board.boards[@enumToInt(promotion_piece)] ^= to_bitboard;
            pos.board.boards[@enumToInt(m.piece_color)] ^= to_bitboard;
        } else if (m.is(MoveType.en_passant)) {
            const from_to_bitboard = from_bitboard ^ to_bitboard;

            pos.board.boards[@enumToInt(m.piece_color)] ^= from_to_bitboard;
            pos.board.boards[@enumToInt(m.piece_type)] ^= from_to_bitboard;

            // Determine the en passant target, depending on the direction of
            // movement, and recreate the pawn that was captured.
            const capture_index = if (m.piece_color == Color.white) m.to - 8 else m.to + 8;

            pos.board.set(m.captured_piece_type, m.captured_piece_color, capture_index);
        } else if (m.is(MoveType.double_pawn_push)) {
            makeQuietMove(pos, m);

            pos.en_passant_target = artifacts.en_passant_position;
        } else if (m.is(MoveType.capture)) {
            makeCapture(pos, m);
        }
    }

    pos.hash = zobrist.Hash.from_u64(artifacts.old_hash);
}
