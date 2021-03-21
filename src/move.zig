const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const std = @import("std");
const Color = @import("./color.zig").Color;

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

    pub fn initDoublePawnPush(from: u8, to: u8, piece_color: Color) Move {
        var move = Move.initQuiet(from, to, piece_color, PieceType.pawn);
        move.move_type = MoveType.double_pawn_push;
        return move;
    }

    pub fn initCapture(from: u8, to: u8, piece_color: Color, piece_type: PieceType, captured_piece_color: Color, captured_piece_type: PieceType) Move {
        var move = Move.initQuiet(from, to, piece_color, piece_type);
        move.move_type = MoveType.capture;
        move.captured_piece_color = captured_piece_color;
        move.captured_piece_type = captured_piece_type;
        return move;
    }

    pub fn initPromotion(from: u8, to: u8, piece_color: Color, piece_type: PieceType, promote_to: PieceType) Move {
        var move = Move.initQuiet(from, to, piece_color, piece_type);
        move.move_type = switch (promote_to) {
            PieceType.knight => knight_promo,
            PieceType.bishop => bishop_promo,
            PieceType.rook => rook_promo,
            PieceType.queen => queen_promo,
            else => 0,
        };

        return move;
    }

    pub fn initPromotionCapture(from: u8, to: u8, piece_color: Color, piece_type: PieceType, promote_to: PieceType, captured_piece_color: Color, captured_piece_type: PieceType) Move {
        var move = Move.initQuiet(from, to, piece_color, piece_type);
        move.move_type = switch (promote_to) {
            PieceType.knight => knight_promo_capture,
            PieceType.bishop => bishop_promo_capture,
            PieceType.rook => rook_promo_capture,
            PieceType.queen => queen_promo_capture,
            else => 0,
        };
        move.captured_piece_color = captured_piece_color;
        move.captured_piece_type = captured_piece_type;

        return move;
    }

    pub fn initEnPassant(from: u8, to: u8, piece_color: Color) Move {
        var move = Move.initQuiet(from, to, piece_color, PieceType.pawn);
        move.move_type = MoveType.en_passant;
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

    pub fn toLongAlgebraic(self: Move) ![]const u8 {
        var ret: [5]u8 = undefined;

        const to = self.to;
        const from = self.from;
        const to_rank = to / 16 + 1;
        const to_file = (to % 16) + 'a';
        const from_rank = from / 16 + 1;
        const from_file = (from % 16) + 'a';

        if (self.isPromotion()) {
            const promotion_piece = self.getPromotedPiece();

            return try std.fmt.bufPrint(
                ret[0..],
                "{c}{d}{c}{d}{c}",
                .{from_file, from_rank, to_file, to_rank, pieceToCharColorblind(promotion_piece)},
            );
        }

        return try std.fmt.bufPrint(
            ret[0..],
            "{c}{d}{c}{d}",
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