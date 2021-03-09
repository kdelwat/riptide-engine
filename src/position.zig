const std = @import("std");


// Position contains the complete game state after a turn.
// board is the board state as an array of pieces. The array is 128 elements long,
// rather than 64, because it is in 0x88 form. This essentially places a junk board
// to the right of the main board, like so:
//
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
// 0 0 0 0 0 0 0 0 x x x x x x x x
//
// The bottom left hand corner is index 0, while the top right hand corner is 127.
// 0x88 form has the advantage of allowing very fast checks to see if a position is
// on the board, which is used in move generation.
// castling is a byte that represents castling rights for both players. Only the
// lower 4 bits are used, with 1 indicating castling is allowed.
// x x x x _ _ _ _
//         ^ ^ ^ ^
//         | | | |
//         | | | |
//         + | | |
// White king| | |
//           + | |
// White queen | |
//             | |
// Black king+-+ |
//               |
// Black queen+--+
// toMove is the colour of the player who is next to move.
// enPassantTarget is the index of a square where there is an en passant
// opportunity. If a pawn was double pushed in the previous turn, its jumped
// position will appear as the en passant target.
// halfmove and fullmove represent the time elapsed in the game.


pub const Position = struct {
    board:           [128]u8,
    // castling:        u8,
    // toMove:          u8,
    // enPassantTarget: u8,
    // halfmove:        u8,
    // fullmove:        u32,
};

pub fn fromFEN(fen: [:0]const u8) *Position {
    // The FEN for the starting position looks like this:
    //         rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    var i: u16 = 0;

    // We need to convert the board string into a piece array. Due to the way
    // FEN is structured, the first piece is at a8, which translates to 0x88
    // index 112.
    var board_position: [128]u8 = [_]u8{0} ** 128;
    var board_index: u8 = 112;

    while (true) {
        std.debug.print("i: {}, board_index: {}, fen[i]: {}\n", .{i, board_index, fen[i]});

        // Skip the slashes which separate ranks
        if (fen[i] == '/') {
            i += 1;
            continue;
        }

        // Numbers in the board string indicate empty spaces, so we advance the
        // board index by that number of spaces since there aren't any pieces in
        // those positions.
        if (fen[i] >= '1' and fen[i] <= '8') {
            board_index += fen[i] - '0';
        } else {
            // Otherwise, look up the correct piece code and insert it.
            board_position[board_index] = fromFENCode(fen[i]);
            board_index += 1;
        }

        if (board_index == 8) {
            // Done
            i += 1;
            break;
        }

        // Skip squares that aren't on the board
        if (board_index % 16 > 7) {
            board_index = ((board_index / 16) - 1) * 16;
        }

        i += 1;
    }

    return &Position{.board = board_position};
}

// Convert a FEN piece code (e.g. p) to the 0x88 byte form
fn fromFENCode(fen: u8) u8 {
    return switch(fen) {
        'k' => 67,
        'q' => 71,
        'b' => 68,
        'n' => 66,
        'r' => 69,
        'p' => 65,
        'K' => 3,
        'Q' => 7,
        'B' => 4,
        'N' => 2,
        'R' => 5,
        'P' => 1,
        else => 0,
    };
}