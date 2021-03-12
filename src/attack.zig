const position = @import("./position.zig");
const piece = @import("./piece.zig");
const Color = piece.Color;
const PieceType = piece.PieceType;
const std = @import("std");

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

const NOT_A: u64 = 0xfefefefefefefefe;
const NOT_H: u64 = 0x7f7f7f7f7f7f7f7f;


// The following declaration is an attack map, which represents the ability of
// pieces to attack each other around the board. This is used for quick lookups -
// we can skip generating attacks for a Queen, for example, if we know already that
// its position couldn't possibly attack the King.
// This attack map, and the associated method, was created by Jonatan Pettersson.
// See his guide here:
// https://mediocrechess.blogspot.com.au/2006/12/guide-attacked-squares.html

const AttackType = enum(u8) {
    attack_none  = 0,
    attack_KQR   = 1,
    attack_QR    = 2,
    attack_KQBwP = 3,
    attack_KQBbP = 4,
    attack_QB    = 5,
    attack_N     = 6,
};

const ATTACK_ARRAY = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0,
    0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 5, 0,
    0, 0, 0, 5, 0, 0, 0, 0, 2, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0,
    5, 0, 0, 0, 2, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0,
    2, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 6, 2, 6, 5, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 4, 1, 4, 6, 0, 0, 0, 0, 0,
    0, 2, 2, 2, 2, 2, 2, 1, 0, 1, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0,
    0, 0, 6, 3, 1, 3, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 6,
    2, 6, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 2, 0, 0, 5,
    0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 2, 0, 0, 0, 5, 0, 0, 0,
    0, 0, 0, 5, 0, 0, 0, 0, 2, 0, 0, 0, 0, 5, 0, 0, 0, 0, 5, 0,
    0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 5, 0, 0, 5, 0, 0, 0, 0, 0, 0,
    2, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

