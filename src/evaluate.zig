const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;
const position = @import("./position.zig");
const b = @import("./bitboard_ops.zig");
const bitboard = @import("./bitboard.zig");
const std = @import("std");

pub const Score = i16;
pub const INFINITY = std.math.maxInt(i16);

// These constants specify the value, in centipawns, of each piece when evaluating a position.
// A piece's value is a combination of its base weight and a modifier based on its position on the board. This reflects more subtle information about a position. For example, a knight in the centre of the board is more effective than one on the side, so it recieves a bonus.
// The values and piece tables used are from Tomasz Michniewski and can be found at https://chessprogramming.wikispaces.com/Simplified+evaluation+function.

const PIECE_WEIGHTS = [6]Score{
    100, // pawn
    300, // knight
    300, // bishop
    500, // rook
    900, // queen
    10000, // king
};

// Same order as PIECE_WEIGHTS
const POSITION_WEIGHTS = [6][64]Score{ [64]Score{
    0,  0,  0,   0,   0,   0,   0,  0,
    5,  10, 10,  -20, -20, 10,  10, 5,
    5,  -5, -10, 0,   0,   -10, -5, 5,
    0,  0,  0,   20,  20,  0,   0,  0,
    5,  5,  10,  25,  25,  10,  5,  5,
    10, 10, 20,  30,  30,  20,  10, 10,
    50, 50, 50,  50,  50,  50,  50, 50,
    0,  0,  0,   0,   0,   0,   0,  0,
}, [64]Score{
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0,   5,   5,   0,   -20, -40,
    -30, 5,   10,  15,  15,  10,  5,   -30,
    -30, 0,   15,  20,  20,  15,  0,   -30,
    -30, 5,   15,  20,  20,  15,  5,   -30,
    -30, 0,   10,  15,  15,  10,  0,   -30,
    -40, -20, 0,   0,   0,   0,   -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
}, [64]Score{
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 5,   0,   0,   0,   0,   5,   -10,
    -10, 10,  10,  10,  10,  10,  10,  -10,
    -10, 0,   10,  10,  10,  10,  0,   -10,
    -10, 5,   5,   10,  10,  5,   5,   -10,
    -10, 0,   5,   10,  10,  5,   0,   -10,
    -10, 0,   0,   0,   0,   0,   0,   -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
}, [64]Score{
    0,  0,  0,  5,  5,  0,  0,  0,
    -5, 0,  0,  0,  0,  0,  0,  -5,
    -5, 0,  0,  0,  0,  0,  0,  -5,
    -5, 0,  0,  0,  0,  0,  0,  -5,
    -5, 0,  0,  0,  0,  0,  0,  -5,
    -5, 0,  0,  0,  0,  0,  0,  -5,
    5,  10, 10, 10, 10, 10, 10, 5,
    0,  0,  0,  0,  0,  0,  0,  0,
}, [64]Score{
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0,   5,   0,  0,  0,   0,   -10,
    -10, 5,   5,   5,  5,  5,   0,   -10,
    0,   0,   5,   5,  5,  5,   0,   -5,
    -5,  0,   5,   5,  5,  5,   0,   -5,
    -10, 0,   5,   5,  5,  5,   0,   -10,
    -10, 0,   0,   0,  0,  0,   0,   -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
}, [64]Score{
    20,  30,  10,  0,   0,   10,  30,  20,
    20,  20,  0,   0,   0,   0,   20,  20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
} };

const ALL_PIECE_TYPES = [6]PieceType{ .pawn, .knight, .bishop, .rook, .queen, .king };

// evaluate returns an objective score representing the game's current result. A
// game starts at 0, with no player having the advantage. As it progresses, if
// white were to start taking pieces, the score would increase. If black were to
// instead perform strongly, the score would decrease.
// Since the move search function uses the Negamax algorithm, this evaluation is
// symmetrical. A position for black is the same as the identical one for white,
// but negated.
pub fn evaluate(pos: *position.Position) Score {
    var score: Score = 0;

    for (ALL_PIECE_TYPES) |piece_type| {
        const white = pos.board.get(piece_type, Color.white);
        const black = b.flipV(pos.board.get(piece_type, Color.black));

        score += evaluate_bitboard(white, piece_type);
        score -= evaluate_bitboard(black, piece_type);
    }

    return score * switch (pos.to_move) {
        Color.white => @as(Score, 1),
        Color.black => @as(Score, -1),
    };
}

pub fn get_piece_value(piece_type: PieceType) Score {
    return PIECE_WEIGHTS[@enumToInt(piece_type) - 2];
}

// Evaluate a position for a certain piece type
// Assumes that the bitboard passed in is for white
fn evaluate_bitboard(bb: u64, piece_type: PieceType) Score {
    var score: Score = 0;
    var scan_board = bb;

    while (scan_board != 0) {
        var index = b.bitscanForwardAndReset(&scan_board);

        score += get_piece_value(piece_type) + POSITION_WEIGHTS[@enumToInt(piece_type) - 2][index];
    }

    return score;
}

// Since the piece position tables are symmetrical, convert a black index to a white index
// to look up the position value for black
fn invertIndex(index: u8) u8 {
    const rank_index = 7 - bitboard.rankIndex(index); // Black is on inverted rank

    return bitboard.bitboardIndex(bitboard.fileIndex(index), rank_index);
}
