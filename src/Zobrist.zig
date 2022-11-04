const std = @import("std");
const Position = @import("position.zig").Position;
const piece = @import("piece.zig");
const color = @import("color.zig");
const Bitboard = @import("./bitboard.zig").Bitboard;
const move = @import("move.zig");

const b = @import("./bitboard_ops.zig");
const SEED = 69;

const N_SQUARES = 64;
const N_PIECES = 8;
const N_COLORS = 2;
const PIECE_CONSTANTS: [N_SQUARES][N_PIECES][N_COLORS]u64 = generatePieceConstants();

const N_CASTLING_PERMUTATIONS = 16;
const CASTLING_CONSTANTS: [N_CASTLING_PERMUTATIONS]u64 = generateCastlingConstants();

const SIDE_CONSTANTS: [N_COLORS]u64 = .{ 0, generateBlackSideConstant() };

const N_FILES = 8;
const EN_PASSANT_CONSTANTS: [N_FILES + 1]u64 = generateEnPassantConstants();

fn generatePieceConstants() [N_SQUARES][N_PIECES][N_COLORS]u64 {
    var constants: [N_SQUARES][N_PIECES][N_COLORS]u64 = undefined;

    var rng = std.rand.DefaultPrng.init(SEED);

    const rand = rng.random();

    // The default limit for comptime code is hit in this nested loop,
    // so bump it up
    @setEvalBranchQuota(N_SQUARES * N_PIECES * N_COLORS * 100);

    var sq: u64 = 0;
    while (sq < N_SQUARES) {
        var p: u64 = 0;
        while (p < N_PIECES) {
            var c: u64 = 0;
            while (c < N_COLORS) {
                constants[sq][p][c] = rand.int(u64);
                c += 1;
            }
            p += 1;
        }
        sq += 1;
    }

    return constants;
}

fn generateCastlingConstants() [N_CASTLING_PERMUTATIONS]u64 {
    var constants: [N_CASTLING_PERMUTATIONS]u64 = undefined;

    var rng = std.rand.DefaultPrng.init(SEED + 1);

    const rand = rng.random();

    var i: u64 = 0;
    while (i < N_CASTLING_PERMUTATIONS) {
        constants[i] = rand.int(u64);
        i += 1;
    }

    return constants;
}

fn generateBlackSideConstant() u64 {
    var rng = std.rand.DefaultPrng.init(SEED + 2);

    const rand = rng.random();

    return rand.int(u64);
}

fn generateEnPassantConstants() [N_FILES + 1]u64 {
    var constants: [N_FILES + 1]u64 = undefined;

    var rng = std.rand.DefaultPrng.init(SEED + 3);

    const rand = rng.random();

    var i: u64 = 0;
    while (i < N_FILES + 1) {
        constants[i] = rand.int(u64);
        i += 1;
    }

    return constants;
}

// Compute a hash from an initial position
// This is quite slow, but we only need to do it once for a new starting
// position. From then on, the hash is updated incrementally.
pub fn hash(board: *Bitboard, castling: u4, to_move: color.Color, en_passant_target: u8) u64 {
    var z: u64 = 0;

    for (piece.ALL_PIECE_TYPES) |piece_type| {
        for (color.ALL_COLORS) |piece_color| {
            var pieces = board.get(piece_type, piece_color);

            while (pieces != 0) {
                const i = b.bitscanForwardAndReset(&pieces);
                z |= PIECE_CONSTANTS[i][@enumToInt(piece_type)][@enumToInt(piece_color)];
            }
        }
    }

    z |= CASTLING_CONSTANTS[castling];
    z |= SIDE_CONSTANTS[@enumToInt(to_move)];
    z |= EN_PASSANT_CONSTANTS[@ctz(en_passant_target)];

    return z;
}

pub fn update(pos: *Position, _: move.Move) u64 {
    return hash(&pos.board, pos.castling, pos.to_move, pos.en_passant_target);
}