// isAttacked determines if a piece is under attack. It takes the current game
// position, the index of the piece in question (in 0x88 form).
pub fn isAttacked(pos: position.Position, target_index: u8, attacker: Color) bool {
    // Declare bitboards for representing the pieces present. While the normal board position is in 0x88 form, these
    // bitboards don't require the extra squares and simple represent an 8x8 grid, meaning that they can fit in a
    // 64-bit integer.

    // attack_map represents the squares currently under attack.
    var attack_map: u64 = 0;

    // empty represents squares with no pieces.
    var empty: u64 = 0;

    // The other bitboards hold the positions of sliding pieces.
    var queens: u64 = 0;
    var rooks: u64 = 0;
    var bishops: u64 = 0;

    // Loop through every index on the board, skipping over indices that fall
    // outside the visible playing area.
    for (pos.board) |p, i| {
        if (!position.isOnBoard(@intCast(u8, i))) {
            continue;
        }

        // If there is a piece present, but it isn't on the attacking side,
        // we can skip the iteration.
        if (p != 0 and piece.pieceColor(p) != attacker) {
            continue;
        }

        // Look up the pieces that can attack the target from this index,
        // using the attack array declared above. The lookup returns a
        // constant representing the set of possible pieces.
        const attack_array_index: usize = @intCast(usize, @intCast(isize, target_index) - @intCast(isize, i) + 128);
        const can_attack: AttackType = @intToEnum(AttackType, ATTACK_ARRAY[attack_array_index]);

        // Convert the index in 0x88 form to the standard 8x8 form.
        const index: u6 = @intCast(u6, map0x88ToStandard(@intCast(u8, i)));


        // Moves are generated differently depending on the type of piece.
        // Non-sliding pieces can simply be checked against the can_attack
        // constant generated previously. If they are found to be
        // attacking, we can return early and save computations.
        // Sliding pieces are first checked against this constant, which
        // saves costly move generation if it's impossible for them to ever
        // attack the target square. If they could attack it, they are
        // added to the relevant bitboard for later generation.
        switch (piece.pieceType(p)) {
            PieceType.queen =>
                if (can_attack == AttackType.attack_none or can_attack == AttackType.attack_N) {
                    continue;
                } else {
                    queens |= @shlExact(@intCast(u64, 1), index);
                },
            PieceType.bishop =>
                if (!(can_attack == AttackType.attack_KQBbP or can_attack == AttackType.attack_KQBwP or can_attack == AttackType.attack_QB)) {
                    continue;
                } else {
                    bishops |= @shlExact(@intCast(u64, 1), index);
                },
            PieceType.rook =>
                if (!(can_attack == AttackType.attack_KQR or can_attack == AttackType.attack_QR)) {
                    continue;
                } else {
                    rooks |= @shlExact(@intCast(u64, 1), index);
                },
            PieceType.knight =>
                if (can_attack == AttackType.attack_N) {
                    return true;
                },
            PieceType.pawn =>
                if ((attacker == Color.white and can_attack == AttackType.attack_KQBwP) or (attacker == Color.black and can_attack == AttackType.attack_KQBbP)) {
                    return true;
                },
            PieceType.king =>
                if (can_attack == AttackType.attack_KQR or can_attack == AttackType.attack_KQBbP or can_attack == AttackType.attack_KQBwP) {
                    return true;
                },
            else =>
                empty |= @shlExact(@intCast(u64, 1), index),
        }
    }

    
    // Now that the bitboards have been filled by sliding pieces, we can generate
    // the attack map. To do this, we use the Dumb7Fill algorithm, implemented
    // based on the site https://chessprogramming.wikispaces.com/Dumb7Fill.
    // For each direction a sliding piece could move, these moves are generated,
    // following a three step process:
    //     1. The pieces that can make that move have their bitboards combined with bitwise OR. For example, only queens and rooks can attack directly east, so we only combine their bitboards.
    //     2. The bitboard is shifted according to the algorithm, which moves the pieces in the relevant direction until they hit a non-empty square (which blocks the attack.)
    //     3. These moves are combined with the overall attack map using bitwise OR.
    
    attack_map |= south_attacks(queens|rooks, empty);
    attack_map |= north_attacks(queens|rooks, empty);
    attack_map |= east_attacks(queens|rooks, empty);
    attack_map |= west_attacks(queens|rooks, empty);
    attack_map |= north_east_attacks(queens|bishops, empty);
    attack_map |= north_west_attacks(queens|bishops, empty);
    attack_map |= south_east_attacks(queens|bishops, empty);
    attack_map |= south_west_attacks(queens|bishops, empty);

    // Finally, we check whether the target index is attacked in the attack map
    // and return true if possible.
    return attack_map & @shlExact(@intCast(u64, 1), @intCast(u6, map0x88ToStandard(target_index))) != 0;
}



fn map0x88ToStandard(index: u8) u8 {
    const rank: u8 = index / 16;
    const file: u8 = index % 16;
    return rank * 8 + file;
}

fn south_attacks(start_const: u64, empty: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;

    while (start != 0) {
        flood |= start;
        start = (start >> 8) & empty;
    }

    return flood >> 8;
}

fn north_attacks(start_const: u64, empty: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;

    while (start != 0) {
        flood |= start;
        start = (start << 8) & empty;
    }

    return flood << 8;
}

fn east_attacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_A;
    while (start != 0) {
        flood |= start;
        start = (start << 1) & empty;
    }

    return (flood << 1) & NOT_A;
}

fn west_attacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_H;
    while (start != 0) {
        flood |= start;
        start = (start >> 1) & empty;
    }

    return (flood >> 1) & NOT_H;
}

fn north_east_attacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_A;

    while (start != 0) {
        flood |= start;
        start = (start << 9) & empty;
    }

    return (flood << 9) & NOT_A;

}

fn north_west_attacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_H;

    while (start != 0) {
        flood |= start;
        start = (start << 7) & empty;
    }

    return (flood << 7) & NOT_H;
}

fn south_east_attacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_A;

    while (start != 0) {
        flood |= start;
        start = (start >> 7) & empty;
    }

    return (flood >> 7) & NOT_A;
}

fn south_west_attacks(start_const: u64, empty_const: u64) u64 {
    var flood: u64 = 0;
    var start: u64 = start_const;
    var empty: u64 = empty_const;

    empty &= NOT_H;

    while (start != 0) {
        flood |= start;
        start = (start >> 9) & empty;
    }

    return (flood >> 9) & NOT_H;
}
