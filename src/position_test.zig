const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

const position = @import("./position.zig");

test "fromFEN - empty board" {
    expect(
        comparePositions(
            position.fromFEN("8/8/8/8/8/8/8/8 w KQkq - 0 1"),
            &position.Position{.board = [_]u8{0} ** 128})
    );
}

test "fromFEN - starting board" {
    expect(
        comparePositions(
            position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"),
            &position.Position{.board = [_]u8{
                 5,  2,  4,  7,  3,  4,  2,  5,   0, 0, 0, 0, 0, 0, 0, 0,
                 1,  1,  1,  1,  1,  1,  1,  1,   0, 0, 0, 0, 0, 0, 0, 0,
                 0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                 0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                 0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                 0,  0,  0,  0,  0,  0,  0,  0,   0, 0, 0, 0, 0, 0, 0, 0,
                65, 65, 65, 65, 65, 65, 65, 65,   0, 0, 0, 0, 0, 0, 0, 0,
                69, 66, 68, 71, 67, 68, 66, 69,   0, 0, 0, 0, 0, 0, 0, 0,
            }})
    );
}

fn comparePositions(a: *position.Position, b: *const position.Position) bool {
    // Board
    if (a.board.len != b.board.len) return false;
    for (a.board) |sq, i| {
        if (b.board[i] != sq) return false;
    }

    return true;
}