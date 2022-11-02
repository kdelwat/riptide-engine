const std = @import("std");
const Position = @import("position.zig").Position;

// https://www.chessprogramming.org/Zobrist_Hashing
pub const Zobrist = struct {
    piece_constants: [64 * 12]u64,

    pub fn init(seed: u64) Zobrist {
        var piece_constants: [64 * 12]u64 = undefined;

        var rng = std.rand.DefaultPrng.init(seed);

        const rand = rng.random();

        var i: u64 = 0;
        while (i < 64) {
            var j: u64 = 0;
            while (j < 12) {
                piece_constants[i * 12 + j] = rand.int(u64);
                j += 1;
            }
            i += 1;
        }

        return .{ .piece_constants = piece_constants };
    }

    pub fn hash(_: Zobrist, _: Position) u64 {
        return 1;
    }
};
