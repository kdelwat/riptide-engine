const position = @import("./position.zig");
const MoveGenerator = @import("./movegen.zig").MoveGenerator;
const PVTable = @import("./pv.zig").PVTable;
const make_move = @import("./make_move.zig");
const Move = @import("./move.zig").Move;
const move = @import("./move.zig");
const evaluate = @import("./evaluate.zig");
const debug = @import("./debug.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Timer = std.time.Timer;
const Logger = @import("./logger.zig").Logger;

pub const INFINITY = 100000;
pub const ASPIRATION_WINDOW = 100; // One pawn

// Runs a search for the best move.
// searchInfinite uses iterative deepening. It will search to a progressively greater
// depth, returning each best move until it is signalled to stop.
pub const InfiniteSearchContext = struct {
    pos: *position.Position,
    best_move: *?Move,
    thread_ctx: SearchContext,
};

pub const SearchContext = struct {
    cancelled: *bool, a: *Allocator, logger: Logger, stats: *SearchStats
};

pub const SearchStats = struct {
    nodes_evaluated: u64, nodes_visited: u64
};

// Infinite search uses an iterative deepening approach. Searches are performed at
// progressively greater depths, until time runs out.
// Based on the result from the prevous iteration, alpha and beta are estimated
// for the next search, which theoretically leads to a more efficient search tree.
pub fn searchInfinite(context: InfiniteSearchContext) !void {
    var alpha: i64 = -INFINITY;
    var beta: i64 = INFINITY;

    var depth: u64 = 1;

    try context.thread_ctx.logger.log("SEARCH", "thread started", .{});

    var pv = PVTable.init();

    var timer = try Timer.start();

    var result: ?SearchResult = null;
    while (true) {
        try context.thread_ctx.logger.log("SEARCH", "searching: depth = {}", .{depth});

        result = search(context.pos, &pv, depth, alpha, beta, context.thread_ctx);

        try context.thread_ctx.logger.log(
            "SEARCH",
            "complete: depth = {}, best move = {}, duration = {}",
            .{ depth, result, timer.lap() / std.time.ns_per_ms },
        );

        if (context.thread_ctx.cancelled.*) {
            try context.thread_ctx.logger.log("SEARCH", "thread cancelled", .{});
            break;
        }

        if (result) |best_move| {
            if (best_move.score <= alpha or best_move.score >= beta) {
                // Aspiration window missed; do a full re-search
                std.debug.print("Missed aspiration window at depth {}\n", .{depth});
                alpha = -INFINITY;
                beta = INFINITY;
                continue;
            } else {
                alpha = best_move.score - ASPIRATION_WINDOW;
                beta = best_move.score + ASPIRATION_WINDOW;
                context.best_move.* = best_move.move;
            }
        }

        depth += 1;
    }
}

pub fn searchUntilDepth(pos: *position.Position, max_depth: u64, context: SearchContext) void {
    var alpha: i64 = -INFINITY;
    var beta: i64 = INFINITY;

    var depth: u64 = 1;
    var pv = PVTable.init();

    while (depth <= max_depth) {
        const result = search(pos, &pv, depth, alpha, beta, context);

        if (result) |best_move| {
            if (best_move.score <= alpha or best_move.score >= beta) {
                // Aspiration window missed; do a full re-search
                alpha = -INFINITY;
                beta = INFINITY;
                continue;
            } else {
                alpha = best_move.score - ASPIRATION_WINDOW;
                beta = best_move.score + ASPIRATION_WINDOW;
            }
        }

        depth += 1;
    }
}

// Search for the best move for a position, to a given depth.
const SearchResult = struct {
    move: Move, score: i64
};

pub fn search(pos: *position.Position, pv: *PVTable, depth: u64, alpha: i64, beta: i64, ctx: SearchContext) ?SearchResult {
    var gen = MoveGenerator.init();

    var score = alphaBeta(pos, &gen, pv, alpha, beta, depth, 0, ctx) catch {
        return null;
    };

    if (pv.get(0)) |best_move| {
        return SearchResult{ .move = best_move, .score = score };
    } else {
        return null;
    }
}

// Run a negamax search of the move tree from a given position, to a given
// depth. The negamax search finds the "least-bad" move; the move that minimises
// the opponents advantage no matter how they play.
// An alpha-beta cutoff algorithm prunes the search tree to save time that would be
// wasted exploring moves that have proven already to be worst than the best
// candidate.
// This function was implemented from the pseudocode at
// https://chessprogramming.wikispaces.com/Alpha-Beta.
const AlphaBetaError = error{Cancelled};

fn alphaBeta(pos: *position.Position, gen: *MoveGenerator, pv: *PVTable, alpha: i64, beta: i64, depth: u64, ply: u64, ctx: SearchContext) AlphaBetaError!i64 {
    if (ctx.cancelled.*) {
        return AlphaBetaError.Cancelled;
    }

    ctx.stats.nodes_visited += 1;

    // std.debug.warn("AB: ply = {}, alpha = {}, beta = {}", .{ ply, alpha, beta });

    // At the bottom of the tree, return the score of the position for the attacking player.
    if (depth == 0) {
        ctx.stats.nodes_evaluated += 1;
        return quiesce(pos, gen, pv, alpha, beta);
    }

    var new_alpha: i64 = alpha;

    // Otherwise, generate all possible moves.
    gen.generate(pos);

    gen.orderer.setPV(pv.get(ply));

    while (gen.next()) |m| {
        // Make the move.
        const artifacts = make_move.makeMove(pos, m);

        // Recursively call the search function to determine the move's score.
        const score: i64 = -(try alphaBeta(pos, gen, pv, -beta, -new_alpha, depth - 1, ply + 1, ctx));

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

            // This is the new best move / principal variation
            pv.set(ply, m);
        }

        // Restore the pre-move state of the board.
        make_move.unmakeMove(pos, m, artifacts);
    }

    return new_alpha;
}

fn quiesce(pos: *position.Position, gen: *MoveGenerator, pv: *PVTable, alpha: i64, beta: i64) i64 {
    const stand_pat = evaluate.evaluate(pos);

    if (stand_pat >= beta) {
        return beta;
    }

    var new_alpha: i64 = alpha;
    if (alpha < stand_pat) {
        new_alpha = stand_pat;
    }

    // Generate all possible moves.
    gen.generate(pos);

    // Don't use the PV
    gen.orderer.setPV(null);

    // Loop through captures
    while (gen.next()) |m| {
        if (m.move_type != move.MoveType.capture) {
            continue;
        }

        // Make the move.
        const artifacts = make_move.makeMove(pos, m);

        // Recursively call the search function to determine the move's score.
        const score: i64 = -quiesce(pos, gen, pv, -beta, -new_alpha);

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
