const std = @import("std");
const Position = @import("position.zig").Position;
const Move = @import("move.zig").Move;
const TranspositionData = @import("TranspositionData.zig").TranspositionData;

const Key = u64;

const TableEntry = packed struct { key: Key, data: u64 };

const TableStats = struct {
    n_probe: u64,
    n_hit: u64,
    n_store: u64,
    n_collisions: u64,
};

// TranspositionTable is a lockless shared hash table using
// Hyatt and Mann's XOR method as a crude checksum.
pub const TranspositionTable = struct {
    hashmap: []TableEntry,

    allocator: std.mem.Allocator,

    stats: TableStats,

    n_entries: u64,
    enabled: bool,

    pub fn init(a: std.mem.Allocator, size: u64) !TranspositionTable {
        // Configurable by size in MB
        var n_entries = size * 1000 * 1000 / entrySize();
        var hashmap = try a.alloc(TableEntry, n_entries);

        var i: u64 = 0;
        while (i < n_entries) {
            hashmap[i].key = 0;

            i += 1;
        }

        return TranspositionTable{ .hashmap = hashmap, .allocator = a, .stats = TableStats{ .n_probe = 0, .n_hit = 0, .n_store = 0, .n_collisions = 0 }, .enabled = n_entries > 0, .n_entries = n_entries };
    }

    pub fn deinit(self: TranspositionTable) void {
        self.allocator.free(self.hashmap);
    }

    // TODO: think about replacement policy; this currently clobbers
    pub fn put(self: *TranspositionTable, position: *Position, data: TranspositionData) void {
        if (!self.enabled) {
            return;
        }

        self.stats.n_store += 1;

        const key = position.hash.hash;
        const i = key % self.n_entries;

        // For stats only
        if (self.hashmap[i].key > 0) {
            if ((self.hashmap[i].key ^ self.hashmap[i].data) == self.hashmap[i].key and self.hashmap[i].key != key) {
                self.stats.n_collisions += 1;
            }
        }

        const entry = @bitCast(u64, data);

        // Each 64-bit value can be stored atomically, but we can't atomically
        // store more than that. Therefore we use a simple checksum, XOR-ing the key
        // with the data.
        // On retrieval, if the checksum is OK, we know that the operation was
        // LIKELY atomic.
        //
        // From a cursory glance at the LLVM docs, Unordered should be good enough
        // to prevent weird half-written values
        @atomicStore(u64, @alignCast(@alignOf(u64), &self.hashmap[i].key), key ^ entry, std.builtin.AtomicOrder.Unordered);
        @atomicStore(u64, @alignCast(@alignOf(u64), &self.hashmap[i].data), entry, std.builtin.AtomicOrder.Unordered);
    }

    // If no value is returned, either there's no relevant entry or it's been
    // corrupted
    pub fn get(self: *TranspositionTable, position: *Position) ?TranspositionData {
        if (!self.enabled) {
            return null;
        }

        self.stats.n_probe += 1;
        const key = position.hash.hash;
        const i = key % self.n_entries;

        if (self.hashmap[i].key > 0) {
            if ((self.hashmap[i].key ^ self.hashmap[i].data) == key) {
                self.stats.n_hit += 1;
                const entry = @bitCast(TranspositionData, self.hashmap[i].data);
                return entry;
            }
        }

        return null;
    }
};

fn entrySize() comptime_int {
    return @sizeOf(u64) + @sizeOf(u64);
}
