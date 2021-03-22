const std = @import("std");
const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const parse_fen = @import("./parse/fen.zig").fen;
const Fen = @import("./parse/fen.zig").Fen;
const Bitboard = @import("./bitboard.zig").Bitboard;
const bitboardIndex = @import("./bitboard.zig").bitboardIndex;
const CanCastle = @import("./castling.zig").CanCastle;
const attack = @import("./attack.zig");
usingnamespace @import("./bitboard_ops.zig");

// Position contains the complete game state after a turn.
pub const Position = struct {
    board:              Bitboard,

    // To improve move generation speed, cache the positions of each king
    // Indexed by Color
    king_indices:       [2]u8,

    // to_move is the color of the player who is next to move.
    to_move:            Color,

    castling:           u4,

    // en_passant_target is the index of a square where there is an en passant
    // opportunity. If a pawn was double pushed in the previous turn, its jumped
    // position will appear as the en passant target.
    en_passant_target: u8,

    // halfmove and fullmove represent the time elapsed in the game.
    halfmove:        u64,
    fullmove:        u64,

    // Equality with another position
    pub fn eq(self: Position, other: Position) bool {
        if (!self.board.eq(other.board)) return false;
        if (!std.mem.eql(u8, self.king_indices[0..], other.king_indices[0..])) return false;
        if (self.to_move != other.to_move) return false;
        if (self.castling != other.castling) return false;
        if (self.en_passant_target != other.en_passant_target) return false;
        if (self.halfmove != other.halfmove) return false;
        if (self.fullmove != other.fullmove) return false;

        return true;
    }

    pub fn cmpDebug(self: Position, other: Position) void {
        std.debug.print("=== FINDING MISMATCHES BETWEEN SELF AND OTHER ===\n", .{});
        if (self.board.boards[0] != other.board.boards[0]) std.debug.print("\t[white] want: {b}, got: {b}\n", .{self.board.boards[0], other.board.boards[0]});
        if (self.board.boards[1] != other.board.boards[1]) std.debug.print("\t[black] want: {b}, got: {b}\n", .{self.board.boards[1], other.board.boards[1]});
        if (self.board.boards[2] != other.board.boards[2]) std.debug.print("\t[pawn] want: {b}, got: {b}\n", .{self.board.boards[2], other.board.boards[2]});
        if (self.board.boards[3] != other.board.boards[3]) std.debug.print("\t[knight] want: {b}, got: {b}\n", .{self.board.boards[3], other.board.boards[3]});
        if (self.board.boards[4] != other.board.boards[4]) std.debug.print("\t[bishop] want: {b}, got: {b}\n", .{self.board.boards[4], other.board.boards[4]});
        if (self.board.boards[5] != other.board.boards[5]) std.debug.print("\t[rook] want: {b}, got: {b}\n", .{self.board.boards[5], other.board.boards[5]});
        if (self.board.boards[6] != other.board.boards[6]) std.debug.print("\t[queen] want: {b}, got: {b}\n", .{self.board.boards[6], other.board.boards[6]});
        if (self.board.boards[7] != other.board.boards[7]) std.debug.print("\t[king] want: {b}, got: {b}\n", .{self.board.boards[7], other.board.boards[7]});
        if (self.king_indices[0] != other.king_indices[0]) std.debug.print("\t[white king] want: {}, got: {}\n", .{self.king_indices[0], other.king_indices[0]});
        if (self.king_indices[1] != other.king_indices[1]) std.debug.print("\t[black king] want: {}, got: {}\n", .{self.king_indices[1], other.king_indices[1]});
        if (self.to_move != other.to_move) std.debug.print("\t[to_move] want: {}, got: {}\n", .{self.to_move, other.to_move});
        if (self.castling != other.castling) std.debug.print("\t[castling] want: {b}, got: {b}\n", .{self.castling, other.castling});
        if (self.en_passant_target != other.en_passant_target) std.debug.print("\t[en passant] want: {}, got: {}\n", .{self.en_passant_target, other.en_passant_target});
        if (self.halfmove != other.halfmove) std.debug.print("\t[halfmove] want: {}, got: {}\n", .{self.halfmove, other.halfmove});
        if (self.fullmove != other.fullmove) std.debug.print("\t[fullmove] want: {}, got: {}\n", .{self.fullmove, other.fullmove});

        std.debug.print("=== COMPARISON COMPLETE ===\n", .{});
    }

    pub fn getIndexOfKing(self: Position, side: Color) u8 {
        return self.king_indices[@enumToInt(side)];
    }

    pub fn generateKingAttackMap(self: *Position, attacker: Color) u64 {
        // Remove the attacked king before generating an attack bitboard
        // This will prevent moves where the king tries to run from sliding pieces
        // but would still be attacked
        self.board.unset(PieceType.king, color.invert(attacker), self.king_indices[color.invert(attacker)]);
        const attack_map = self.generateAttackMap(attacker);
        self.board.set(PieceType.king, color.invert(attacker), self.king_indices[color.invert(attacker)]);
        return attack_map;
    }

    pub fn generateAttackMap(self: *Position, attacker: Color) u64 {
        // TODO: cache repeated calls to this function for a position
        return attack.generateAttackMap(self, attacker);
    }
    // Checks if there is a piece at the given index
    pub fn pieceOn(self: Position, i: u8) bool {
        return self.board.occupied() & bitboardFromIndex(i) != 0;
    }
};

