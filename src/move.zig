const piece = @import("./piece.zig");
const PieceType = piece.PieceType;

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

// Empty move
pub const NULL_MOVE = 0;

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

// Get the from index of a move
pub fn fromIndex(m: u32) u8 {
    return @intCast(u8, (m & (0xFF << 8)) >> 8);
}
// Get the to index of a move
pub fn toIndex(m: u32) u8 {
    return @intCast(u8, m & 0xFF);
}

// Extract the piece that the move promotes to, in the case of promotions or
// promotion capture. This information is encoded in the special section of the
// move, as in the above table.
const PROMOTION_MASK = 0x3 << 16;
pub fn getPromotedPiece(m: u32, piece_promoted: u8) u8 {
    var new_piece: u8 = 0;

    switch (m & PROMOTION_MASK) {
        BISHOP_PROMOTION => new_piece |= @enumToInt(PieceType.bishop),
        KNIGHT_PROMOTION => new_piece |= @enumToInt(PieceType.knight),
        QUEEN_PROMOTION => new_piece |= @enumToInt(PieceType.queen),
        ROOK_PROMOTION => new_piece |= @enumToInt(PieceType.rook),
        else => unreachable,
    }

    new_piece |= @enumToInt(piece.pieceColor(piece_promoted));

    return new_piece;
}

const MOVE_TYPE_MASK = 0xF << 16;

// Is the move a quiet move?
pub fn isQuiet(m: u32) bool {
    return (m & MOVE_TYPE_MASK == 0);
}

// Is the move a promotion?
pub fn isPromotion(m: u32) bool {
    return (m & PROMOTION != 0);
}

// Is the move a promotion capture?
pub fn isPromotionCapture(m: u32) bool {
    return isPromotion(m) and (m & CAPTURE != 0);
}

// Is the move a capture?
pub fn isCapture(m: u32) bool {
    return (m & CAPTURE != 0);
}

// Is the move a castle?
pub fn isCastle(m: u32) bool {
    return isKingCastle(m) or isQueenCastle(m);
}

// Is the move a kingside castle?
pub fn isKingCastle(m: u32) bool {
    return ((m & MOVE_TYPE_MASK)>>16 == 2);
}

// Is the move a queenside castle?
pub fn isQueenCastle(m: u32) bool {
    return ((m & MOVE_TYPE_MASK)>>16 == 3);
}

// Is the move a double pawn push?
pub fn isDoublePawnPush(m: u32) bool {
    return ((m & MOVE_TYPE_MASK)>>16 == 1);
}

// Is the move an en passant capture?
pub fn isEnPassantCapture(m: u32) bool {
    return isCapture(m) and (m & EN_PASSANT != 0);
}