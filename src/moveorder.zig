const std = @import("std");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const Move = @import("./move.zig").Move;
const move = @import("./move.zig");
const movegen = @import("./movegen.zig");
const make_move = @import("./make_move.zig");
const attack = @import("./attack.zig");
const evaluate = @import("./evaluate.zig");
const position = @import("./position.zig");

pub const MoveOrderContext = struct {
    position: *position.Position
};

pub fn buildContext(pos: *position.Position, moves: []Move) MoveOrderContext {
    return MoveOrderContext{ .position = pos };
}

pub fn cmp(context: *const MoveOrderContext, a: Move, b: Move) bool {
    // Order captures first
    if (a.move_type == move.MoveType.capture and b.move_type != move.MoveType.capture) {
        return true;
    }

    if (a.move_type == move.MoveType.capture and b.move_type == move.MoveType.capture) {
        const a_see = evaluateCapture(context.position, a);
        const b_see = evaluateCapture(context.position, a);

        return a_see < b_see;
    }

    return @intCast(u4, @enumToInt(a.move_type)) < @intCast(u4, @enumToInt(b.move_type));
}

// Use static exchange evaluation to determine a value for a capture
// https://www.chessprogramming.org/Static_Exchange_Evaluation
//
// The resulting value indicates expected score gain for a capture after all
// counter, counter-counter, ... attacks are resolved for the position.
//
// First, force the capture in question, then recursively evaluate subsequent
// captures. This is NOT the most efficient way to do things, but it works for
// now.
pub fn evaluateCapture(pos: *position.Position, m: Move) i64 {
    const captured_piece = evaluate.get_piece_value(m.captured_piece_type orelse PieceType.empty);
    const artifacts = make_move.makeMove(pos, m);
    const value = captured_piece - see(pos, m.to, color.invert(m.piece_color));
    make_move.unmakeMove(pos, m, artifacts);

    return value;
}

fn see(pos: *position.Position, to: u8, side: Color) i64 {
    var value: i64 = 0;

    const attacker = movegen.findSmallestAttackerMove(pos, to, side);
    if (attacker) |a| {
        const artifacts = make_move.makeMove(pos, a);

        value = std.math.max(0, evaluate.get_piece_value(a.captured_piece_type orelse PieceType.empty) - see(pos, to, color.invert(side)));

        make_move.unmakeMove(pos, a, artifacts);
    }
    return value;
}
