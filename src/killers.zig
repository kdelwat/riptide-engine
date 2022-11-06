const Move = @import("./move.zig").Move;
const std = @import("std");
const MAX_DEPTH = @import("./movegen.zig").MAX_DEPTH;

pub const Killers = struct {
    data: [MAX_DEPTH][2]?Move,

    pub fn init() Killers {
        var t = Killers{ .data = undefined };

        var i: usize = 0;
        while (i < MAX_DEPTH) {
            t.data[i][0] = null;
            t.data[i][1] = null;

            i += 1;
        }

        return t;
    }

    pub fn get_first(self: *Killers, ply: u64) ?Move {
        return self.data[ply][0];
    }

    pub fn get_second(self: *Killers, ply: u64) ?Move {
        return self.data[ply][1];
    }

    pub fn put(self: *Killers, ply: u64, m: Move) void {
        if (self.data[ply][0]) |cur| {
            if (cur.eq(m)) {
                return;
            } else if (self.data[ply][1]) |cur2| {
                if (cur2.eq(m)) {
                    return;
                } else {
                    self.data[ply][1] = m;
                }
            }
        } else {
            self.data[ply][0] = m;
        }
    }
};
