const std = @import("std");
const piece = @import("./piece.zig");
const Color = piece.Color;

pub const BOARD_SIZE: u8 = 128;

// Position contains the complete game state after a turn.
pub const Position = struct {
    // board is the board state as an array of pieces. The array is 128 elements long,
    // rather than 64, because it is in 0x88 form. This essentially places a junk board
    // to the right of the main board, like so:
    //
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    // 0 0 0 0 0 0 0 0 x x x x x x x x
    //
    // The bottom left hand corner is index 0, while the top right hand corner is 127.
    // 0x88 form has the advantage of allowing very fast checks to see if a position is
    // on the board, which is used in move generation.
    board:              [128]u8,

    // to_move is the colour of the player who is next to move.
    to_move:            Color,

    // castling is a nibble that represents castling rights for both players. A 1 indicates that
    // castling is allowed.
    //
    //         _ _ _ _
    //         ^ ^ ^ ^
    //         | | | |
    //         | | | |
    //         + | | |
    // White king| | |
    //           + | |
    // White queen | |
    //             | |
    // Black king+-+ |
    //               |
    // Black queen+--+
    castling:           u4,

    // en_passant_target is the index of a square where there is an en passant
    // opportunity. If a pawn was double pushed in the previous turn, its jumped
    // position will appear as the en passant target.
    en_passant_target: u8,

    // halfmove and fullmove represent the time elapsed in the game.
    halfmove:        u8,
    fullmove:        u32,

    // Equality with another position
    pub fn eq(self: Position, other: Position) bool {
        if (self.board.len != other.board.len) return false;
        for (self.board) |sq, i| {
            if (other.board[i] != sq) return false;
        }

        if (self.to_move != other.to_move) return false;

        if (self.castling != other.castling) return false;
        if (self.en_passant_target != other.en_passant_target) return false;
        if (self.halfmove != other.halfmove) return false;
        if (self.fullmove != other.fullmove) return false;

        return true;
    }

    // Checks if there is a piece at the given index
    pub fn pieceOn(self: Position, i: u16) bool {
        return self.board[i] & piece.PIECE_IDENTITY_MASK != 0;
    }

    // Given the index of an attacking pawn, returns whether the pawn can attack the current en
    // passant target, if it exists, from the side in to_move.
    pub fn isEnPassantTarget(self: Position, index: u8) bool {
        if (self.en_passant_target == 0) {
            return false;
        }

        var is_target: bool = false;
        // TODO: Could allow overflow for these? Then it would wrap to off the board
        if (self.to_move == Color.white or (self.to_move == Color.black and index >= 15)) {
            const left_target: u8 = if (self.to_move == Color.white) index + 15 else index - 15;

            if (self.en_passant_target == left_target) {
                is_target = true;
            }
        }

        if (self.to_move == Color.white or (self.to_move == Color.black and index >= 17)) {
            const right_target: u8 = if (self.to_move == Color.white) index + 17 else index - 17;

            if (self.en_passant_target == right_target) {
                is_target = true;
            }
        }

        return is_target;
    }

    pub fn hasCastleRight(self: Position, queenside: bool) bool {
        var offset: u4 = 3;

        if (queenside) {
            offset -= 1;
        }

        if (self.to_move == Color.black) {
            offset -= 2;
        }

        return (self.castling & (@intCast(u32, 1) << offset)) != 0;
    }

    pub fn opponentHasCastleRight(self: Position, queenside: bool) bool {
        var offset: u4 = 3;

        if (queenside) {
            offset -= 1;
        }

        if (self.to_move == Color.white) {
            offset -= 2;
        }

        return (self.castling & (@intCast(u32, 1) << offset)) != 0;
    }

};

const CanCastle = enum(u4) {
    white_king  = 0b1000,
    white_queen = 0b0100,
    black_king  = 0b0010,
    black_queen = 0b0001,
    invalid     = 0,
};

