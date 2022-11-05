const position = @import("./position.zig");
const MoveGenerator = @import("./movegen.zig").MoveGenerator;
const PVTable = @import("./pv.zig").PVTable;
const make_move = @import("./make_move.zig");
const Move = @import("./move.zig").Move;
const move = @import("./move.zig");
const evaluate = @import("./evaluate.zig");
const Score = evaluate.Score;
const debug = @import("./debug.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Timer = std.time.Timer;
const Logger = @import("./logger.zig").Logger;
const TranspositionTable = @import("TranspositionTable.zig").TranspositionTable;
const TranspositionData = @import("TranspositionData.zig").TranspositionData;
const NodeType = @import("TranspositionData.zig").NodeType;

pub const ASPIRATION_WINDOW = 100; // One pawn

pub const SearchContext = struct { cancelled: *bool, a: Allocator, logger: Logger, stats: *SearchStats };

pub const SearchStats = struct { nodes_evaluated: u64, nodes_visited: u64 };

// Max depth is 255
pub const Depth = u8;

// Infinite search uses an iterative deepening approach. Searches are performed at
// progressively greater depths, until time runs out.
// Based on the result from the prevous iteration, alpha and beta are estimated
// for the next search, which theoretically leads to a more efficient search tree.
pub fn searchInfinite(pos: *position.Position, tt: *TranspositionTable, best_move: *?Move, cancelled: *bool, stats: *SearchStats, a: Allocator, logger: Logger) !void {
    var alpha: Score = -evaluate.INFINITY;
    var beta: Score = evaluate.INFINITY;

    var depth: Depth = 1;

    try logger.log("SEARCH", "thread started", .{});

    var pv = PVTable.init();

    var timer = try Timer.start();

    var result: ?SearchResult = null;
    while (true) {
        try logger.log("SEARCH", "searching: depth = {}", .{depth});
        std.debug.print("searching: depth = {}\n", .{depth});

        result = search(pos, tt, &pv, depth, alpha, beta, .{ .logger = logger, .a = a, .cancelled = cancelled, .stats = stats });

        try logger.log(
            "SEARCH",
            "complete: depth = {}, best move = {?}, duration = {}",
            .{ depth, result, timer.lap() / std.time.ns_per_ms },
        );

        if (cancelled.*) {
            try logger.log("SEARCH", "thread cancelled", .{});
            try logger.log("SEARCH", "TT stats: {}", .{tt.stats});
            break;
        }

        if (result) |bm| {
            if (bm.score <= alpha or bm.score >= beta) {
                // Aspiration window missed; do a full re-search
                std.debug.print("Missed aspiration window at depth {}\n", .{depth});
                alpha = -evaluate.INFINITY;
                beta = evaluate.INFINITY;
                continue;
            } else {
                alpha = bm.score - ASPIRATION_WINDOW;
                beta = bm.score + ASPIRATION_WINDOW;
                best_move.* = bm.move;
            }
        }

        depth += 1;
    }
}

pub fn searchUntilDepth(pos: *position.Position, tt: *TranspositionTable, max_depth: Depth, context: SearchContext) void {
    var alpha: Score = -evaluate.INFINITY;
    var beta: Score = evaluate.INFINITY;

    var depth: Depth = 1;
    var pv = PVTable.init();

    while (depth <= max_depth) {
        const result = search(pos, tt, &pv, depth, alpha, beta, context);

        if (result) |best_move| {
            if (best_move.score <= alpha or best_move.score >= beta) {
                // Aspiration window missed; do a full re-search
                alpha = -evaluate.INFINITY;
                beta = evaluate.INFINITY;
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
const SearchResult = struct { move: Move, score: Score };

pub fn search(pos: *position.Position, tt: *TranspositionTable, pv: *PVTable, depth: Depth, alpha: Score, beta: Score, ctx: SearchContext) ?SearchResult {
    var gen = MoveGenerator.init();

    var score = alphaBeta(pos, &gen, tt, pv, alpha, beta, depth, 0, ctx) catch {
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
// and https://en.wikipedia.org/wiki/Negamax
const AlphaBetaError = error{Cancelled};

fn alphaBeta(pos: *position.Position, gen: *MoveGenerator, tt: *TranspositionTable, pv: *PVTable, alpha: Score, beta: Score, depth: Depth, ply: Depth, ctx: SearchContext) AlphaBetaError!Score {
    //std.debug.print("AB: pos={} alpha={} beta={} depth={}\n", .{ pos.hash.hash, alpha, beta, depth });
    if (ctx.cancelled.*) {
        return AlphaBetaError.Cancelled;
    }

    ctx.stats.nodes_visited += 1;

    var new_alpha: Score = alpha;
    var new_beta: Score = beta;

    // Check the transposition table
    if (tt.get(pos)) |entry| {
        // std.debug.print("HIT {}\n", .{entry});
        // Ensure the entry has been evaluated deep enough
        if (entry.depth >= depth) {
            if (entry.node_type == NodeType.exact) {
                return entry.score;
            } else if (entry.node_type == NodeType.lowerbound) {
                new_alpha = std.math.max(new_alpha, entry.score);
            } else {
                new_beta = std.math.min(new_beta, entry.score);
            }
        }
    } else {
        //std.debug.print("MISS \n", .{});
    }

    // At the bottom of the tree, return the score of the position for the attacking player.
    if (depth == 0) {
        ctx.stats.nodes_evaluated += 1;
        var q = quiesce(pos, gen, pv, new_alpha, new_beta);
        var tt_data = TranspositionData.init(0, q, NodeType.exact);
        tt.put(pos, tt_data);
        return q;
    }

    // Otherwise, generate all possible moves.
    gen.generate(pos);

    gen.orderer.setPV(pv.get(ply));

    var did_beta_cutoff: bool = false;
    var beta_cutoff: Score = 0;

    while (gen.next()) |m| {
        // Make the move.
        const artifacts = make_move.makeMove(pos, m);

        // Recursively call the search function to determine the move's score.
        const score: Score = -(try alphaBeta(pos, gen, tt, pv, -new_beta, -new_alpha, depth - 1, ply + 1, ctx));

        // If the score is higher than the beta cutoff, the rest of the search
        // tree is irrelevant and the cutoff is returned.
        if (score >= new_beta) {
            make_move.unmakeMove(pos, m, artifacts);
            gen.cutoff();
            did_beta_cutoff = true;
            beta_cutoff = new_beta;
            break;
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

    if (did_beta_cutoff) {
        // Fail-high = lower bound on score
        var tt_data = TranspositionData.init(depth, beta_cutoff, NodeType.lowerbound);
        tt.put(pos, tt_data);

        return beta_cutoff;
    } else if (new_alpha > alpha) {
        // If alpha improved, new exact score
        var tt_data = TranspositionData.init(depth, new_alpha, NodeType.exact);
        tt.put(pos, tt_data);
        return new_alpha;
    } else {
        // Fail-low = upper bound on score
        var tt_data = TranspositionData.init(depth, new_alpha, NodeType.upperbound);
        tt.put(pos, tt_data);
        return new_alpha;
    }
}

fn quiesce(pos: *position.Position, gen: *MoveGenerator, pv: *PVTable, alpha: Score, beta: Score) Score {
    const stand_pat = evaluate.evaluate(pos);

    if (stand_pat >= beta) {
        return beta;
    }

    var new_alpha: Score = alpha;
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
        const score: Score = -quiesce(pos, gen, pv, -beta, -new_alpha);

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
