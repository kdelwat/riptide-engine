const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

const position = @import("./position.zig");
const Color = @import("./piece.zig").Color;

test "fromFEN - empty board" {
    expect(
        position.fromFEN("8/8/8/8/8/8/8/8 w KQkq - 0 1").eq(
            position.Position{
                .board = [_]u8{0} ** 128,
                .to_move = Color.white,
                .castling = 0b1111,
                .en_passant_target = 0,
                .halfmove = 0,
                .fullmove = 1,
            }
        )
    );
}

test "fromFEN - empty board with other data variety" {
    expect(
        position.fromFEN("8/8/8/8/8/8/8/8 b Kq a6 36 113").eq(
            position.Position{
                .board = [_]u8{0} ** 128,
                .to_move = Color.black,
                .castling = 0b1001,
                .en_passant_target = 0x50,
                .halfmove = 36,
                .fullmove = 113,
            }
        )
    );
}

test "fromFEN - starting board" {
    expect(
        position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1").eq(
            position.Position{
                .board = [_]u8{
                     5,  2,  4,  7,  3,  4,  2,  5,   0, 0, 0, 0, 0, 0, 0, 0,
                     1,  1,  1,  1,  1,  1,  1,  1,   0, 0, 0, 0, 0, 0, 0, 0,
                     0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                     0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                     0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                     0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                    65, 65, 65, 65, 65, 65, 65, 65,   0, 0, 0, 0, 0, 0, 0, 0,
                    69, 66, 68, 71, 67, 68, 66, 69,   0, 0, 0, 0, 0, 0, 0, 0,
                },
                .to_move = Color.white,
                .castling = 0b1111,
                .en_passant_target = 0,
                .halfmove = 0,
                .fullmove = 1,
            }
        )
    );
}

test "converting between rank-and-file and 0x88 positions" {
    const a = position.RankAndFile{.rank = 7, .file = 5};

    expect(position.ex88ToRf(position.rfToEx88(a)).eq(a));
}

