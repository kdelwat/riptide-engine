const Move = @import("move.zig").Move;
const MoveType = @import("move.zig").MoveType;
const PieceType = @import("piece.zig").PieceType;
const Color = @import("color.zig").Color;
const evaluate = @import("evaluate.zig");
const search = @import("search.zig");
const std = @import("std");
pub const NodeType = enum(u2) {
    exact,
    lowerbound,
    upperbound,
};

// Data representing a particular position
// Packed into 64 bits
pub const TranspositionData = packed struct {
    depth: search.Depth, // 8
    score: evaluate.Score, // 16
    node_type: NodeType, // 2

    // Copied from Move. I think there's a compiler bug when a packed
    // struct is inside a packed struct, and underlying memory is being messed
    // up...
    piece_color: Color, // 1
    captured_piece_color: Color = Color.white, // 1
    piece_type: PieceType, // 4
    captured_piece_type: PieceType = PieceType.empty, // 4
    move_type: MoveType = MoveType.quiet, // 4
    from: u8, // 8
    to: u8, // 8
    padding: u8, // 8

    pub fn init(depth: search.Depth, score: evaluate.Score, node_type: NodeType, move: ?Move) TranspositionData {
        if (move) |m| {
            return TranspositionData{
                .depth = depth,
                .score = score,
                .node_type = node_type,
                .padding = 0,
                .piece_color = m.piece_color,
                .captured_piece_color = m.captured_piece_color,
                .from = m.from,
                .to = m.to,
                .piece_type = m.piece_type,
                .captured_piece_type = m.captured_piece_type,
                .move_type = m.move_type,
            };
        } else {
            return TranspositionData{
                .depth = depth,
                .score = score,
                .node_type = node_type,
                .padding = 0,
                .piece_color = Color.white,
                .captured_piece_color = Color.white,
                .from = 0,
                .to = 0,
                .piece_type = PieceType.empty,
                .captured_piece_type = PieceType.empty,
                .move_type = MoveType.quiet,
            };
        }
    }

    pub fn getMove(self: TranspositionData) ?Move {
        if (self.from == 0 and self.to == 0) {
            return null;
        }

        return Move{ .piece_color = self.piece_color, .captured_piece_color = self.captured_piece_color, .piece_type = self.piece_type, .captured_piece_type = self.captured_piece_type, .move_type = self.move_type, .from = self.from, .to = self.to };
    }
};
