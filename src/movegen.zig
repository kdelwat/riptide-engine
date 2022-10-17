const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const position = @import("./position.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const Bitboard = @import("./bitboard.zig").Bitboard;
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const Move = @import("./move.zig").Move;
const make_move = @import("./make_move.zig");
const attack = @import("./attack.zig");
const debug = @import("./debug.zig");
const castling = @import("./castling.zig");
const b = @import("./bitboard_ops.zig");
const moveorder = @import("./moveorder.zig");

const AVERAGE_BRANCHING_FACTOR = 38;
pub const MAX_DEPTH = 40;
const MOVE_ARRAY_SIZE = AVERAGE_BRANCHING_FACTOR * MAX_DEPTH;

// The move generator is responsible for legal move generation at each ply of a search
// Based on the design at https://www.chessprogramming.org/Move_List, the generator allocates a single
// array once that will be reused through the entire search tree - this dramatically speeds up generation
// as no allocation occurs after the initial setup.
pub const MoveGenerator = struct {
    moves: [MOVE_ARRAY_SIZE]Move,

    // next_to_play is the index of the next move to search for the given ply
    next_to_play: [MAX_DEPTH]usize,
    // next_to_generate is the index of the next empty slot for the given ply (where a generated move
    // will be inserted)
    next_to_generate: [MAX_DEPTH]usize,

    // the current ply of the search
    ply: usize,

    orderer: moveorder.MoveOrderer,

    pub fn init() MoveGenerator {
        return MoveGenerator{
            .moves = undefined, // This can be junk, we'll take care of filling it gradually
            .next_to_play = [_]usize{0} ** MAX_DEPTH,
            .next_to_generate = [_]usize{0} ** MAX_DEPTH,
            .ply = 0,
            .orderer = moveorder.MoveOrderer.init(),
        };
    }

    // After generation at a certain ply, the search routine should call next() until it returns
    // null
    pub fn next(self: *MoveGenerator) ?Move {
        // If we reach the end of the generated moves for this ply, search is complete
        // Drop down one ply and signal the end of generation
        if (self.next_to_play[self.ply] == self.next_to_generate[self.ply]) {
            self.ply -= 1;
            return null;
        }

        // Otherwise, return the next generated move
        self.next_to_play[self.ply] += 1;

        return self.moves[self.next_to_play[self.ply] - 1];
    }

    // When a beta cutoff occurs, the usual logic for decrementing the ply is never reached (in next())
    // The search routine must manually call this function.
    pub fn cutoff(self: *MoveGenerator) void {
        self.ply -= 1;
    }

    // Called with a position, generate a list of legal moves
    pub fn generate(self: *MoveGenerator, pos: *position.Position) void {
        // Calling generate will increase the ply by 1, since it's called for each level of the alpha-beta search
        self.ply += 1;

        // Set move pointers to the last value before generation
        self.next_to_generate[self.ply] = self.next_to_generate[self.ply - 1];
        self.next_to_play[self.ply] = self.next_to_generate[self.ply - 1];

        generateMoves(self, pos);
        self.orderMoves(pos);
    }

    // Return the remaining moves to be evaluated
    pub fn count(self: *MoveGenerator) u64 {
        return self.next_to_generate[self.ply] - self.next_to_play[self.ply];
    }

    // Add a pseudo-legal move to the move list for the current ply, which is filtered for legality
    fn addPseudoLegal(self: *MoveGenerator, move: Move, pos: *position.Position) void {
        const artifacts = make_move.makeMove(pos, move);

        if (!isKingInCheck(pos)) {
            // Filter out this move, king is in check
            self.add(move);
        }

        make_move.unmakeMove(pos, move, artifacts);
    }

    // Add a known-legal move to the move list for the current ply
    fn addLegal(self: *MoveGenerator, move: Move, _: *position.Position) void {
        self.add(move);
    }

    fn add(self: *MoveGenerator, move: Move) void {
        self.moves[self.next_to_generate[self.ply]] = move;
        self.next_to_generate[self.ply] += 1;
    }

    // Order moves based on fitness heuristics. The quicker we see a good move,
    // the better alpha-beta search works.
    fn orderMoves(self: *MoveGenerator, pos: *position.Position) void {
        self.orderer.preprocess(pos, self.moves[self.next_to_play[self.ply]..self.next_to_generate[self.ply]]);
        const context = moveorder.buildContext(pos, &self.orderer);
        std.sort.sort(Move, self.moves[self.next_to_play[self.ply]..self.next_to_generate[self.ply]], &context, moveorder.cmp);
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

    var single_push = switch (pos.to_move) {
        Color.white => b.northOne(pawns) & pos.board.empty(),
        Color.black => b.southOne(pawns) & pos.board.empty(),
    };

    var double_push = switch (pos.to_move) {
        Color.white => b.northOne(single_push) & empty & RANK_4,
        Color.black => b.southOne(single_push) & empty & RANK_5,
    };

    const promotion_rank = switch (pos.to_move) {
        Color.white => @as(u8, 7),
        Color.black => @as(u8, 0),
    };

    // If the single push results in a pawn ending up on the final rank, generate
    // promotion moves. Otherwise generate a quiet push.
    while (single_push != 0) {
        const to = b.bitscanForwardAndReset(&single_push);
        const from = switch (pos.to_move) {
            Color.white => to - 8,
            Color.black => to + 8,
        };

        if (b.isOnRank(to, promotion_rank)) {
            moves.addPseudoLegal(Move.initPromotion(from, to, pos.to_move, PieceType.queen), pos);
            moves.addPseudoLegal(Move.initPromotion(from, to, pos.to_move, PieceType.knight), pos);
            moves.addPseudoLegal(Move.initPromotion(from, to, pos.to_move, PieceType.rook), pos);
            moves.addPseudoLegal(Move.initPromotion(from, to, pos.to_move, PieceType.bishop), pos);
        } else {
            moves.addPseudoLegal(Move.initQuiet(from, to, pos.to_move, PieceType.pawn), pos);
        }
    }

    // Generate double push moves.
    while (double_push != 0) {
        const to = b.bitscanForwardAndReset(&double_push);
        const from = switch (pos.to_move) {
            Color.white => to - 16,
            Color.black => to + 16,
        };
        moves.addPseudoLegal(Move.initDoublePawnPush(from, to, pos.to_move), pos);
    }
}

fn generatePawnCaptures(moves: *MoveGenerator, pos: *position.Position) !void {
    var opponent_pieces = pos.board.getColor(color.invert(pos.to_move));

    if (pos.en_passant_target != 0) {
        opponent_pieces |= b.bitboardFromIndex(pos.en_passant_target);
    }

    const pawns = pos.board.get(PieceType.pawn, pos.to_move);

    var east_captures = switch (pos.to_move) {
        Color.white => b.northEastOne(pawns) & opponent_pieces,
        Color.black => b.southEastOne(pawns) & opponent_pieces,
    };

    var west_captures = switch (pos.to_move) {
        Color.white => b.northWestOne(pawns) & opponent_pieces,
        Color.black => b.southWestOne(pawns) & opponent_pieces,
    };

    const promotion_rank = switch (pos.to_move) {
        Color.white => @as(u8, 7),
        Color.black => @as(u8, 0),
    };

    // If the capture results in a pawn ending up on the final rank, generate
    // promotion capture moves. Otherwise generate a capture move.
    while (east_captures != 0) {
        const to = b.bitscanForwardAndReset(&east_captures);
        const from = switch (pos.to_move) {
            Color.white => to - 9,
            Color.black => to + 7,
        };

        const captured_piece_type = pos.board.getPieceTypeAt(to);

        if (b.isOnRank(to, promotion_rank)) {
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type), pos);
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type), pos);
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type), pos);
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type), pos);
        } else if (to == pos.en_passant_target) {
            moves.addPseudoLegal(Move.initEnPassant(from, to, pos.to_move), pos);
        } else {
            moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.pawn, captured_piece_type), pos);
        }
    }

    while (west_captures != 0) {
        const to = b.bitscanForwardAndReset(&west_captures);
        const from = switch (pos.to_move) {
            Color.white => to - 7,
            Color.black => to + 9,
        };

        const captured_piece_type = pos.board.getPieceTypeAt(to);

        if (b.isOnRank(to, promotion_rank)) {
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type), pos);
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type), pos);
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type), pos);
            moves.addPseudoLegal(Move.initPromotionCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type), pos);
        } else if (to == pos.en_passant_target) {
            moves.addPseudoLegal(Move.initEnPassant(from, to, pos.to_move), pos);
        } else {
            moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.pawn, captured_piece_type), pos);
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
        const from = b.bitscanForwardAndReset(&knights);
        const targets = attack.KNIGHT_ATTACKS[from];

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = b.bitscanForwardAndReset(&quiet);
            moves.addPseudoLegal(Move.initQuiet(from, to, pos.to_move, PieceType.knight), pos);
        }

        while (captures != 0) {
            const to = b.bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.knight, captured_piece_type), pos);
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
        const to = b.bitscanForwardAndReset(&quiet);
        moves.addPseudoLegal(Move.initQuiet(from, to, pos.to_move, PieceType.king), pos);
    }

    while (captures != 0) {
        const to = b.bitscanForwardAndReset(&captures);
        const captured_piece_type = pos.board.getPieceTypeAt(to);
        moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.king, captured_piece_type), pos);
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
        const from = b.bitscanForwardAndReset(&queens);
        var targets: u64 = 0;
        const bitboard = b.bitboardFromIndex(from);

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
            const to = b.bitscanForwardAndReset(&quiet);
            moves.addPseudoLegal(Move.initQuiet(from, to, pos.to_move, PieceType.queen), pos);
        }

        while (captures != 0) {
            const to = b.bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.queen, captured_piece_type), pos);
        }
    }

    while (rooks != 0) {
        const from = b.bitscanForwardAndReset(&rooks);
        var targets: u64 = 0;
        const bitboard = b.bitboardFromIndex(from);
        targets |= attack.southAttacks(bitboard, empty);
        targets |= attack.northAttacks(bitboard, empty);
        targets |= attack.eastAttacks(bitboard, empty);
        targets |= attack.westAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = b.bitscanForwardAndReset(&quiet);
            moves.addPseudoLegal(Move.initQuiet(from, to, pos.to_move, PieceType.rook), pos);
        }

        while (captures != 0) {
            const to = b.bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.rook, captured_piece_type), pos);
        }
    }

    while (bishops != 0) {
        const from = b.bitscanForwardAndReset(&bishops);
        var targets: u64 = 0;
        const bitboard = b.bitboardFromIndex(from);

        targets |= attack.northEastAttacks(bitboard, empty);
        targets |= attack.northWestAttacks(bitboard, empty);
        targets |= attack.southEastAttacks(bitboard, empty);
        targets |= attack.southWestAttacks(bitboard, empty);

        var quiet = targets & empty;
        var captures = targets & opponent_pieces;

        while (quiet != 0) {
            const to = b.bitscanForwardAndReset(&quiet);
            moves.addPseudoLegal(Move.initQuiet(from, to, pos.to_move, PieceType.bishop), pos);
        }

        while (captures != 0) {
            const to = b.bitscanForwardAndReset(&captures);
            const captured_piece_type = pos.board.getPieceTypeAt(to);
            moves.addPseudoLegal(Move.initCapture(from, to, pos.to_move, PieceType.bishop, captured_piece_type), pos);
        }
    }
}

