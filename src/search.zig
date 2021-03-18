const position = @import("./position.zig");
const movegen = @import("./movegen.zig");
const make_move = @import("./make_move.zig");
const move = @import("./move.zig");
const evaluate = @import("./evaluate.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Timer = std.time.Timer;

// Runs a search for the best move.
// searchInfinite uses iterative deepening. It will search to a progressively greater
// depth, returning each best move until it is signalled to stop.
pub const InfiniteSearchContext = struct {
    pos: *position.Position,
    best_move: *u32,
    cancelled: *bool,
    a: *Allocator,
    stderr: File,
};

pub fn searchInfinite(context: InfiniteSearchContext) !void {
    const alpha: i64 = -100000;
    const beta: i64 = 100000;

    var depth: u64 = 0;

    try context.stderr.writer().print(
        "??? [SEARCH] thread started\n",
        .{},
    );

    var timer = try Timer.start();
    while(true) {
        try context.stderr.writer().print(
            "??? [SEARCH] searching: depth = {}\n",
            .{depth},
        );

        const result = search(context.pos, depth, alpha, beta, context.cancelled, context.a);

        try context.stderr.writer().print(
            "??? [SEARCH] search complete: depth = {}, best move = {}, duration = {}\n",
            .{depth, result, timer.lap() / std.time.ns_per_ms},
        );

        if (context.cancelled.*) {
            try context.stderr.writer().print(
                "??? [SEARCH] thread cancelled\n",
                .{},
            );

            break;
        }

        context.best_move.* = result;

        depth += 1;
    }
}

// Search for the best move for a position, to a given depth.
pub fn search(pos: *position.Position, depth: u64, alpha: i64, beta: i64, should_cancel: *bool, a: *Allocator) u32 {
    // Generate all legal moves for the current position.
    var moves = ArrayList(u32).init(a);
    defer moves.deinit();
    movegen.generateLegalMoves(&moves, pos);

    var best_score: i64 = -100000;
    var best_move: u32 = move.NULL_MOVE;

    // For each move available, run a search of its tree to the given depth, to
    // identify the best outcome.
    for (moves.items) |m| {
        if (should_cancel.*) {
            break;
        }

        if (m == move.NULL_MOVE) {
            // Not a legal move
            continue;
        }

        const artifacts = make_move.makeMove(pos, m);
        const negamax_score: i64 = -alphaBeta(pos, alpha, beta, depth, a);

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
fn alphaBeta(pos: *position.Position, alpha: i64, beta: i64, depth: u64, a: *Allocator) i64 {
    // At the bottom of the tree, return the score of the position for the attacking player.
    if (depth == 0) {
        return evaluate.evaluate(pos.*);
    }

    var new_alpha: i64 = alpha;

    // Otherwise, generate all possible moves.
    var moves = ArrayList(u32).init(a);
    defer moves.deinit();
    movegen.generateLegalMoves(&moves, pos);

    for (moves.items) |m| {
        if (m == move.NULL_MOVE) {
            // Not a legal move
            continue;
        }

        // Make the move.
        const artifacts = make_move.makeMove(pos, m);

        // Recursively call the search function to determine the move's score.
        const score: i64 = -alphaBeta(pos, -beta, -new_alpha, depth - 1, a);

        // If the score is higher than the beta cutoff, the rest of the search
        // tree is irrelevant and the cutoff is returned.
        if (score >= beta) {
            make_move.unmakeMove(pos, m, artifacts);
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
