const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const position = @import("./position.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const Move = @import("./move.zig").Move;
const make_move = @import("./make_move.zig");
const attack = @import("./attack.zig");
const debug = @import("./debug.zig");
const castling = @import("./castling.zig");
usingnamespace @import("./bitboard_ops.zig");

const AVERAGE_BRANCHING_FACTOR = 38;
const MAX_DEPTH = 20;
const MOVE_ARRAY_SIZE = AVERAGE_BRANCHING_FACTOR * MAX_DEPTH;

pub const MoveGenerator = struct {
    moves: [MOVE_ARRAY_SIZE]Move,
    next_to_play: [MAX_DEPTH]usize,
    next_to_generate: [MAX_DEPTH]usize,
    ply: usize,

    pub fn init() MoveGenerator {
        return MoveGenerator{
            .moves = undefined, // This can be junk, we'll take care of filling it gradually
            .next_to_play = [_]usize{0} ** MAX_DEPTH,
            .next_to_generate = [_]usize{0} ** MAX_DEPTH,
            .ply = 0,
        };
    }

    pub fn next(self: *MoveGenerator) ?Move {
        if (self.next_to_play[self.ply] == self.next_to_generate[self.ply]) {
            return null;
        }

        self.next_to_play[self.ply] += 1;

        return self.moves[self.next_to_play[self.ply] - 1];
    }

    pub fn generate(self: *MoveGenerator, pos: *position.Position) void {
        // Calling generate will increase the ply by 1, since it's called for each level of the alpha-beta search
        self.ply += 1;

        // Set move pointers to the last value before generation
        self.next_to_generate[self.ply] = self.next_to_generate[self.ply - 1];
        self.next_to_play[self.ply] = self.next_to_generate[self.ply - 1];

        generateMoves(self, pos);

        // TODO: ordering
    }

    pub fn count(self: *MoveGenerator) u64 {
        return self.next_to_generate[self.ply] - self.next_to_play[self.ply];
    }

    fn addLegal(self: *MoveGenerator, move: Move, pos: *position.Position) void {
        const artifacts = make_move.makeMove(pos, move);

        const attack_map = attack.generateAttackMap(pos, pos.to_move);
        if (!isKingInCheck(pos.*, color.invert(pos.to_move), attack_map)) {
            self.add(move);
        }

        make_move.unmakeMove(pos, move, artifacts);
    }

    fn add(self: *MoveGenerator, move: Move) void {
        self.moves[self.next_to_generate[self.ply]] = move;
        self.next_to_generate[self.ply] += 1;
    }
};

// Generate pseudo-legal moves for a position
// Moves will be filtered for legality by the move generator
pub fn generateMoves(moves: *MoveGenerator, pos: *position.Position) void {
    generatePawnMoves(moves, pos) catch unreachable;
    generatePawnCaptures(moves, pos) catch unreachable;
    generateKnightMoves(moves, pos) catch unreachable;
    generateKingMoves(moves, pos) catch unreachable;
    generateCastlingMoves(moves, pos) catch unreachable;
    generateSlidingMoves(moves, pos) catch unreachable;
}

// Generate all non-capture pawn moves, including non-capture promotions
// Works by generating a bitboard for single and double push targets, then converting
// that into a list of moves using a bitscan.
// https://www.chessprogramming.org/Pawn_Pushes_(Bitboards)#PawnPushSetwise
const RANK_4: u64 = 0x00000000FF000000;
const RANK_5: u64 = 0x000000FF00000000;

fn generatePawnMoves(moves: *MoveGenerator, pos: *position.Position) !void {
    const empty = pos.board.empty();
    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    var single_push = switch(pos.to_move) {
        Color.white => northOne(pawns) & pos.board.empty(),
        Color.black => southOne(pawns) & pos.board.empty(),
    };

    var double_push = switch(pos.to_move) {
        Color.white => northOne(single_push) & empty & RANK_4,
        Color.black => southOne(single_push) & empty & RANK_5,
    };

    const promotion_rank = switch(pos.to_move) {
        Color.white => @as(u8, 7),
        Color.black => @as(u8, 0),
    };

    // If the single push results in a pawn ending up on the final rank, generate
    // promotion moves. Otherwise generate a quiet push.
    while (single_push != 0) {
        const to = bitscanForwardAndReset(&single_push);
        const from = switch(pos.to_move) {
            Color.white => to - 8,
            Color.black => to + 8,
        };

        if (isOnRank(to, promotion_rank)) {
            moves.addLegal(Move.initPromotion(from, to, pos.to_move, PieceType.queen), pos);
            moves.addLegal(Move.initPromotion(from, to, pos.to_move, PieceType.knight), pos);
            moves.addLegal(Move.initPromotion(from, to, pos.to_move, PieceType.rook), pos);
            moves.addLegal(Move.initPromotion(from, to, pos.to_move, PieceType.bishop), pos);
        } else {
            moves.addLegal(Move.initQuiet(from, to, pos.to_move, PieceType.pawn), pos);
        }
    }

    // Generate double push moves.
    while (double_push != 0) {
        const to = bitscanForwardAndReset(&double_push);
        const from = switch(pos.to_move) {
            Color.white => to - 16,
            Color.black => to + 16,
        };
        moves.addLegal(Move.initDoublePawnPush(from, to, pos.to_move), pos);
    }
}

fn generatePawnCaptures(moves: *MoveGenerator, pos: *position.Position) !void {
    var opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    if (pos.en_passant_target != 0) {
        opponent_pieces |= bitboardFromIndex(pos.en_passant_target);
    }

    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    var east_captures = switch(pos.to_move) {
        Color.white => northEastOne(pawns) & opponent_pieces,
        Color.black => southEastOne(pawns) & opponent_pieces,
    };

    var west_captures = switch(pos.to_move) {
        Color.white => northWestOne(pawns) & opponent_pieces,
        Color.black => southWestOne(pawns) & opponent_pieces,
    };

    const promotion_rank = switch(pos.to_move) {
        Color.white => @as(u8, 7),
        Color.black => @as(u8, 0),
    };

    // If the capture results in a pawn ending up on the final rank, generate
    // promotion capture moves. Otherwise generate a capture move.
    while (east_captures != 0) {
        const to = bitscanForwardAndReset(&east_captures);
        const from = switch(pos.to_move) {
            Color.white => to - 9,
            Color.black => to + 7,
        };

        const captured_piece_type = pos.board.getPieceTypeAt(to);

        if (isOnRank(to, promotion_rank)) {
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type), pos);
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type), pos);
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type), pos);
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type), pos);
        } else if (to == pos.en_passant_target) {
            moves.addLegal(Move.initEnPassant(from, to, pos.to_move), pos);
        } else {
            moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.pawn, captured_piece_type), pos);
        }
    }

    while (west_captures != 0) {
        const to = bitscanForwardAndReset(&west_captures);
        const from = switch(pos.to_move) {
            Color.white => to - 7,
            Color.black => to + 9,
        };

        const captured_piece_type = pos.board.getPieceTypeAt(to);

        if (isOnRank(to, promotion_rank)) {
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type), pos);
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type), pos);
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type), pos);
            moves.addLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type), pos);
        } else if (to == pos.en_passant_target) {
            moves.addLegal(Move.initEnPassant(from, to, pos.to_move), pos);
        } else {
            moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.pawn, captured_piece_type), pos);
        }
    }
}

