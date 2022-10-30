const Move = @import("./move.zig").Move;
const std = @import("std");
const MAX_DEPTH = @import("./movegen.zig").MAX_DEPTH;

const PV_TABLE_SIZE = MAX_DEPTH * MAX_DEPTH;

pub const PVTable = struct {
    data: [PV_TABLE_SIZE]?Move,

    pub fn init() PVTable {
        var t = PVTable{ .data = undefined };

        var i: usize = 0;
        while (i < PV_TABLE_SIZE) {
            t.data[i] = null;

            i += 1;
        }

        return t;
    }

    // Get the best move at a given ply
    pub fn get(self: *PVTable, ply: u64) ?Move {
        return self.data[ply * MAX_DEPTH];
    }

    // Set a new best move for a given ply
    // This will copy down the principal variation from the next ply
    pub fn set(self: *PVTable, ply: u64, m: Move) void {
        // First element for the ply is the PV move
        self.data[ply * MAX_DEPTH] = m;
        self.copyDown(ply + 1);
    }

    // Copy moves down one ply
    // i.e. moves from ply 6 are appended to ply 5's PV
    fn copyDown(self: *PVTable, ply: u64) void {
        var n_moves = MAX_DEPTH - ply;
        var i: u64 = 0;
        while (i < n_moves) {
            self.data[(ply - 1) * MAX_DEPTH + i + 1] = self.data[ply * MAX_DEPTH + i];
            i += 1;
        }
    }
};