pub fn fromFEN(fen: []const u8) !Position {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer { _ = gpa.deinit(); }
    const f: Fen = (try parse_fen(&gpa.allocator, fen)).value;
    return fromFENStruct(f);
}

pub fn fromFENStruct(fen: Fen) Position {
    // First, set up the board position.
    var board = Bitboard.init();
    var rank_index: u8 = 7;
    var file_index: u8 = 0;
    var king_indices = [2]u8{0,0};
    for (fen.board) |c| {
        // Skip the slashes which separate ranks
        if (c == '/') {
            rank_index -= 1;
            file_index = 0;
            continue;
        }

        // Numbers in the board string indicate empty spaces, so we advance the
        // file index by that number of spaces since there aren't any pieces in
        // those positions.
        if (c >= '1' and c <= '8') {
            file_index += c - '0';
        } else {
            // Otherwise, set the piece in the board representation
            const piece_color = pieceColorFromFenCode(c);
            const piece_type = pieceTypeFromFenCode(c);

            if (piece_type == PieceType.king) {
                king_indices[@enumToInt(piece_color)] = bitboardIndex(file_index, rank_index);
            }

            board.setFR(piece_type, piece_color, file_index, rank_index);
            file_index += 1;
        }
    }

    // Find the next player to move
    const to_move = if (fen.to_move[0] == 'w') Color.white else Color.black;

    // Castling
    var castling: u4 = 0;
    for (fen.castling) |c| {
        castling |= @enumToInt(switch (c) {
            'K' => CanCastle.white_king,
            'Q' => CanCastle.white_queen,
            'k' => CanCastle.black_king,
            'q' => CanCastle.black_queen,
            else => CanCastle.invalid,
        });
    }

    // En passant
    var en_passant_target: u8 = 0;
    if (fen.en_passant[0] != '-') {
        const file = fen.en_passant[0] - 'a';
        const rank = fen.en_passant[1] - '1';

        en_passant_target = bitboardIndex(file, rank);
    }

    return Position{
        .board = board,
        .to_move = to_move,
        .castling = castling,
        .en_passant_target = en_passant_target,
        .halfmove = fen.halfmove,
        .fullmove = fen.fullmove,
        .king_indices = king_indices,
    };
}

// Convert a FEN piece code (e.g. p) to the piece type
fn pieceTypeFromFenCode(fen: u8) PieceType {
    return switch(toLower(fen)) {
        'k' => PieceType.king,
        'q' => PieceType.queen,
        'b' => PieceType.bishop,
        'n' => PieceType.knight,
        'r' => PieceType.rook,
        'p' => PieceType.pawn,
        else => PieceType.empty,
    };
}

fn pieceColorFromFenCode(fen: u8) Color {
    return if (isUpper(fen)) Color.white else Color.black;
}

fn toLower(c: u8) u8 {
    if (isUpper(c)) {
        return c + ('a' - 'A');
    }

    return c;
}

fn isUpper(c: u8) bool {
    return c >= 'A' and c <= 'Z';
}