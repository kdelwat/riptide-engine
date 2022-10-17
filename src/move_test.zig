const std = @import("std");
const expectEqualStrings = std.testing.expectEqualStrings;
const Move = @import("./move.zig").Move;
const Color = @import("./color.zig").Color;
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;

test "toLongAlgebraic" {
    const m = Move.initQuiet(8, 24, Color.white, PieceType.pawn);
    var buf: [4]u8 = [_]u8{ 0, 0, 0, 0 };

    m.toLongAlgebraic(buf[0..]) catch unreachable;
    try expectEqualStrings("a2a4", buf[0..]);
}
