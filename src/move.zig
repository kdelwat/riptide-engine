const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const std = @import("std");
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const bitboard = @import("./bitboard.zig");
const position = @import("position.zig");
const b = @import("./bitboard_ops.zig");
const LongAlgebraicMove = @import("./parse/algebraic.zig").LongAlgebraicMove;

pub const MoveType = enum(u4) {
    quiet = 0b0000,
    double_pawn_push = 0b0001,
    kingside_castle = 0b0010,
    queenside_castle = 0b0011,
    capture = 0b0100,
    en_passant = 0b0101,
    knight_promo = 0b1000,
    bishop_promo = 0b1001,
    rook_promo = 0b1010,
    queen_promo = 0b1011,
    knight_promo_capture = 0b1100,
    bishop_promo_capture = 0b1101,
    rook_promo_capture = 0b1110,
    queen_promo_capture = 0b1111,
};

pub const Move = packed struct {
    piece_color: Color, // 1
    piece_type: PieceType, // 4

    // Ideally, these would be optionals, as they're only filled in when the
    // move is a capture. But we want to be able to store a Move in the
    // transposition tables, so we need a fixed size, and optionals aren't fixed.
    captured_piece_type: PieceType = PieceType.empty, // 4
    captured_piece_color: Color = Color.white, // 1

    move_type: MoveType = MoveType.quiet, // 4

    from: u8, // 8
    to: u8, // 8

    pub fn eq(self: Move, other: Move) bool {
        return self.piece_color == other.piece_color and self.move_type == other.move_type and self.from == other.from and self.to == other.to;
    }

    pub fn initQuiet(from: u8, to: u8, piece_color: Color, piece_type: PieceType) Move {
        return Move{
            .from = from,
            .to = to,
            .piece_color = piece_color,
            .piece_type = piece_type,
        };
    }

    pub fn initQueensideCastle(piece_color: Color) Move {
        return Move{
            .from = 0,
            .to = 0,
            .piece_color = piece_color,
            .piece_type = PieceType.empty,
            .move_type = MoveType.queenside_castle,
        };
    }

    pub fn initKingsideCastle(piece_color: Color) Move {
        return Move{
            .from = 0,
            .to = 0,
            .piece_color = piece_color,
            .piece_type = PieceType.empty,
            .move_type = MoveType.kingside_castle,
        };
    }

    pub fn initDoublePawnPush(from: u8, to: u8, piece_color: Color) Move {
        var move = Move.initQuiet(from, to, piece_color, PieceType.pawn);
        move.move_type = MoveType.double_pawn_push;
        return move;
    }

    pub fn initCapture(from: u8, to: u8, piece_color: Color, piece_type: PieceType, captured_piece_type: PieceType) Move {
        var move = Move.initQuiet(from, to, piece_color, piece_type);
        move.move_type = MoveType.capture;
        move.captured_piece_color = color.invert(piece_color);
        move.captured_piece_type = captured_piece_type;
        return move;
    }

    pub fn initPromotion(from: u8, to: u8, piece_color: Color, promote_to: PieceType) Move {
        var move = Move.initQuiet(from, to, piece_color, PieceType.pawn);
        move.move_type = switch (promote_to) {
            .knight => .knight_promo,
            .bishop => .bishop_promo,
            .rook => .rook_promo,
            .queen => .queen_promo,
            else => unreachable,
        };

        return move;
    }

    pub fn initPromotionCapture(from: u8, to: u8, piece_color: Color, promote_to: PieceType, captured_piece_type: PieceType) Move {
        var move = Move.initQuiet(from, to, piece_color, PieceType.pawn);
        move.move_type = switch (promote_to) {
            .knight => .knight_promo_capture,
            .bishop => .bishop_promo_capture,
            .rook => .rook_promo_capture,
            .queen => .queen_promo_capture,
            else => unreachable,
        };
        move.captured_piece_color = color.invert(piece_color);
        move.captured_piece_type = captured_piece_type;

        return move;
    }

    pub fn initEnPassant(from: u8, to: u8, piece_color: Color) Move {
        var move = Move.initQuiet(from, to, piece_color, PieceType.pawn);
        move.move_type = MoveType.en_passant;
        move.captured_piece_color = color.invert(piece_color);
        move.captured_piece_type = PieceType.pawn;

        return move;
    }

    pub fn is(self: Move, move_type: MoveType) bool {
        return self.move_type == move_type;
    }

    pub fn isCastle(self: Move) bool {
        return self.move_type == MoveType.queenside_castle or self.move_type == MoveType.kingside_castle;
    }

    pub fn isPromotion(self: Move) bool {
        return @enumToInt(self.move_type) & 0b1000 == 0b1000;
    }

    pub fn isPromotionCapture(self: Move) bool {
        return @enumToInt(self.move_type) & 0b1100 == 0b1100;
    }

    pub fn isCapture(self: Move) bool {
        return @enumToInt(self.move_type) & 0b0100 == 0b0100;
    }

    pub fn getPromotedPiece(self: Move) PieceType {
        return switch (self.move_type) {
            .knight_promo => PieceType.knight,
            .bishop_promo => PieceType.bishop,
            .rook_promo => PieceType.rook,
            .queen_promo => PieceType.queen,

            .knight_promo_capture => PieceType.knight,
            .bishop_promo_capture => PieceType.bishop,
            .rook_promo_capture => PieceType.rook,
            .queen_promo_capture => PieceType.queen,

            else => PieceType.empty,
        };
    }

    pub fn toLongAlgebraic(self: Move, buf: []u8) !void {
        var to = self.to;
        var from = self.from;

        if (self.move_type == .kingside_castle and self.piece_color == .white) {
            from = 4;
            to = 6;
        } else if (self.move_type == .queenside_castle and self.piece_color == .white) {
            from = 4;
            to = 2;
        } else if (self.move_type == .kingside_castle and self.piece_color == .black) {
            from = 60;
            to = 62;
        } else if (self.move_type == .queenside_castle and self.piece_color == .black) {
            from = 60;
            to = 58;
        }

        const to_rank = bitboard.rankIndex(to) + '1';
        const to_file = bitboard.fileIndex(to) + 'a';
        const from_rank = bitboard.rankIndex(from) + '1';
        const from_file = bitboard.fileIndex(from) + 'a';

        if (bitboard.rankIndex(to) > 7 or bitboard.fileIndex(to) > 7 or bitboard.rankIndex(from) > 7 or bitboard.fileIndex(from) > 7) {
            std.debug.print("WARNING Invalid entry: from = {}, to = {}\n", .{ from, to });
            std.debug.print("-> piece = {}\n", .{self.piece_type});
            std.debug.print("-> color = {}\n", .{self.piece_color});
        }

        if (self.isPromotion()) {
            const promotion_piece = self.getPromotedPiece();
            _ = try std.fmt.bufPrint(
                buf,
                "{c}{c}{c}{c}{c}",
                .{ from_file, from_rank, to_file, to_rank, pieceToCharColorblind(promotion_piece) },
            );
        }

        _ = try std.fmt.bufPrint(
            buf,
            "{c}{c}{c}{c}",
            .{ from_file, from_rank, to_file, to_rank },
        );

        if (bitboard.rankIndex(to) > 7 or bitboard.fileIndex(to) > 7 or bitboard.rankIndex(from) > 7 or bitboard.fileIndex(from) > 7 or buf[1] == 'I') {
            std.debug.print("WARNING Invalid entry: from = {}, to = {}\n", .{ from, to });
            std.debug.print("-> piece = {}\n", .{self.piece_type});
            std.debug.print("-> color = {}\n", .{self.piece_color});
        }
    }

    pub fn fromLongAlgebraic(pos: *position.Position, m: LongAlgebraicMove) Move {
        const to_file = m.to[0] - 'a';
        const to_rank = m.to[1] - '1';
        const to = bitboard.bitboardIndex(to_file, to_rank);

        const from_file = m.from[0] - 'a';
        const from_rank = m.from[1] - '1';
        const from = bitboard.bitboardIndex(from_file, from_rank);

        var mt: MoveType = .quiet;
        var captured_piece_type: PieceType = PieceType.empty;
        var captured_piece_color: Color = Color.white;

        if (m.promotion) |promo| {
            if (pos.pieceOn(to)) {
                // Promo capture
                mt = switch (promo[0]) {
                    'n' => .knight_promo_capture,
                    'b' => .bishop_promo_capture,
                    'r' => .rook_promo_capture,
                    'q' => .queen_promo_capture,
                    else => unreachable,
                };

                captured_piece_color = color.invert(pos.to_move);
                captured_piece_type = pos.board.getPieceTypeAt(to);
            } else {
                // Promo
                mt = switch (promo[0]) {
                    'n' => .knight_promo,
                    'b' => .bishop_promo,
                    'r' => .rook_promo,
                    'q' => .queen_promo,
                    else => unreachable,
                };
            }
        } else if (pos.board.getPieceTypeAt(from) == .king) {
            // Might be a castle
            if (from == 4 and to == 6) {
                mt = .kingside_castle;
            } else if (from == 4 and to == 2) {
                mt = .queenside_castle;
            } else if (from == 60 and to == 62) {
                mt = .kingside_castle;
            } else if (from == 60 and to == 58) {
                mt = .queenside_castle;
            }
        } else if (pos.pieceOn(to)) {
            // Capture
            mt = .capture;
            captured_piece_color = color.invert(pos.to_move);
            captured_piece_type = pos.board.getPieceTypeAt(to);
        } else if (mt != .kingside_castle and mt != .queenside_castle) {
            if (pos.board.getPieceTypeAt(from) == .pawn) {
                var rankDiff: u8 = undefined;
                if (bitboard.rankIndex(from) > bitboard.rankIndex(to)) {
                    rankDiff = bitboard.rankIndex(from) - bitboard.rankIndex(to);
                } else {
                    rankDiff = bitboard.rankIndex(to) - bitboard.rankIndex(from);
                }

                if (bitboard.fileIndex(from) != bitboard.fileIndex(to)) {
                    // En passant, pawn has changed files but no capture piece
                    mt = .en_passant;
                    captured_piece_color = color.invert(pos.to_move);
                    captured_piece_type = .pawn;
                } else if (rankDiff == 2) {
                    mt = .double_pawn_push;
                } else {
                    mt = .quiet;
                }
            } else {
                mt = .quiet;
            }
        }

        return Move{ .move_type = mt, .piece_type = pos.board.getPieceTypeAt(from), .piece_color = pos.to_move, .captured_piece_type = captured_piece_type, .captured_piece_color = captured_piece_color, .from = from, .to = to };
    }
};

// Converts a piece to a FEN char, without capitalisation for white.
fn pieceToCharColorblind(p: PieceType) u8 {
    return switch (p) {
        PieceType.king => 'k',
        PieceType.queen => 'q',
        PieceType.rook => 'r',
        PieceType.bishop => 'b',
        PieceType.knight => 'n',
        PieceType.pawn => 'p',
        else => '_',
    };
}