fn generateCastlingMoves(moves: *MoveGenerator, pos: *position.Position) !void {
    // Return early if no castling is possible; this saves the attack generation cost
    if (!castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.king) and !castling.hasCastlingRight(pos.castling, pos.to_move, castling.CastleSide.queen)) {
        return;
    }

    // Generate an attack map for the opponent, to test for check and castling through
    // check
    const attack_map = pos.generateAttackMap(color.invert(pos.to_move));

    const king_index = pos.king_indices[@enumToInt(pos.to_move)];

    if (attack.isSquareAttacked(attack_map, king_index)) {
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
    [_]u8{ 5, 6, 0 }, // White king
    [_]u8{ 1, 2, 3 }, // White queen
    [_]u8{ 61, 62, 0 }, // Black king
    [_]u8{ 57, 58, 59 }, // Black queen
};

// CASTLING_CHECKS declares the indices which, if in check, can block castling.
// Same order as above.
const CASTLING_CHECKS = [4][2]u8{
    [_]u8{ 5, 6 },
    [_]u8{ 2, 3 },
    [_]u8{ 61, 62 },
    [_]u8{ 58, 59 },
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

// Check if a king is in check, from the perspective of the attacking side
pub fn isKingInCheck(pos: *position.Position) bool {
    const king_index = pos.king_indices[@enumToInt(color.invert(pos.to_move))];

    return attack.isSquareAttackedOnTheFly(pos, king_index, pos.to_move);
}

// This is useful for Static Exchange Evaluation. We want to find the lowest-valued
// attacker who can target a particular square.
//
// Helpfully, attacks are symmetrical, so the key insight here is to swap the
// attacking and defending sides, then generating attacks.
pub fn findSmallestAttackerMove(pos: *position.Position, to: u8, side: Color) ?Move {
    const captured_piece_type = pos.board.getPieceTypeAt(to);

    // Is it a pawn? Is it a knight? Is it a slider? No, it's all of the above!
    var super_pseudo_piece = b.bitboardFromIndex(to);

    // Pawn attacks
    var pawn_attack_map = switch (color.invert(side)) {
        Color.white => attack.generateWhitePawnAttackBitboard(super_pseudo_piece),
        Color.black => attack.generateBlackPawnAttackBitboard(super_pseudo_piece),
    };

    var attacking_pawns = pawn_attack_map & pos.board.get(PieceType.pawn, side);

    if (attacking_pawns > 0) {
        const attack_from = b.bitscanForwardAndReset(&attacking_pawns);
        return Move.initCapture(attack_from, to, side, PieceType.pawn, captured_piece_type);
    }

    // Knight attacks
    var knight_attack_map = attack.generateKnightAttackBitboard(super_pseudo_piece);
    var attacking_knights = knight_attack_map & pos.board.get(PieceType.knight, side);

    if (attacking_knights > 0) {
        const attack_from = b.bitscanForwardAndReset(&attacking_knights);
        return Move.initCapture(attack_from, to, side, PieceType.knight, captured_piece_type);
    }

    // Empty positions on the board, which sliders can move through
    const empty: u64 = pos.board.empty();

    // Bishop attacks
    var bishop_attack_map = attack.generateBishopAttackBitboard(super_pseudo_piece, empty);
    var attacking_bishops = bishop_attack_map & pos.board.get(PieceType.bishop, side);

    if (attacking_bishops > 0) {
        const attack_from = b.bitscanForwardAndReset(&attacking_bishops);
        return Move.initCapture(attack_from, to, side, PieceType.bishop, captured_piece_type);
    }

    // Rook attacks
    var rook_attack_map = attack.generateRookAttackBitboard(super_pseudo_piece, empty);
    var attacking_rooks = rook_attack_map & pos.board.get(PieceType.rook, side);

    if (attacking_rooks > 0) {
        const attack_from = b.bitscanForwardAndReset(&attacking_rooks);
        return Move.initCapture(attack_from, to, side, PieceType.rook, captured_piece_type);
    }

    // Queen attacks
    var queen_attack_map = attack.generateQueenAttackBitboard(super_pseudo_piece, empty);
    var attacking_queens = queen_attack_map & pos.board.get(PieceType.queen, side);

    if (attacking_queens > 0) {
        const attack_from = b.bitscanForwardAndReset(&attacking_queens);
        return Move.initCapture(attack_from, to, side, PieceType.queen, captured_piece_type);
    }

    // King attacks
    var king_attack_map = attack.generateKingAttackBitboard(super_pseudo_piece);
    var attacking_kings = king_attack_map & pos.board.get(PieceType.king, side);

    if (attacking_kings > 0) {
        const attack_from = b.bitscanForwardAndReset(&attacking_kings);
        return Move.initCapture(attack_from, to, side, PieceType.king, captured_piece_type);
    }

    return null;
}
