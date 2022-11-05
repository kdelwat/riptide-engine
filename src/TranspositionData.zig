const Move = @import("move.zig").Move;
const evaluate = @import("evaluate.zig");
const search = @import("search.zig");

pub const NodeType = enum(u2) {
    exact,
    lowerbound,
    upperbound,
};

// Data representing a particular position
pub const TranspositionData = packed struct {
    depth: search.Depth, // 8
    score: evaluate.Score, // 16
    node_type: NodeType, // 2
    move: Move, // 30
    padding: u8,

    pub fn init(depth: search.Depth, score: evaluate.Score, node_type: NodeType, move: ?Move) TranspositionData {
        if (move) |m| {
            return TranspositionData{ .depth = depth, .score = score, .node_type = node_type, .padding = 0, .move = m };
        } else {
            return TranspositionData{ .depth = depth, .score = score, .node_type = node_type, .padding = 0, .move = Move.initEmpty() };
        }
    }
};
