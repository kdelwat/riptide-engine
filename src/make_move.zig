const move = @import("./move.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = piece.Color;
const position = @import("./position.zig");
const std = @import("std");
// When making a move, some information about the previous state cannot be
// recovered from the next state. The moveArtifacts type contains this information.
pub const MoveArtifacts = struct {
    halfmove: u8,
    castling:  u4,
    en_passant_position: u8,
    captured: u8,
};

// Makes a quiet move (a regular move with no captures) given the position,
// origin, and destination.
fn makeQuietMove(pos: *position.Position, from: u8, to: u8) void {
    const moved_piece = pos.board[from];

    pos.board[from] = 0;
    pos.board[to] = moved_piece;
}


// Performs a move on the given position. This function takes a pointer to the
// current position, so it modifies it in-place. While this isn't ideal from a
// debugging point of view, it would be impossible to copy the position each
// time due to memory constraints.
// makeMove returns the artifacts required to reverse the move later.
pub fn makeMove(pos: *position.Position, m: u32) MoveArtifacts {
    // Record the current state in artifacts.
    var artifacts = MoveArtifacts{
        .halfmove =          pos.halfmove,
        .castling =          pos.castling,
        .en_passant_position = pos.en_passant_target,
        .captured =          0,
    };

    // Extract information from move
    const from: u8 = move.fromIndex(m);
    const to: u8 = move.toIndex(m);
    const moved_piece: u8 = pos.board[from];
    const moved_piece_type: PieceType = piece.pieceType(moved_piece);

    // The new position by default has no en passant target.
    pos.en_passant_target = 0;

    // The halfmove counter is reset on a capture, and incremented otherwise.
    if (move.isCapture(m)) {
        pos.halfmove = 0;
    } else {
        pos.halfmove += 1;
    }

    // If the king or rook are moving, remove castling rights
    if (moved_piece_type == PieceType.king) {
        pos.castling = updateCastling(pos.castling, false, pos.to_move, false);
        pos.castling = updateCastling(pos.castling, true, pos.to_move, false);
    }

    if (moved_piece_type == PieceType.rook) {
        if (from == 0 or from == 112) {
            pos.castling = updateCastling(pos.castling, true, pos.to_move, false);
        } else if (from == 7 or from == 119) {
            pos.castling = updateCastling(pos.castling, false, pos.to_move, false);
        }
    }

    // Determine which type of move to make.
    if (move.isQuiet(m)) {
        makeQuietMove(pos, from, to);

        // A quiet move resets the halfmove counter if it is made by a pawn.
        if (moved_piece_type == PieceType.pawn) {
            pos.halfmove = 0;
        }

    } else if (move.isCastle(m)) {
        // If the player is castling, remove all castle rights in the future.
        pos.castling = updateCastling(pos.castling, true, pos.to_move, false);
        pos.castling = updateCastling(pos.castling, false, pos.to_move, false);

        // Determine the starting and ending location of the pieces involved.
        const king_origin: u8 = if (pos.to_move == Color.white) 4 else 116;
        const rook_origin: u8 = if (move.isQueenCastle(m)) king_origin - 4 else king_origin + 3;
        const king_final: u8 = if (move.isQueenCastle(m)) king_origin - 2 else king_origin + 2;
        const rook_final: u8 = if (move.isQueenCastle(m)) king_origin - 1 else king_origin + 1;

        // Swap the pieces in the board.
        const king = pos.board[king_origin];
        const rook = pos.board[rook_origin];
        pos.board[king_origin] = 0;
        pos.board[rook_origin] = 0;

        pos.board[king_final] = king;
        pos.board[rook_final] = rook;
    } else {
        if (move.isPromotionCapture(m)) {
            const promotion_piece = move.getPromotedPiece(m, moved_piece);

            // Save the captured piece in the move artifacts.
            artifacts.captured = pos.board[to];

            pos.board[from] = 0;
            pos.board[to] = promotion_piece;
        } else if (move.isPromotion(m)) {
            const promotion_piece = move.getPromotedPiece(m, moved_piece);

            pos.board[from] = 0;
            pos.board[to] = promotion_piece;

            // The halfmove counter is reset on a promotion.
            pos.halfmove = 0;
        } else if (move.isEnPassantCapture(m)) {
            pos.board[from] = 0;
            pos.board[to] = moved_piece;

            // Determine the en passant target, depending on the direction of
            // movement.
            const capture_index = if (piece.pieceColor(moved_piece) == Color.white) to - 16 else to + 16;

            artifacts.captured = pos.board[capture_index];
            pos.board[capture_index] = 0;
        } else if (move.isDoublePawnPush(m)) {
            pos.board[from] = 0;
            pos.board[to] = moved_piece;

            // A double pawn push creates an en passant target, which must be
            // saved in the new position.
            pos.en_passant_target = (from + to) / 2;
            pos.halfmove = 0;
        } else if (move.isCapture(m)) {
            artifacts.captured = pos.board[to];

            pos.board[from] = 0;
            pos.board[to] = moved_piece;
        }
    }

    // If the rook was captured, remove castling rights for that side.
    if (artifacts.captured != 0 and piece.pieceType(artifacts.captured) == PieceType.rook) {
        const captured_color = piece.pieceColor(artifacts.captured);

        if (pos.opponentHasCastleRight(true)) {
            if (captured_color == Color.white and to == 0) {
                pos.castling = updateCastling(pos.castling, true, Color.white, false);
            } else if (captured_color == Color.black and to == 112) {
                pos.castling = updateCastling(pos.castling, true, Color.black, false);
            }
        }

        if (pos.opponentHasCastleRight(false)) {
            if (captured_color == Color.white and to == 7) {
                pos.castling = updateCastling(pos.castling, false, Color.white, false);
            } else if (captured_color == Color.black and to == 119) {
                pos.castling = updateCastling(pos.castling, false, Color.black, false);
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

    return artifacts;
}


// Reverses a move on the given position. This function takes a position, the move
// which was applied, and the artifacts generated by makeMove, and restores the
// position in-place to the state before the move was applied.
pub fn unmakeMove(pos: *position.Position, m: u32, artifacts: MoveArtifacts) void {
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

    // Extract information from move
    const from: u8 = move.fromIndex(m);
    const to: u8 = move.toIndex(m);
    const moved_piece: u8 = pos.board[to];
    const moved_piece_type: PieceType = piece.pieceType(moved_piece);

    if (move.isQuiet(m)) {
        pos.board[to] = 0;
        pos.board[from] = moved_piece;
    } else if (move.isCastle(m)) {
        // Determine the starting and ending location of the pieces involved.
        const king_origin: u8 = if (pos.to_move == Color.white) 4 else 116;
        const rook_origin: u8 = if (move.isQueenCastle(m)) king_origin - 4 else king_origin + 3;
        const king_final: u8 = if (move.isQueenCastle(m)) king_origin - 2 else king_origin + 2;
        const rook_final: u8 = if (move.isQueenCastle(m)) king_origin - 1 else king_origin + 1;

        // Swap the pieces in the board.
        const king = pos.board[king_final];
        const rook = pos.board[rook_final];
        pos.board[king_final] = 0;
        pos.board[rook_final] = 0;

        pos.board[king_origin] = king;
        pos.board[rook_origin] = rook;
    } else {
        if (move.isPromotionCapture(m)) {
            // If the move was a promotion capture, recreate the pawn piece that
            // was replaced by the promoted piece.
            const pawn: u8 = @enumToInt(piece.pieceColor(moved_piece)) | @enumToInt(PieceType.pawn);

            pos.board[from] = pawn;
            pos.board[to] = artifacts.captured;
        } else if (move.isPromotion(m)) {
            // If the move was a promotion , recreate the pawn piece that was
            // replaced by the promoted piece.
            const pawn: u8 = @enumToInt(piece.pieceColor(moved_piece)) | @enumToInt(PieceType.pawn);

            pos.board[from] = pawn;
            pos.board[to] = 0;
        } else if (move.isEnPassantCapture(m)) {
            pos.board[to] = 0;
            pos.board[from] = moved_piece;

            // Determine the index captured by the en passant, depending on the
            // direction of movement.
            const capture_index = if (piece.pieceColor(moved_piece) == Color.white) to - 16 else to + 16;

            // Restore the captured piece.
            pos.board[capture_index] = artifacts.captured;
        } else if (move.isDoublePawnPush(m)) {
            pos.board[to] = 0;
            pos.board[from] = moved_piece;

            pos.en_passant_target = artifacts.en_passant_position;
        } else if (move.isCapture(m)) {
            pos.board[from] = moved_piece;
            pos.board[to] = artifacts.captured;
        }
    }
}

// Updates the castling nibble
fn updateCastling(castling: u4, queenside: bool, color: Color, can_castle: bool) u4 {
    var new_castling: u4 = castling;
    var offset: u3 = 3;

    if (queenside) {
        offset -= 1;
    }

    if (color == Color.black) {
        offset -= 2;
    }

    if (can_castle) {
        new_castling |= @intCast(u4, @shlExact(@intCast(u8, 1), offset));
    } else {
        new_castling &= @truncate(u4, ~@shlExact(@intCast(u8, 1), offset));
    }

    return new_castling;
}
