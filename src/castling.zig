const Color = @import("./color.zig").Color;

// Manage the castling nibble
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

pub const CanCastle = enum(u4) {
    white_king = 0b1000,
    white_queen = 0b0100,
    black_king = 0b0010,
    black_queen = 0b0001,
    invalid = 0,
};

pub const CastleSide = enum {
    king,
    queen,
};

pub fn hasCastlingRight(c: u4, player: Color, side: CastleSide) bool {
    var offset: u4 = 3;

    if (side == CastleSide.queen) {
        offset -= 1;
    }

    if (player == Color.black) {
        offset -= 2;
    }

    return (c & (@as(u32, 1) << offset)) != 0;
}

pub fn updateCastling(c: u4, side: CastleSide, player: Color, can_castle: bool) u4 {
    var new_castling: u4 = c;
    var offset: u3 = 3;

    if (side == CastleSide.queen) {
        offset -= 1;
    }

    if (player == Color.black) {
        offset -= 2;
    }

    if (can_castle) {
        new_castling |= @intCast(u4, @shlExact(@intCast(u8, 1), offset));
    } else {
        new_castling &= @truncate(u4, ~@shlExact(@intCast(u8, 1), offset));
    }

    return new_castling;
}
