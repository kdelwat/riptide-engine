// A piece is represented by a single byte.
//           off the board
//           +       +
//           |       | +----+sliding
//           v       v v
//           _ _ _ _ _ _ _ _
//             ^ ^     ^ ^ ^
//   colour+---+ |     + + +
//               |     identity
// double pushed++
//
// If the piece is white, the colour bit is 0. Otherwise, it is 1.
// +--------+----------+
// | Piece  | Identity |
// +--------+----------+
// | empty  |      000 |
// | pawn   |      001 |
// | knight |      010 |
// | bishop |      100 |
// | rook   |      101 |
// | king   |      011 |
// | queen  |      111 |
// +--------+----------+


pub const Color = enum(u8) {
    white = 0x00,
    black = 0x40,
};

pub const PieceType = enum(u8) {
    king   = 0x03,
    queen  = 0x07,
    rook   = 0x05,
    bishop = 0x04,
    knight = 0x02,
    pawn   = 0x01,
    empty  = 0x00,
};

pub const PIECE_IDENTITY_MASK: u8 = 0x0F;
pub const COLOR_MASK: u8          = 0x40;

pub fn pieceType(p: u8) PieceType {
    return @intToEnum(PieceType, p & PIECE_IDENTITY_MASK);
}

pub fn pieceColor(p: u8) Color {
    return @intToEnum(Color, p & COLOR_MASK);
}

// Is the piece a sliding piece (bishop, rook, and queen)?
const SLIDING: u8 = 0x04;

pub fn isSlidingPiece(p: u8) bool {
    return p & SLIDING != 0;
}

pub const MOVE_OFFSETS = [8][8]i8{
    [_]i8{0, 0, 0, 0, 0, 0, 0, 0}, // Empty
    [_]i8{0, 0, 0, 0, 0, 0, 0, 0}, // Pawn
    [_]i8{14, 31, 33, 18, -14, -31, -33, -18}, // Knight
    [_]i8{15, 16, 17, -1, 1, -15, -16, -17}, // King
    [_]i8{15, 17, -15, -17, 0, 0, 0, 0}, // Bishop
    [_]i8{16, -16, 1, -1, 0, 0, 0, 0}, // Rook
    [_]i8{0, 0, 0, 0, 0, 0, 0, 0}, // Empty
    [_]i8{15, 16, 17, -1, 1, -15, -16, -17}, // Queen
};
