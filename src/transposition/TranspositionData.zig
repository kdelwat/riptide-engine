const Move = @import("../move.zig").Move;

// Data representing a particular position
pub const TranspositionData = struct { evaluation: i64, move: Move, depth: u8, flags: u8 };
