const position = @import("./position.zig");
const MoveGenerator = @import("./movegen.zig").MoveGenerator;
const make_move = @import("./make_move.zig");
const Move = @import("./move.zig").Move;
const evaluate = @import("./evaluate.zig");
const debug = @import("./debug.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Timer = std.time.Timer;
const Logger = @import("./logger.zig").Logger;

// Runs a search for the best move.
// searchInfinite uses iterative deepening. It will search to a progressively greater
// depth, returning each best move until it is signalled to stop.
pub const InfiniteSearchContext = struct {
    pos: *position.Position,
    best_move: *?Move,
    thread_ctx: SearchContext,
};

pub const SearchContext = struct {
    cancelled: *bool,
    a: *Allocator,
    logger: Logger,
};

pub fn searchInfinite(context: InfiniteSearchContext) !void {
    const alpha: i64 = -100000;
    const beta: i64 = 100000;

    var depth: u64 = 0;

    try context.thread_ctx.logger.log("SEARCH", "thread started", .{});

    var timer = try Timer.start();
    while(true) {
        try context.thread_ctx.logger.log("SEARCH", "searching: depth = {}", .{depth});

        const result = search(context.pos, depth, alpha, beta, context.thread_ctx);

        try context.thread_ctx.logger.log("SEARCH", "complete: depth = {}, best move = {}, duration = {}",
            .{depth, result, timer.lap() / std.time.ns_per_ms},
        );

        if (context.thread_ctx.cancelled.*) {
            try context.thread_ctx.logger.log("SEARCH", "thread cancelled", .{});
            break;
        }

        if (result) |best_move| {
            context.best_move.* = best_move;
        }

        depth += 1;
    }
}

// Search for the best move for a position, to a given depth.
pub fn search(pos: *position.Position, depth: u64, alpha: i64, beta: i64, ctx: SearchContext) ?Move {
    // Log the starting position of the search
//    var debug_buf = std.ArrayList(u8).init(ctx.a);
//    defer debug_buf.deinit();
//    debug.toFEN(pos.*, &debug_buf) catch unreachable;
//    ctx.logger.log("SEARCH", "\tposition = {s}, depth = {}, alpha = {}, beta = {}", .{debug_buf.items, depth, alpha, beta}) catch unreachable;

    // Generate all legal moves for the current position.
    var gen = MoveGenerator.init();
    gen.generate(pos);

    ctx.logger.log("SEARCH", "\tgenerated starting moves: n = {}", .{gen.count()}) catch unreachable;

    var best_score: i64 = -100000;
    var best_move: ?Move = null;

    // For each move available, run a search of its tree to the given depth, to
    // identify the best outcome.
    while (gen.next()) |m| {
        if (ctx.cancelled.*) {
            break;
        }

        const artifacts = make_move.makeMove(pos, m);
        const negamax_score: i64 = -alphaBeta(pos, &gen, alpha, beta, depth, ctx);

        if (negamax_score >= best_score) {
            best_score = negamax_score;
            best_move = m;
        }

        make_move.unmakeMove(pos, m, artifacts);
    }

    return best_move;
}

// Run a negamax search of the move tree from a given position, to a given
// depth. The negamax search finds the "least-bad" move; the move that minimises
// the opponents advantage no matter how they play.
// An alpha-beta cutoff algorithm prunes the search tree to save time that would be
// wasted exploring moves that have proven already to be worst than the best
// candidate.
// This function was implemented from the pseudocode at
// https://chessprogramming.wikispaces.com/Alpha-Beta.
fn alphaBeta(pos: *position.Position, gen: *MoveGenerator, alpha: i64, beta: i64, depth: u64, ctx: SearchContext) i64 {
    // At the bottom of the tree, return the score of the position for the attacking player.
    if (depth == 0) {
        return evaluate.evaluate(pos);
    }

    var new_alpha: i64 = alpha;

    // Otherwise, generate all possible moves.
    gen.generate(pos);

    while (gen.next()) |m| {
        // Make the move.
        const artifacts = make_move.makeMove(pos, m);

        // Recursively call the search function to determine the move's score.
        const score: i64 = -alphaBeta(pos, gen, -beta, -new_alpha, depth - 1, ctx);

        // If the score is higher than the beta cutoff, the rest of the search
        // tree is irrelevant and the cutoff is returned.
        if (score >= beta) {
            make_move.unmakeMove(pos, m, artifacts);
            gen.cutoff();
            return beta;
        }

        // Otherwise, replace the alpha if the new score is higher.
        if (score > new_alpha) {
            new_alpha = score;
        }

        // Restore the pre-move state of the board.
        make_move.unmakeMove(pos, m, artifacts);
    }

    return new_alpha;
}