pub fn fromFEN(fen: [:0]const u8) Position {
    // The FEN for the starting position looks like this:
    //         rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    var i: u16 = 0;

    // We need to convert the board string into a piece array. Due to the way
    // FEN is structured, the first piece is at a8, which translates to 0x88
    // index 112.
    var board_position: [128]u8 = [_]u8{0} ** 128;
    var board_index: u8 = 112;

    while (true) {
        // Skip the slashes which separate ranks
        if (fen[i] == '/') {
            i += 1;
            continue;
        }

        // Numbers in the board string indicate empty spaces, so we advance the
        // board index by that number of spaces since there aren't any pieces in
        // those positions.
        if (fen[i] >= '1' and fen[i] <= '8') {
            board_index += fen[i] - '0';
        } else {
            // Otherwise, look up the correct piece code and insert it.
            board_position[board_index] = fromFENCode(fen[i]);
            board_index += 1;
        }

        if (board_index == 8) {
            // Done
            i += 1;
            break;
        }

        // Skip squares that aren't on the board
        if (board_index % 16 > 7) {
            board_index = ((board_index / 16) - 1) * 16;
        }

        i += 1;
    }

    // Find the next player to move
    i += 1;
    const to_move = if (fen[i] == 'w') Color.white else Color.black;

    i += 2;

    // Castling
    var castling: u4 = 0;

    while (fen[i] != ' ') {
        castling |= @enumToInt(switch (fen[i]) {
            'K' => CanCastle.white_king,
            'Q' => CanCastle.white_queen,
            'k' => CanCastle.black_king,
            'q' => CanCastle.black_queen,
            else => CanCastle.invalid,
        });
        i += 1;
    }

    // En passant
    i += 1;
    var en_passant_target: u8 = 0;
    if (fen[i] != '-') {
        const file = fen[i] - 'a';
        const rank = fen[i + 1] - '0';

        en_passant_target = rfToEx88(RankAndFile{
            .file = file,
            .rank = rank,
        });

        i += 3;
    } else {
        i += 2;
    }


    // Halfmove
    const halfmove_start = i;
    while (fen[i] != ' ') {
        i += 1;
    }

    const halfmove: u8 = std.fmt.parseInt(u8, fen[halfmove_start..i], 10) catch 0;

    i += 1;

    // Fullmove
    const fullmove_start = i;
    while (fen[i] != ' ' and i < fen.len) {
        i += 1;
    }

    const fullmove: u8 = std.fmt.parseInt(u8, fen[fullmove_start..i], 10) catch 0;

    return Position{.board = board_position, .to_move = to_move, .castling = castling, .en_passant_target = en_passant_target, .halfmove = halfmove, .fullmove = fullmove};
}

// Convert a FEN piece code (e.g. p) to the 0x88 byte form
fn fromFENCode(fen: u8) u8 {
    return switch(fen) {
        'k' => 67,
        'q' => 71,
        'b' => 68,
        'n' => 66,
        'r' => 69,
        'p' => 65,
        'K' => 3,
        'Q' => 7,
        'B' => 4,
        'N' => 2,
        'R' => 5,
        'P' => 1,
        else => 0,
    };
}

// Convert from rank and file to 0x88 index
// https://en.wikipedia.org/wiki/0x88
pub const RankAndFile = struct {
    rank: u8,
    file: u8,

    pub fn eq(self: RankAndFile, other: RankAndFile) bool {
        if (self.rank != other.rank) return false;
        if (self.file != other.file) return false;

        return true;
    }
};

pub fn rfToEx88(rf: RankAndFile) u8 {
    return (rf.rank - 1) * 16 + rf.file;
}

pub fn ex88ToRf(ex88: u8) RankAndFile {
    return RankAndFile{
        .file = ex88 & 7,
        .rank = (ex88 >> 4) + 1,
    };
}

// Returns true if the index is on the physical board, false otherwise, using
// the 0x88 form for a fast check.
const OFF_BOARD: u16 = 0x88;
pub fn isOnBoard(index: u16) bool {
    return index & OFF_BOARD == 0;
}


// Determines if a piece is on the rank, from 0 to 7, relative to the color of
// the player passed. So 0 will be the row closest to the player, regardless on
// the color selected.
fn isOnRelativeRank(index: u16, color: Color, rank: u8) bool {
    const start: u16 = if (color == Color.white) 16 * rank else 112 - 16 * rank;
    const end: u16 = start + 7;

    return (index >= start and index <= end);
}

// Determines if a pawn is on its starting row.
pub fn isOnStartingRow(index: u16, color: Color) bool {
    return isOnRelativeRank(index, color, 1);
}

// Determines if a pawn is on the final rank, for promotions.
pub fn isOnFinalRank(index: u16, color: Color) bool {
    return isOnRelativeRank(index, color, 7);
}