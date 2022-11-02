const std = @import("std");
const Position = @import("position.zig").Position;
const Move = @import("move.zig").Move;
const TranspositionData = @import("TranspositionData.zig").TranspositionData;

// TODO: make configurable
const TABLE_SIZE: u64 = std.math.pow(u64, 2, 8);

const Key = u64;

const TableEntry = struct { key: Key, evaluation: i64, data: u64, move: Move };

// TranspositionTable is a lockless shared hash table using
// Hyatt and Mann's XOR method as a crude checksum.
pub const TranspositionTable = struct {
    hashmap: []TableEntry,

    allocator: std.mem.Allocator,

    pub fn init(a: std.mem.Allocator) !TranspositionTable {
        var hashmap = try a.alloc(TableEntry, TABLE_SIZE);

        var i: u64 = 0;
        while (i < TABLE_SIZE) {
            hashmap[i].key = 0;

            i += 1;
        }

        return TranspositionTable{ .hashmap = hashmap, .allocator = a };
    }

    pub fn deinit(self: TranspositionTable) void {
        self.allocator.free(self.hashmap);
    }

    // TODO: think about replacement policy; this currently clobbers
    pub fn put(self: TranspositionTable, position: Position, data: TranspositionData) void {
        const key = self.zobrist.hash(position);
        const i = key % TABLE_SIZE;

        const evaluation = data.evaluation;
        const move = data.move;
        const extra_data = (@as(data.flags, u64) << 8) | data.depth;

        // Each 64-bit value can be stored atomically, but we can't atomically
        // store more than that. Therefore we use a simple checksum, XOR-ing the key
        // with the data.
        // On retrieval, if the checksum is OK, we know that the operation was
        // VERY LIKELY atomic.
        //
        // From a cursory glance at the LLVM docs, Unordered should be good enough
        // to prevent weird half-written values
        @atomicStore(u64, self.hashmap[i].key, key ^ evaluation ^ move ^ extra_data, std.builtin.AtomicOrder.Unordered);
        @atomicStore(u64, self.hashmap[i].evaluation, evaluation, std.builtin.AtomicOrder.Unordered);
        @atomicStore(u64, self.hashmap[i].move, move, std.builtin.AtomicOrder.Unordered);
        @atomicStore(u64, self.hashmap[i].data, extra_data, std.builtin.AtomicOrder.Unordered);
    }

    // If no value is returned, either there's no relevant entry or it's been
    // corrupted
    pub fn get(self: TranspositionTable, position: Position) ?TranspositionData {
        const key = self.zobrist.hash(position);
        const i = key % TABLE_SIZE;

        if (self.hashmap[i].key > 0) {
            if ((self.hashmap[i].key ^ self.hashmap[i].evaluations ^ self.hashmap[i].moves ^ self.hashmap[i].data) == key) {
                return .{ .evaluation = self.hashmap[i].evaluation, .move = self.hashmap[i].moves, .depth = @as(self.hashmap[i].data & 0xFF, u8), .flags = @as(self.hashmap[i].data >> 8, u8) };
            }
        }

        return null;
    }
};
