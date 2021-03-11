const PieceType = @import("./piece.zig").PieceType;

// A move is encoded as a 32-bit integer.
//
//         _ _ _ _  _ _ _ _   unused
// castle  +-----+ +------+   special
//         +--------------+   from index
//         +--------------+   to index
//
// The special byte encodes information about captures, promotions, and other
// non-standard moves. Its schema is taken from
// https://chessprogramming.wikispaces.com/Encoding+Moves.
//
// +----------------------+-----------+---------+-----------+-----------+
// |      Move type       | Promotion | Capture | Special 1 | Special 2 |
// +----------------------+-----------+---------+-----------+-----------+
// | quiet                |         0 |       0 |         0 |         0 |
// | double pawn push     |         0 |       0 |         0 |         1 |
// | kingside castle      |         0 |       0 |         1 |         0 |
// | queenside castle     |         0 |       0 |         1 |         1 |
// | capture              |         0 |       1 |         0 |         0 |
// | en passant           |         0 |       1 |         0 |         1 |
// | knight promotion     |         1 |       0 |         0 |         0 |
// | bishop promotion     |         1 |       0 |         0 |         1 |
// | rook promotion       |         1 |       0 |         1 |         0 |
// | queen promotion      |         1 |       0 |         1 |         1 |
// | knight promo-capture |         1 |       1 |         0 |         0 |
// | bishop promo-capture |         1 |       1 |         0 |         1 |
// | rook promo-capture   |         1 |       1 |         1 |         0 |
// | queen promo-capture  |         1 |       1 |         1 |         1 |
// +----------------------+-----------+---------+-----------+-----------+

// Codes used to determine move types.
const CAPTURE = 0x1 << 18;
const DOUBLE_PAWN_PUSH = 0x1 << 16;
const PROMOTION = 0x1 << 19;
const EN_PASSANT = 0x1 << 16;
const KNIGHT_PROMOTION: u32 = 0x0;
const BISHOP_PROMOTION: u32 = 0x1 << 16;
const ROOK_PROMOTION: u32 = 0x1 << 17;
const QUEEN_PROMOTION: u32 = 0x3 << 16;

pub const KING_CASTLE: u32 = 0x1 << 17;
pub const QUEEN_CASTLE: u32 = 0x3 << 16;

const FROM_INDEX_OFFSET: u8 = 8;

pub fn createQuietMove(from: u8, to: u8) u32 {
    return to | @shlExact(@intCast(u16, from), FROM_INDEX_OFFSET);
}

pub fn createDoublePawnPush(from: u8, to: u8) u32 {
    return createQuietMove(from, to) | DOUBLE_PAWN_PUSH;
}

// Create a capture move between two indices.
pub fn createCaptureMove(from: u8, to: u8) u32 {
    return createQuietMove(from, to) | CAPTURE;
}

// Create a promotion move between two indices, promoting to the given piece
// type.
pub fn createPromotionMove(from: u8, to: u8, pieceType: PieceType) u32 {
    return createQuietMove(from, to)
        | PROMOTION
        | switch (pieceType) {
            PieceType.knight => KNIGHT_PROMOTION,
            PieceType.bishop => BISHOP_PROMOTION,
            PieceType.rook => ROOK_PROMOTION,
            PieceType.queen => QUEEN_PROMOTION,
            else => 0,
        };
}

// Create a promotion capture move between two indices, promoting to the given
// piece type.
pub fn createPromotionCaptureMove(from: u8, to: u8, pieceType: PieceType) u32 {
    return createPromotionMove(from, to, pieceType) | CAPTURE;
}

// Create an en passant capture between two indices.
pub fn createEnPassantCaptureMove(from: u8, to: u8) u32 {
    return createCaptureMove(from, to) | EN_PASSANT;
}