fn generateKnightMoves(moves: *MoveGenerator, pos: *position.Position) !void {
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));
    const empty = pos.board.empty();
    var knights = pos.board.get(PieceType.knight, pos.to_move);

    // While there are knights left to process, find the index and generate moves
    // for that knight
    while (knights != 0) {
        const from = bitscanForwardAndReset(&knights);
        const targets = attack.KNIGHT_ATTACKS[from];

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            moves.addLegal(Move.initQuiet(from, to, pos.to_move, PieceType.knight), pos);
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type), pos);
        }
    }
}

fn generateKingMoves(moves: *MoveGenerator, pos: *position.Position) !void {
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));
    const empty = pos.board.empty();
    const from = pos.getIndexOfKing(pos.to_move);

    const targets = attack.KING_ATTACKS[from];
    var quiet = targets & empty;
    var captures = targets & opponent_pieces;

    while (quiet != 0) {
        const to = bitscanForwardAndReset(&quiet);
        moves.addLegal(Move.initQuiet(from, to, pos.to_move, PieceType.king), pos);
    }

    while (captures != 0) {
        const to = bitscanForwardAndReset(&captures);
        const captured_piece_type = pos.board.getPieceTypeAt(to);
        moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.king, captured_piece_type), pos);
    }
}

// TODO: inefficient, can be improved?
fn generateSlidingMoves(moves: *MoveGenerator, pos: *position.Position) !void {
    const empty = pos.board.empty();
    const opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    var queens = pos.board.get(PieceType.queen, pos.to_move);
    var rooks = pos.board.get(PieceType.rook, pos.to_move);
    var bishops = pos.board.get(PieceType.bishop, pos.to_move);

    while (queens != 0) {
        const from = bitscanForwardAndReset(&queens);
        var targets: u64 = 0;
        const bitboard = bitboardFromIndex(from);

        targets |= attack.southAttacks(bitboard, empty);
        targets |= attack.northAttacks(bitboard, empty);
        targets |= attack.eastAttacks(bitboard, empty);
        targets |= attack.westAttacks(bitboard, empty);
        targets |= attack.northEastAttacks(bitboard, empty);
        targets |= attack.northWestAttacks(bitboard, empty);
        targets |= attack.southEastAttacks(bitboard, empty);
        targets |= attack.southWestAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            moves.addLegal(Move.initQuiet(from, to, pos.to_move, PieceType.queen), pos);
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type), pos);
        }
    }

    while (rooks != 0) {
        const from = bitscanForwardAndReset(&rooks);
        var targets: u64 = 0;
        const bitboard = bitboardFromIndex(from);
        targets |= attack.southAttacks(bitboard, empty);
        targets |= attack.northAttacks(bitboard, empty);
        targets |= attack.eastAttacks(bitboard, empty);
        targets |= attack.westAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            moves.addLegal(Move.initQuiet(from, to, pos.to_move, PieceType.rook), pos);
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type), pos);
        }
    }

    while (bishops != 0) {
        const from = bitscanForwardAndReset(&bishops);
        var targets: u64 = 0;
        const bitboard = bitboardFromIndex(from);

        targets |= attack.northEastAttacks(bitboard, empty);
        targets |= attack.northWestAttacks(bitboard, empty);
        targets |= attack.southEastAttacks(bitboard, empty);
        targets |= attack.southWestAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = bitscanForwardAndReset(&quiet);
            moves.addLegal(Move.initQuiet(from, to, pos.to_move, PieceType.bishop), pos);
        }

        while (captures != 0) {
            const to = bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addLegal(Move.initCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type), pos);
        }
    }
}

