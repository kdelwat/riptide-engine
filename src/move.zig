const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const std = @import("std");
const Color = @import("./color.zig").Color;
const color = @import("./color.zig");
const bitboard = @import("./bitboard.zig");

pub const MoveType = enum(u4) {
    quiet                = 0b0000,
    double_pawn_push     = 0b0001,
    kingside_castle      = 0b0010,
    queenside_castle     = 0b0011,
    capture              = 0b0100,
    en_passant           = 0b0101,
    knight_promo         = 0b1000,
    bishop_promo         = 0b1001,
    rook_promo           = 0b1010,
    queen_promo          = 0b1011,
    knight_promo_capture = 0b1100,
    bishop_promo_capture = 0b1101,
    rook_promo_capture   = 0b1110,
    queen_promo_capture  = 0b1111,
};

pub const Move = struct {
    piece_color: Color,
    piece_type: PieceType,

    captured_piece_type: ?PieceType = null,
    captured_piece_color: ?Color = null,

    move_type: MoveType = MoveType.quiet,

    from: u8,
    to: u8,

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
            .rook_promo   => PieceType.rook,
            .queen_promo  => PieceType.queen,

            .knight_promo_capture => PieceType.knight,
            .bishop_promo_capture => PieceType.bishop,
            .rook_promo_capture   => PieceType.rook,
            .queen_promo_capture  => PieceType.queen,

            else => PieceType.empty,
        };
    }

    pub fn toLongAlgebraic(self: Move, buf: []u8) !void {
        const to = self.to;
        const from = self.from;
        const to_rank = bitboard.rankIndex(to) + '1';
        const to_file = bitboard.fileIndex(to) + 'a';
        const from_rank = bitboard.rankIndex(from) + '1';
        const from_file = bitboard.fileIndex(from) + 'a';

        if (self.isPromotion()) {
            const promotion_piece = self.getPromotedPiece();
            _ = try std.fmt.bufPrint(
                buf,
                "{c}{c}{c}{c}{c}",
                .{from_file, from_rank, to_file, to_rank, pieceToCharColorblind(promotion_piece)},
            );
        }

        _ = try std.fmt.bufPrint(
            buf,
            "{c}{c}{c}{c}",
            .{from_file, from_rank, to_file, to_rank},
        );
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