const position = @import("position.zig");
const Color = @import("color.zig").Color;
const evaluate = @import("evaluate.zig").evaluate;
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Pawn testing" {
    const expected: i64 = 330;
    var pos = position.fromFEN("8/8/8/8/4P3/3P4/2P5/8 w KQkq - 0 11") catch unreachable;
    expect(evaluate(&pos) == expected);
    pos.to_move = switch (pos.to_move) {
        Color.white => Color.black,
        Color.black => Color.white,
    };
    expect(evaluate(&pos) == -expected);
}

test "Knight, rook, bishop"  {
    const expected: i64 = -685;
    var pos = position.fromFEN("8/5n2/r2r4/8/8/6B1/3B4/8 w KQkq - 0 1") catch unreachable;
    expect(evaluate(&pos) == expected);
    pos.to_move = switch (pos.to_move) {
        Color.white => Color.black,
        Color.black => Color.white,
    };
    expect(evaluate(&pos) == -expected);
}

test "Asymmetrical kings" {
    const expected: i64 = 60;
    var pos = position.fromFEN("8/8/8/8/8/8/8/K4k2 w - - 0 1") catch unreachable;

    expectEqual(expected, evaluate(&pos));

    pos.to_move = switch (pos.to_move) {
        Color.white => Color.black,
        Color.black => Color.white,
    };
    expectEqual(-expected, evaluate(&pos));
}

test "Starting position" {
    const expected: i64 = 0;
    var pos = position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") catch unreachable;

    expectEqual(expected, evaluate(&pos));

    pos.to_move = switch (pos.to_move) {
        Color.white => Color.black,
        Color.black => Color.white,
    };

    expectEqual(-expected, evaluate(&pos));
}