fn generateCastlingMoves(moves: *MoveGenerator, pos: *position.Position) !void {
    // Return early if no castling is possible; this saves the attack generation cost
    if (!castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.king)
        and !castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.queen)) {
        return;
    }

    // Generate an attack map for the opponent, to test for check and castling through
    // check
    const attack_map = pos.generateAttackMap(color.invert(pos.to_move));

    // TODO: can do a faster check here? That doesn't involve creating an attack map if not necessary
    if (isKingInCheck(pos.*, pos.to_move, attack_map)) {
        return;
    }

    // Kingside castle
    if (castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.king) and clearToCastle(pos, castling.CastleSide.king, attack_map)) {
        moves.addLegal(Move.initKingsideCastle(pos.to_move), pos);
    }

    if (castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.queen) and clearToCastle(pos, castling.CastleSide.queen, attack_map)) {
        moves.addLegal(Move.initQueensideCastle(pos.to_move), pos);
    }
}

// CASTLING_BLOCKS declares the indices which, if they contain a piece, can block
// castling to that side for each colour.
const CASTLING_BLOCKS = [4][3]u8{
    [_]u8{5, 6, 0}, // White king
    [_]u8{1, 2, 3}, // White queen
    [_]u8{61, 62, 0}, // Black king
    [_]u8{57, 58, 59}, // Black queen
};

// CASTLING_CHECKS declares the indices which, if in check, can block castling.
// Same order as above.
const CASTLING_CHECKS = [4][2]u8{
    [_]u8{5, 6},
    [_]u8{2, 3},
    [_]u8{61, 62},
    [_]u8{58, 59},
};

// Given a position, the side to castle (either KING_CASTLE or QUEEN_CASTLE), and an attack map from the opponent,
// determine if the side is able to legally castle.
// TODO: this can be sped up by precomputing bitboards for the blocked and checked squares, then doing an intersection
// with the occupied and attack maps respectively
fn clearToCastle(pos: *position.Position, side: castling.CastleSide, attack_map: u64) bool {
    const castling_index: u8 = switch (side) {
            .king => @as(u8, 0),
            .queen => @as(u8, 1),
        } + if (pos.to_move == Color.black) @intCast(u8, 2) else @intCast(u8, 0);

    // For each index in the potential blockers, check that there is no piece
    // present.
    for (CASTLING_BLOCKS[castling_index]) |block_index| {
        if (block_index == 0) {
            break;
        }

        if (pos.pieceOn(block_index)) {
            return false;
        }
    }

    // For each index in the potentially-checked indices, ensure that the index
    // is not attacked.
    for (CASTLING_CHECKS[castling_index]) |check_index| {
        if (check_index == 0) {
            break;
        }

        if (attack.isSquareAttacked(attack_map, check_index)) {
            return false;
        }
    }

    return true;
}

pub fn isKingInCheck(pos: position.Position, side: Color, attack_map: u64) bool {
    const king_index = pos.king_indices[@enumToInt(side)];

    return attack.isSquareAttacked(attack_map, king_index);
}
