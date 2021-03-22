const position = @import("./position.zig");
const piece = @import("./piece.zig");
const PieceType = piece.PieceType;
const move = @import("./move.zig");
const std = @import("std");
const ArrayList = std.ArrayList;

//pub fn toAlgebraic(pos: position.Position, m: u32) void {
//    if (move.isKingCastle(m)) {
//        std.debug.print("0-0", .{});
//    }
//
//    if (move.isQueenCastle(m)) {
//        std.debug.print("0-0-0", .{});
//    }
//
//    const to = move.toIndex(m);
//    const from = move.fromIndex(m);
//    const to_rank = to / 16 + 1;
//    const to_file = (to % 16) + 'a';
//    const from_rank = from / 16 + 1;
//    const from_file = (from % 16) + 'a';
//
//    if (move.isPromotion(m) or move.isPromotionCapture(m)) {
//        const piece_moved = pos.board[move.fromIndex(m)];
//        const promotion_piece = move.getPromotedPiece(m, piece_moved);
//
//        std.debug.print(
//            "move: {c}{d}{c}{d}\n",
//            .{from_file, from_rank, to_file, to_rank},
//        );
//    }
//
//    std.debug.print(
//            "move: {c}{d}{c}{d}\n",
//            .{from_file, from_rank, to_file, to_rank},
//    );
//}

//pub fn toFEN(pos: position.Position, buf: *ArrayList(u8)) !void {
//    // Loop in reverse through the ranks, from 8 to 1.
//    var rank_i: i8 = 7;
//    while (rank_i >= 0) {
//        var rank: u8 = @intCast(u8, rank_i);
//        // We need to keep track of the number of empty squares accumulated so
//        // far in the rank.
//        var empty: u8 = 0;
//
//        // Loop forwards through the files, from a to h.
//        var i: u8 = rank * 16;
//        while (i < rank * 16 + 8) {
//            // If a piece is present, add the number of empty squares
//            // encountered so far (if non-zero) to the output string, then rest
//            // the counter and add the current piece to the string. Otherwise,
//            // increment the empty square count.
//            if (pos.pieceOn(i)) {
//                if (empty != 0) {
//                    try buf.append(empty + '0');
//                }
//
//                empty = 0;
//
//                try buf.append(pieceToChar(pos.board[i]));
//            } else {
//                empty += 1;
//            }
//
//             i += 1;
//        }
//
//        // If no pieces were encountered, add the empty squares count to the
//        // string.
//        if (empty != 0) {
//            try buf.append(empty + '0');
//        }
//
//        // At the end of the rank, add a slash.
//        if (rank != 0) {
//            try buf.append('/');
//        }
//
//        rank_i -= 1;
//    }
//
//    try buf.append(' ');
//
//    // Convert the current player to a string.
//    if (pos.to_move == piece.Color.white) {
//        try buf.append('w');
//    } else {
//        try buf.append('b');
//    }
//
//    //    castling = castleString(position)
//    //
//    //    enPassant = enPassantString(position)
//    // halfmove
//    // fullmove
//}
//
//// Converts a piece to a FEN char.
//fn pieceToChar(p: u8) u8 {
//    var code: u8 = switch (piece.pieceType(p)) {
//        PieceType.king => 'k',
//        PieceType.queen => 'q',
//        PieceType.rook => 'r',
//        PieceType.bishop => 'b',
//        PieceType.knight => 'n',
//        PieceType.pawn => 'p',
//        else => '_',
//    };
//
//    if (piece.pieceColor(p) == piece.Color.white) {
//        code -= 'a' - 'A';
//    }
//
//    return code;
//}
