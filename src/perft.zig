const position = @import("./position.zig");
const Move = @import("./move.zig").Move;
const MoveType = @import("./move.zig").MoveType;
const make_move = @import("./make_move.zig");
const MoveGenerator = @import("./movegen.zig").MoveGenerator;
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const color = @import("./color.zig");
const attack = @import("./attack.zig");

// perft is a performance test for the move generation function. It generates a
// move tree to a given depth, recording various information. This information can
// be compared to known results to determine if the move generation is behaving
// correctly.

pub const PerftResults = struct {
    nodes: u64,
    quiet: u64,
    captures: u64,
    enpassant: u64,
    promotion: u64,
    promo_capture: u64,
    castle_king_side: u64,
    castle_queen_side: u64,
    pawn_jump: u64,
    checks: u64,
};

// Run a perft analysis of the position to the given depth. This function is
// based on the C code at https://chessprogramming.wikispaces.com/Perft
pub fn perft(pos: *position.Position, depth: u64) u64 {
    // Generate all moves for the position.
    var gen = MoveGenerator.init();

    return perftRec(pos, &gen, depth);
}

pub fn perftRec(pos: *position.Position, gen: *MoveGenerator, depth: u64) u64 {
    var nodes: u64 = 0;

    // If the end of the tree is reached, increment the number of nodes found.
    if (depth == 0) {
        return 1;
    }

    // Generate all moves for the position.
    gen.generate(pos);

    // Make each move and recurse
    while (gen.next()) |move| {
        const artifacts = make_move.makeMove(pos, move);
        nodes += perftRec(pos, gen, depth - 1);
        make_move.unmakeMove(pos, move, artifacts);
    }

    return nodes;
}

// Run a perft analysis, but divide the initial level of the move tree. This
// allows for debugging the problematic paths of move generation.
//pub fn dividePerft(pos: *position.Position, depth: u64, a: *Allocator) void {
//    // Generate all legal moves for the position.
//    var moves = ArrayList(?Move).init(a);
//    defer moves.deinit();
//    movegen.generateLegalMoves(&moves, pos);
//
//    var total: u64 = 0;
//    for (moves.items) |opt_m| {
//        if (opt_m) |m| {
//            const artifacts = make_move.makeMove(pos, m);
//            const results = perft(pos, depth - 1, a);
//
//            var buf: [5]u8 = [_]u8{0,0,0,0,0};
//            m.toLongAlgebraic(buf[0..]) catch unreachable;
//            std.debug.print("{s}: {}, {} -> {}\n", .{buf, results.nodes, m.from, m.to});
//            total += results.nodes;
//            make_move.unmakeMove(pos, m, artifacts);
//        }
//    }
//
//    std.debug.print("TOTAL: {}\n", .{total});
//}
