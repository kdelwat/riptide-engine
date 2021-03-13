const position = @import("./position");
const movegen = @import("./movegen");
const make_move = @import("./make_move");
const move = @import("./move");
const std = @import("std");
const Allocator = std.mem.Allocator;


// Search for the best move for a position, to a given depth.
fn search(pos: *position.Position, depth: u32, alpha: i64, beta: i64, a: *Allocator) u32 {
    // Generate all legal moves for the current position.
    var moves = ArrayList(u32).init(a);
    defer moves.deinit();
    movegen.generateLegalMoves(&moves, pos);

    var best_score: i64 = -100000;
    var best_move: u32 = move.NULL_MOVE;

    // For each move available, run a search of its tree to the given depth, to
    // identify the best outcome.
    for (moves.items) |m| {
        if (m == move.NULL_MOVE) {
            // Not a legal move
            continue;
        }

        const artifacts = make_move.makeMove(pos, m);
        const negamax_score: i64 = -alphaBeta(pos, alpha, beta, depth);

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
fn alphaBeta(pos: *position.Position, alpha: i64, beta: i64, depth: u32, a: *Allocator) i64 {
    // At the bottom of the tree, return the score of the position for the attacking player.
    if (depth == 0) {
        return evalute.evaluate(pos.*);
    }

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
        const score: i64 = -alphaBeta(pos, -beta, -alpha, depth - 1);

        // If the score is higher than the beta cutoff, the rest of the search
        // tree is irrelevant and the cutoff is returned.
        if (score >= beta) {
            make_move.unmakeMove(pos, m, artifacts);
            return beta;
        }

        // Otherwise, replace the alpha if the new score is higher.
        if (score > alpha) {
            alpha = score;
        }

        // Restore the pre-move state of the board.
        make_move.unmakeMove(pos, m, artifacts);
    }

    return alpha;
}
