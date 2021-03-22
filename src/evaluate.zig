const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;
const position = @import("./position.zig");
usingnamespace @import("./bitboard_ops.zig");

// These constants specify the value, in centipawns, of each piece when evaluating a position.
// A piece's value is a combination of its base weight and a modifier based on its position on the board. This reflects more subtle information about a position. For example, a knight in the centre of the board is more effective than one on the side, so it recieves a bonus.
// The values and piece tables used are from Tomasz Michniewski and can be found at https://chessprogramming.wikispaces.com/Simplified+evaluation+function.

const king_weight: i64 = 10000;
const queen_weight: i64 = 900;
const rook_weight: i64 = 500;
const bishop_weight: i64 = 300;
const knight_weight: i64 = 300;
const pawn_weight: i64 = 100;

const pawn_positions = [64]i64{
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, -20, -20, 10, 10, 5,
    5, -5, -10, 0, 0, -10, -5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, 5, 10, 25, 25, 10, 5, 5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
    0, 0, 0, 0, 0, 0, 0, 0,
};

const knight_positions = [64]i64{
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
};

const bishop_positions = [64]i64{
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
};

const rook_positions = [64]i64{
    0, 0, 0, 5, 5, 0, 0, 0,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    5, 10, 10, 10, 10, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
};

const queen_positions = [64]i64{
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -10, 5, 5, 5, 5, 5, 0, -10,
    0, 0, 5, 5, 5, 5, 0, -5,
    -5, 0, 5, 5, 5, 5, 0, -5,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
};

const king_positions = [64]i64{
    20, 30, 10, 0, 0, 10, 30, 20,
    20, 20, 0, 0, 0, 0, 20, 20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
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

    score += evaluate_bitboard(pos.board.get(PieceType.king, Color.white), king_positions, king_weight);
    score += evaluate_bitboard(pos.board.get(PieceType.queen, Color.white), queen_positions, queen_weight);
    score += evaluate_bitboard(pos.board.get(PieceType.bishop, Color.white), bishop_positions, bishop_weight);
    score += evaluate_bitboard(pos.board.get(PieceType.rook, Color.white), rook_positions, rook_weight);
    score += evaluate_bitboard(pos.board.get(PieceType.knight, Color.white), knight_positions, knight_weight);
    score += evaluate_bitboard(pos.board.get(PieceType.pawn, Color.white), pawn_positions, pawn_weight);
    score -= evaluate_bitboard(pos.board.get(PieceType.king, Color.black), king_positions, king_weight);
    score -= evaluate_bitboard(pos.board.get(PieceType.queen, Color.black), queen_positions, queen_weight);
    score -= evaluate_bitboard(pos.board.get(PieceType.bishop, Color.black), bishop_positions, bishop_weight);
    score -= evaluate_bitboard(pos.board.get(PieceType.rook, Color.black), rook_positions, rook_weight);
    score -= evaluate_bitboard(pos.board.get(PieceType.knight, Color.black), knight_positions, knight_weight);
    score -= evaluate_bitboard(pos.board.get(PieceType.pawn, Color.black), pawn_positions, pawn_weight);

    return score * switch (pos.to_move) {
        Color.white => @as(i64, 1),
        Color.black => @as(i64, -1),
    };
}

fn evaluate_bitboard(board: u64, score_table: [64]i64, piece_type_constant: i64) i64 {
    var score: i64 = 0;
    var scan_board = board;
    while (scan_board != 0) {
        const index = bitscanForwardAndReset(&scan_board);
        score += piece_type_constant + score_table[index];
    }

    return score;
}