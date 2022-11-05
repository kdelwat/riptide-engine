const std = @import("std");
const Allocator = std.mem.Allocator;

const TranspositionTable = @import("TranspositionTable.zig").TranspositionTable;

pub const GameOptions = struct { hash_table_size: u64, threads: u64 };

pub const DEFAULTS = GameOptions{ .hash_table_size = 0, .threads = 1 };

pub const GameData = struct {
    tt: TranspositionTable,

    pub fn init(a: Allocator, opts: GameOptions) !GameData {
        return GameData{ .tt = try TranspositionTable.init(a, opts.hash_table_size) };
    }

    pub fn deinit(self: *GameData) void {
        self.tt.deinit();
    }
};
