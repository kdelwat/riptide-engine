pub const PieceType = enum(u4) {
    empty = 0,
    pawn = 2,
    knight = 3,
    bishop = 4,
    rook = 5,
    queen = 6,
    king = 7,
};

pub const ALL_PIECE_TYPES: [6]PieceType = .{ .pawn, .knight, .bishop, .rook, .queen, .king };
