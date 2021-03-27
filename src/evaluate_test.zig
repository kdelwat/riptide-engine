const position = @import("position.zig");
const Color = @import("color.zig").Color;
const evaluate = @import("evaluate.zig").evaluate;
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const test_allocator = std.testing.allocator;

const EvaluateTestCase = struct {
    position: []const u8,
    expected: i64,
};

var EVALUATE_TEST_CASES = [4]EvaluateTestCase{
    EvaluateTestCase{.position = "8/8/8/8/4P3/3P4/2P5/8 w KQkq - 0 11", .expected = 330},
    EvaluateTestCase{.position = "8/5n2/r2r4/8/8/6B1/3B4/8 w KQkq - 0 1", .expected = -685},
    EvaluateTestCase{.position = "8/8/8/8/8/8/8/K4k2 w - - 0 1", .expected = 60},
    EvaluateTestCase{.position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .expected = 0},
};

test "evaluate" {
    for (EVALUATE_TEST_CASES) |test_case| {
        std.debug.print("evaluate: {s}\n", .{test_case.position});
        var pos = position.fromFEN(test_case.position, test_allocator) catch unreachable;
        expectEqual(test_case.expected, evaluate(&pos));
        pos.to_move = switch (pos.to_move) {
            Color.white => Color.black,
            Color.black => Color.white,
        };
        expectEqual(-test_case.expected, evaluate(&pos));
    }
}