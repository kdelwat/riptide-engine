// Bitboard / setwise operators
// From https://www.chessprogramming.org/General_Setwise_Operations

// Directional shifts

// These constants remove bits from a bitboard on the A and H file respectively.
//
// For example, if we have a bitboard representing attacks of a queen that looks
// like this:
//
//     1 0 0 1 0 0 1 0
//     0 1 0 1 0 1 0 0
//     0 0 1 1 1 0 0 0
//     1 1 1 1 1 1 1 1
//     0 0 1 1 1 0 0 0
//     0 1 0 1 0 1 0 0
//     1 0 0 1 0 0 1 0
//     0 0 0 1 0 0 0 1
//
// A bitwise AND with notA will remove any attacks on the A file:
//
//     0 0 0 1 0 0 1 0
//     0 1 0 1 0 1 0 0
//     0 0 1 1 1 0 0 0
//     0 1 1 1 1 1 1 1
//     0 0 1 1 1 0 0 0
//     0 1 0 1 0 1 0 0
//     0 0 0 1 0 0 1 0
//     0 0 0 1 0 0 0 1

pub const NOT_A_FILE: u64 = 0xfefefefefefefefe;
pub const NOT_H_FILE: u64 = 0x7f7f7f7f7f7f7f7f;

pub inline fn southOne(b: u64) u64 {
    return b >> 8;
}

pub inline fn northOne(b: u64) u64 {
    return b << 8;
}

pub inline fn eastOne(b: u64) u64 {
    return (b << 1) & NOT_A_FILE;
}

pub inline fn northEastOne(b: u64) u64 {
    return (b << 9) & NOT_A_FILE;
}

pub inline fn southEastOne(b: u64) u64 {
    return (b >> 7) & NOT_A_FILE;
}

pub inline fn westOne(b: u64) u64 {
    return (b >> 1) & NOT_H_FILE;
}

pub inline fn southWestOne(b: u64) u64 {
    return (b >> 9) & NOT_H_FILE;
}

pub inline fn northWestOne(b: u64) u64 {
    return (b << 7) & NOT_H_FILE;
}

// Find the least significant 1 in the bitboard
// The caller is responsible for not passing in b == 0
pub inline fn bitscanForward(b: u64) u8 {
    // Count trailing zeroes is equivalent to a bitscan forward
    return @ctz(b);
}

// Find the least significant 1 and remove it.
pub inline fn bitscanForwardAndReset(b: *u64) u8 {
    const ret = bitscanForward(b.*);
    b.* &= b.* - 1;
    return ret;
}

// Generate a bitboard with a 1 at the given index
pub inline fn bitboardFromIndex(index: u8) u64 {
    return @truncate(u64, @as(u256, 1) << index);
}

// Determine whether a bitboard index is on a certain rank
pub fn isOnRank(bitboard_index: u8, rank_index: u8) bool {
    return bitboard_index >= (rank_index * 8) and bitboard_index <= (rank_index * 8 + 7);
}

// Flip a bitboard vertically (invert ranks)
// On supported architectures the @byteSwap builtin will use the intrinsic
// endian conversion instructions
pub inline fn flipV(b: u64) u64 {
    return @byteSwap(b);
}
