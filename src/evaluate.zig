const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;
const position = @import("./position.zig");
usingnamespace @import("./bitboard_ops.zig");
const std = @import("std");
const bitboard = @import("./bitboard.zig");

// These constants specify the value, in centipawns, of each piece when evaluating a position.
// A piece's value is a combination of its base weight and a modifier based on its position on the board. This reflects more subtle information about a position. For example, a knight in the centre of the board is more effective than one on the side, so it recieves a bonus.
// The values and piece tables used are from Tomasz Michniewski and can be found at https://chessprogramming.wikispaces.com/Simplified+evaluation+function.

const PIECE_WEIGHTS = [6]i64{
    100, // pawn
    300, // knight
    300, // bishop
    500, // rook
    900, // queen
    10000, // king
};

// Same order as PIECE_WEIGHTS
const POSITION_WEIGHTS = [6][64]i64{
    [64]i64{
        0, 0, 0, 0, 0, 0, 0, 0,
        5, 10, 10, -20, -20, 10, 10, 5,
        5, -5, -10, 0, 0, -10, -5, 5,
        0, 0, 0, 20, 20, 0, 0, 0,
        5, 5, 10, 25, 25, 10, 5, 5,
        10, 10, 20, 30, 30, 20, 10, 10,
        50, 50, 50, 50, 50, 50, 50, 50,
        0, 0, 0, 0, 0, 0, 0, 0,
    },
    [64]i64{
        -50, -40, -30, -30, -30, -30, -40, -50,
        -40, -20, 0, 5, 5, 0, -20, -40,
        -30, 5, 10, 15, 15, 10, 5, -30,
        -30, 0, 15, 20, 20, 15, 0, -30,
        -30, 5, 15, 20, 20, 15, 5, -30,
        -30, 0, 10, 15, 15, 10, 0, -30,
        -40, -20, 0, 0, 0, 0, -20, -40,
        -50, -40, -30, -30, -30, -30, -40, -50,
    },
    [64]i64{
        -20, -10, -10, -10, -10, -10, -10, -20,
        -10, 5, 0, 0, 0, 0, 5, -10,
        -10, 10, 10, 10, 10, 10, 10, -10,
        -10, 0, 10, 10, 10, 10, 0, -10,
        -10, 5, 5, 10, 10, 5, 5, -10,
        -10, 0, 5, 10, 10, 5, 0, -10,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -20, -10, -10, -10, -10, -10, -10, -20,
    },
    [64]i64{
        0, 0, 0, 5, 5, 0, 0, 0,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        5, 10, 10, 10, 10, 10, 10, 5,
        0, 0, 0, 0, 0, 0, 0, 0,
    },
    [64]i64{
        -20, -10, -10, -5, -5, -10, -10, -20,
        -10, 0, 5, 0, 0, 0, 0, -10,
        -10, 5, 5, 5, 5, 5, 0, -10,
        0, 0, 5, 5, 5, 5, 0, -5,
        -5, 0, 5, 5, 5, 5, 0, -5,
        -10, 0, 5, 5, 5, 5, 0, -10,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -20, -10, -10, -5, -5, -10, -10, -20,
    },
    [64]i64{
        20, 30, 10, 0, 0, 10, 30, 20,
        20, 20, 0, 0, 0, 0, 20, 20,
        -10, -20, -20, -20, -20, -20, -20, -10,
        -20, -30, -30, -40, -40, -30, -30, -20,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
    }
};

const ALL_PIECE_TYPES = [6]PieceType{
    .pawn,
    .knight,
    .bishop,
    .rook,
    .queen,
    .king
};

// evaluate returns an objective score representing the game's current result. A
// game starts at 0, with no player having the advantage. As it progresses, if
// white were to start taking pieces, the score would increase. If black were to
// instead perform strongly, the score would decrease.
// Since the move search function uses the Negamax algorithm, this evaluation is
// symmetrical. A position for black is the same as the identical one for white,
// but negated.
pub fn evaluate(pos: *position.Position) i64 {
    var score: i64 = 0;

    for (ALL_PIECE_TYPES) |piece_type| {
        score += evaluate_bitboard(pos, piece_type, .white);
        score -= evaluate_bitboard(pos, piece_type, .black);
    }

    return score * switch (pos.to_move) {
        Color.white => @as(i64, 1),
        Color.black => @as(i64, -1),
    };
}

fn evaluate_bitboard(pos: *position.Position, piece_type: PieceType, color: Color) i64 {
    var score: i64 = 0;
    var scan_board = pos.board.get(piece_type, color);

    while (scan_board != 0) {
        var index = bitscanForwardAndReset(&scan_board);

        if (color == Color.black) {
            index = invertIndex(index);
        }

        score += PIECE_WEIGHTS[@enumToInt(piece_type) - 2] + POSITION_WEIGHTS[@enumToInt(piece_type) - 2][index];
    }

    return score;
}

// Since the piece position tables are symmetrical, convert a black index to a white index
// to look up the position value for black
fn invertIndex(index: u8) u8 {
    const rank_index = 7 - bitboard.rankIndex(index); // Black is on inverted rank

    return bitboard.bitboardIndex(bitboard.fileIndex(index), rank_index);
}