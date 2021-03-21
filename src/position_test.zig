const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

const position = @import("./position.zig");
const Bitboard = @import("./bitboard.zig").Bitboard;
const Color = @import("./color.zig").Color;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f) catch unreachable;
}

test "fromFEN - empty board" {
    expect(
        fromFEN("8/8/8/8/8/8/8/8 w KQkq - 0 1").eq(
            position.Position{
                .board = Bitboard{.boards = [_]u64{0} ** 8},
                .to_move = Color.white,
                .castling = 0b1111,
                .en_passant_target = 0,
                .halfmove = 0,
                .fullmove = 1,
                .king_indices = [2]u8{0, 0},
            }
        )
    );
}

test "fromFEN - empty board with other data variety" {
    expect(
        fromFEN("8/8/8/8/8/8/8/8 b Kq a6 36 113").eq(
            position.Position{
                .board = Bitboard{.boards = [_]u64{0} ** 8},
                .to_move = Color.black,
                .castling = 0b1001,
                .en_passant_target = 40,
                .halfmove = 36,
                .fullmove = 113,
                .king_indices = [2]u8{0, 0},
            }
        )
    );
}

test "fromFEN - bug" {
    expect(
        fromFEN("8/8/8/8/8/8/8/8 b KQkq - 1 2").eq(
            position.Position{
                .board = Bitboard{.boards = [_]u64{0} ** 8},
                .to_move = Color.black,
                .castling = 0b1111,
                .en_passant_target = 0,
                .halfmove = 1,
                .fullmove = 2,
                .king_indices = [2]u8{0, 0},
            }
        )
    );
}

test "fromFEN - starting board" {
    expect(
        fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1").eq(
            position.Position{
                .board = Bitboard{.boards = [8]u64{
                     0b1111111111111111000000000000000000000000000000000000000000000000,
                     0b0000000000000000000000000000000000000000000000001111111111111111,
                     0b0000000011111111000000000000000000000000000000001111111100000000,
                     0b0100001000000000000000000000000000000000000000000000000001000010,
                     0b0010010000000000000000000000000000000000000000000000000000100100,
                     0b1000000100000000000000000000000000000000000000000000000010000001,
                     0b0000100000000000000000000000000000000000000000000000000000001000,
                     0b0001000000000000000000000000000000000000000000000000000000010000,
                 }},
                .to_move = Color.white,
                .castling = 0b1111,
                .en_passant_target = 0,
                .halfmove = 0,
                .fullmove = 1,
                .king_indices = [2]u8{0, 0},
            }
        )
    );
}

