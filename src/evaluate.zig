const piece = @import("./piece.zig");
const Color = piece.Color;
const PieceType = piece.PieceType;
const position = @import("./position.zig");

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
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
};

const knight_positions = [64]i64{
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
};

const bishop_positions = [64]i64{
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
};

const rook_positions = [64]i64{
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
};

const queen_positions = [64]i64{
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
};

const king_positions = [64]i64{
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
};


// evaluate returns an objective score representing the game's current result. A
// game starts at 0, with no player having the advantage. As it progresses, if
// white were to start taking pieces, the score would increase. If black were to
// instead perform strongly, the score would decrease.
// Since the move search function uses the Negamax algorithm, this evaluation is
// symmetrical. A position for black is the same as the identical one for white,
// but negated.
pub fn evaluate(pos: position.Position) i64 {
    var score: i64 = 0;

    // Loop through the board, finding the score for each piece present. If the
    // piece is white, add it to the total; if black, subtract it.
    var i: u16 = 0;
    while (i < position.BOARD_SIZE) {
        const p = pos.board[i];
        if (position.isOnBoard(i) and pos.pieceOn(i)) {
            const increment: i64 = switch(piece.pieceColor(p)) {
                Color.white => 1,
                Color.black => -1,
            };

            const piecemap_index = map0x88ToPiecemap(i, piece.pieceColor(p));

            score += switch (piece.pieceType(p)) {
                PieceType.king =>
                    (king_weight + king_positions[piecemap_index]) * increment,
                PieceType.queen =>
                    (queen_weight + queen_positions[piecemap_index]) * increment,
                PieceType.bishop =>
                    (bishop_weight + bishop_positions[piecemap_index]) * increment,
                PieceType.rook =>
                    (rook_weight + rook_positions[piecemap_index]) * increment,
                PieceType.knight =>
                    (knight_weight + knight_positions[piecemap_index]) * increment,
                PieceType.pawn =>
                    (pawn_weight + pawn_positions[piecemap_index]) * increment,
                PieceType.empty => 0,
            };
        }

        i += 1;
    }

    return score * switch (pos.to_move) {
        Color.white => @intCast(i64, 1),
        Color.black => @intCast(i64, -1),
    };
}

// Map a 0x88 index to the required position in the score piecemaps. The
// direction (1 for white, -1 for black) is required because the indices are
// asymmetrical in 0x88 but symmetrical in the piecemap.
fn map0x88ToPiecemap(index: usize, to_move: Color) u64 {
    var rank = index / 16;
    const file = index % 16;

    if (to_move == Color.white) {
        rank = 7 - rank;
    }

    return rank * 8 + file;
}