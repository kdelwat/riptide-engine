const position = @import("./position.zig");
const piece = @import("./piece.zig");
const Color = @import("./color.zig").Color;
const PieceType = piece.PieceType;
const std = @import("std");
usingnamespace @import("./bitboard_ops.zig");

// King attack indices, based on https://www.chessprogramming.org/King_Pattern#KingAttacks
// We can generate the final KING_ATTACKS array at compile time, which gives an attack
// bitboard for each king position.
fn generateKingAttackBitboard(king_bitboard: u64) u64 {
   var temp_king_bitboard = king_bitboard;
   var attacks = eastOne(temp_king_bitboard) | westOne(temp_king_bitboard);
   temp_king_bitboard |= attacks;
   attacks |= northOne(temp_king_bitboard) | southOne(temp_king_bitboard);
   return attacks;
}

fn generateKingAttackArray() [64]u64 {
    var array: [64]u64 = undefined;

    var i: u7 = 0;
    while (i < 64) {
        array[i] = generateKingAttackBitboard(@truncate(u64, @as(u128, 1) << i));
        i += 1;
    }

    return array;
}

const KING_ATTACKS: [64]u64 = comptime generateKingAttackArray();

// Knight attack indices, based on https://www.chessprogramming.org/Knight_Pattern#KnightAttacks
// We can generate the final KNIGHT_ATTACKS array at compile time, which gives an attack
// bitboard for each knight position.
fn generateKnightAttackBitboard(knight_bitboard: u64) u64 {
   var temp_bitboard = knight_bitboard;
   var attacks: u64 = 0;
   var east = eastOne(temp_bitboard);
   var west = westOne(temp_bitboard);

   attacks = (east | west) << 16;
   attacks |= (east | west) >> 16;

   east = eastOne(east);
   west = westOne(west);

   attacks |= (east | west) << 8;
   attacks |= (east | west) >> 8;

   return attacks;
}

fn generateKnightAttackArray() [64]u64 {
    var array: [64]u64 = undefined;

    var i: u7 = 0;
    while (i < 64) {
        array[i] = generateKnightAttackBitboard(@truncate(u64, @as(u128, 1) << i));
        i += 1;
    }

    return array;
}

pub const KNIGHT_ATTACKS: [64]u64 = comptime generateKnightAttackArray();

// Pawn attack indices, based on https://www.chessprogramming.org/Pawn_Attacks_(Bitboards)
// We can generate the final PAWN_ATTACKS array at compile time, which gives an attack
// bitboard for each pawn position.
pub fn generateWhitePawnAttackBitboard(pawn_bitboard: u64) u64 {
   return northEastOne(pawn_bitboard) | northWestOne(pawn_bitboard);
}

pub fn generateWhitePawnEastAttacks(pawn_bitboard: u64) u64 {
   return northEastOne(pawn_bitboard) | northWestOne(pawn_bitboard);
}

pub fn generateBlackPawnAttackBitboard(pawn_bitboard: u64) u64 {
   return southEastOne(pawn_bitboard) | southWestOne(pawn_bitboard);
}

pub fn generateAttackMap(pos: *position.Position, attacker: Color) u64 {
    // attack_map represents the squares currently under attack.
    var attack_map: u64 = 0;

    // The other bitboards hold the positions of sliding pieces.
    const queens: u64 = pos.board.get(PieceType.queen, attacker);
    const rooks: u64 = pos.board.get(PieceType.rook, attacker);
    const bishops: u64 = pos.board.get(PieceType.bishop, attacker);

    // TODO: May need to filter this to only empty positions on attacking side?
    const empty: u64 = pos.board.empty();

    // Generate the attacks of all sliding pieces.
    // To do this, we use the Dumb7Fill algorithm, implemented
    // based on the site https://chessprogramming.wikispaces.com/Dumb7Fill.
    // For each direction a sliding piece could move, these moves are generated,
    // following a three step process:
    //
    //     1. The pieces that can make that move have their bitboards combined with bitwise OR. For example, only queens
    //        and rooks can attack directly east, so we only combine their bitboards.
    //     2. The bitboard is shifted according to the algorithm, which moves the pieces in the relevant direction until
    //        they hit a non-empty square (which blocks the attack.)
    //     3. These moves are combined with the overall attack map using bitwise OR.
    attack_map |= southAttacks(queens|rooks, empty);
    attack_map |= northAttacks(queens|rooks, empty);
    attack_map |= eastAttacks(queens|rooks, empty);
    attack_map |= westAttacks(queens|rooks, empty);
    attack_map |= northEastAttacks(queens|bishops, empty);
    attack_map |= northWestAttacks(queens|bishops, empty);
    attack_map |= southEastAttacks(queens|bishops, empty);
    attack_map |= southWestAttacks(queens|bishops, empty);

    // Pawn attack generation
    attack_map |= switch (attacker) {
        Color.white => generateWhitePawnAttackBitboard(pos.board.get(PieceType.pawn, attacker)),
        Color.black => generateBlackPawnAttackBitboard(pos.board.get(PieceType.pawn, attacker)),
    };

    // Knight attack generation
    var knights = pos.board.get(PieceType.knight, attacker);
    while (knights != 0) {
        const i = bitscanForwardAndReset(&knights);
        attack_map |= KNIGHT_ATTACKS[i];
    }

    // King attack generation
    attack_map |= KING_ATTACKS[pos.getIndexOfKing(attacker)];

    return attack_map;
}

pub fn isSquareAttacked(attack_map: u64, index: u8) bool {
    return (attack_map & (@as(u64, 1) << @truncate(u6, index))) > 0;
}

fn southAttacks(start_const: u64, empty: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;

    while (start != 0) {
        flood |= start;
        start = (start >> 8) & empty;
    }

    return flood >> 8;
}

fn northAttacks(start_const: u64, empty: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;

    while (start != 0) {
        flood |= start;
        start = (start << 8) & empty;
    }

    return flood << 8;
}

fn eastAttacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_A_FILE;
    while (start != 0) {
        flood |= start;
        start = (start << 1) & empty;
    }

    return (flood << 1) & NOT_A_FILE;
}

fn westAttacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_H_FILE;
    while (start != 0) {
        flood |= start;
        start = (start >> 1) & empty;
    }

    return (flood >> 1) & NOT_H_FILE;
}

fn northEastAttacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_A_FILE;

    while (start != 0) {
        flood |= start;
        start = (start << 9) & empty;
    }

    return (flood << 9) & NOT_A_FILE;

}

fn northWestAttacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_H_FILE;

    while (start != 0) {
        flood |= start;
        start = (start << 7) & empty;
    }

    return (flood << 7) & NOT_H_FILE;
}

fn southEastAttacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_A_FILE;

    while (start != 0) {
        flood |= start;
        start = (start >> 7) & empty;
    }

    return (flood >> 7) & NOT_A_FILE;
}

fn southWestAttacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_H_FILE;

    while (start != 0) {
        flood |= start;
        start = (start >> 9) & empty;
    }

    return (flood >> 9) & NOT_H_FILE;
}
