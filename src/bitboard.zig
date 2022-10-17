const std = @import("std");

const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;
const b = @import("./bitboard_ops.zig");

pub const Bitboard = struct {
    // Array of bitboards
    // 0 - white
    // 1 - black
    // 2 - pawn
    // 3 - knight
    // 4 - bishop
    // 5 - rook
    // 6 - queen
    // 7 - king
    boards: [8]u64,

    pub fn init() Bitboard {
        return Bitboard{
            .boards = [8]u64{ 0, 0, 0, 0, 0, 0, 0, 0 },
        };
    }

    pub fn get(self: *Bitboard, piece_type: PieceType, color: Color) u64 {
        return self.boards[@enumToInt(piece_type)] & self.boards[@enumToInt(color)];
    }

    pub fn getColor(self: *Bitboard, color: Color) u64 {
        return self.boards[@enumToInt(color)];
    }

    pub fn getPieceTypeAt(self: *Bitboard, index: u8) PieceType {
        const mask = b.bitboardFromIndex(index);
        if (self.boards[2] & mask != 0) return PieceType.pawn;
        if (self.boards[3] & mask != 0) return PieceType.knight;
        if (self.boards[4] & mask != 0) return PieceType.bishop;
        if (self.boards[5] & mask != 0) return PieceType.rook;
        if (self.boards[6] & mask != 0) return PieceType.queen;
        if (self.boards[7] & mask != 0) return PieceType.king;
        return PieceType.empty;
    }

    // Ensure a bit is set to 1 for the given position
    pub fn setFR(self: *Bitboard, piece_type: PieceType, color: Color, file_index: u8, rank_index: u8) void {
        const mask = b.bitboardFromIndex(bitboardIndex(file_index, rank_index));
        self.boards[@enumToInt(piece_type)] |= mask;
        self.boards[@enumToInt(color)] |= mask;
    }

    pub fn set(self: *Bitboard, piece_type: PieceType, color: Color, index: u8) void {
        const mask = b.bitboardFromIndex(index);
        self.boards[@enumToInt(piece_type)] |= mask;
        self.boards[@enumToInt(color)] |= mask;
    }

    // Ensure a bit is set to 0 for the given position
    pub fn unset(self: *Bitboard, piece_type: PieceType, color: Color, index: u8) void {
        const mask = ~b.bitboardFromIndex(index);
        self.boards[@enumToInt(piece_type)] &= mask;
        self.boards[@enumToInt(color)] &= mask;
    }

    // Return a bitboard where each empty space is set to 1
    pub fn empty(self: Bitboard) u64 {
        return ~(self.boards[@enumToInt(Color.white)] | self.boards[@enumToInt(Color.black)]);
    }

    pub fn occupied(self: Bitboard) u64 {
        return self.boards[@enumToInt(Color.white)] | self.boards[@enumToInt(Color.black)];
    }

    pub fn eq(self: Bitboard, other: Bitboard) bool {
        return std.mem.eql(u64, self.boards[0..], other.boards[0..]);
    }

    pub fn debug(self: Bitboard) void {
        std.debug.print("white: {b}\n", .{self.boards[0]});
        std.debug.print("black: {b}\n", .{self.boards[1]});
        std.debug.print("pawn: {b}\n", .{self.boards[2]});
        std.debug.print("knight: {b}\n", .{self.boards[3]});
        std.debug.print("bishop: {b}\n", .{self.boards[4]});
        std.debug.print("rook: {b}\n", .{self.boards[5]});
        std.debug.print("queen: {b}\n", .{self.boards[6]});
        std.debug.print("king: {b}\n", .{self.boards[7]});
        std.debug.print("empty: {b}\n", .{self.empty()});
        std.debug.print("occupied: {b}\n", .{self.occupied()});
    }
};

// Each bitboard is packed in little-endian rank-file order (LERF)
//
// From https://www.chessprogramming.org/Little-endian:
//
// a1, b1, c1, d1, e1, f1, g1, h1,   0 ..  7
// a2, b2, c2, d2, e2, f2, g2, h2,   8 .. 15
// a3, b3, c3, d3, e3, f3, g3, h3,  16 .. 23
// a4, b4, c4, d4, e4, f4, g4, h4,  24 .. 31
// a5, b5, c5, d5, e5, f5, g5, h5,  32 .. 39
// a6, b6, c6, d6, e6, f6, g6, h6,  40 .. 47
// a7, b7, c7, d7, e7, f7, g7, h7,  48 .. 55
// a8, b8, c8, d8, e8, f8, g8, h8   56 .. 63

pub inline fn bitboardIndex(file_index: u8, rank_index: u8) u8 {
    return 8 * rank_index + file_index;
}

pub inline fn fileIndex(bitboard_index: u8) u8 {
    return bitboard_index & 7;
}

pub inline fn rankIndex(bitboard_index: u8) u8 {
    return bitboard_index >> 3;
}
