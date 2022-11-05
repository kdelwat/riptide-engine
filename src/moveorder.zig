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

const MOVE_METADATA_ARRAY_SIZE = 64 * 64;

const MoveOrder = enum(u4) {
    pv = 0,
    capture = 1,
    other = 2,
};

const MoveEvaluation = struct {
    order: MoveOrder,
    see_value: ?i64,
};

pub const MoveOrderer = struct {
    moves: [MOVE_METADATA_ARRAY_SIZE]MoveEvaluation,
    pv: ?Move,

    pub fn init() MoveOrderer {
        var orderer = MoveOrderer{ .moves = undefined, .pv = null };

        orderer.clear();

        return orderer;
    }

    pub fn preprocess(self: *MoveOrderer, pos: *position.Position, moves: []Move) void {
        for (moves) |m| {
            if (self.pv) |known_pv| {
                if (m.eq(known_pv)) {
                    self.moves[self.see_index(m)].order = MoveOrder.pv;
                }
            } else if (m.move_type == move.MoveType.capture) {
                const see_value = evaluateCapture(pos, m);
                self.moves[self.see_index(m)].see_value = see_value;
                self.moves[self.see_index(m)].order = MoveOrder.capture;
            } else {
                self.moves[self.see_index(m)].order = MoveOrder.other;
            }
        }
    }

    pub fn clear(self: *MoveOrderer) void {
        var i: u64 = 0;

        while (i < MOVE_METADATA_ARRAY_SIZE) {
            self.moves[i] = MoveEvaluation{ .see_value = null, .order = MoveOrder.other };
            i += 1;
        }
    }

    pub fn getEvaluation(self: *MoveOrderer, m: Move) MoveEvaluation {
        return self.moves[self.see_index(m)];
    }

    fn see_index(_: *MoveOrderer, m: Move) usize {
        return @intCast(usize, m.from) * 64 + @intCast(usize, m.to);
    }

    pub fn setPV(self: *MoveOrderer, pv: ?Move) void {
        self.pv = pv;
    }
};

pub const MoveOrderContext = struct { position: *position.Position, orderer: *MoveOrderer };

pub fn buildContext(pos: *position.Position, orderer: *MoveOrderer) MoveOrderContext {
    return MoveOrderContext{ .position = pos, .orderer = orderer };
}

pub fn cmp(context: *const MoveOrderContext, a: Move, b: Move) bool {
    const eval_a = context.orderer.getEvaluation(a);
    const eval_b = context.orderer.getEvaluation(b);

    if (eval_a.order == MoveOrder.capture and eval_b.order == MoveOrder.capture) {
        const a_see = eval_a.see_value orelse unreachable;
        const b_see = eval_b.see_value orelse unreachable;

        // Order by descending SEE value
        return a_see > b_see;
    }

    return @intCast(u4, @enumToInt(eval_a.order)) < @intCast(u4, @enumToInt(eval_b.order));
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
    const captured_piece = evaluate.get_piece_value(m.captured_piece_type);
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

        value = std.math.max(0, evaluate.get_piece_value(a.captured_piece_type) - see(pos, to, color.invert(side)));

        make_move.unmakeMove(pos, a, artifacts);
    }
    return value;
}
