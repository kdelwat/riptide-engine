const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const position = @import("./position.zig");
const TranspositionTable = @import("./TranspositionTable.zig").TranspositionTable;
const TranspositionData = @import("./TranspositionData.zig").TranspositionData;
const NodeType = @import("./TranspositionData.zig").NodeType;
const Move = @import("./move.zig").Move;
const MoveType = @import("./move.zig").MoveType;
const PieceType = @import("./piece.zig").PieceType;
const Color = @import("./color.zig").Color;

fn fromFEN(f: []const u8) !position.Position {
    return position.fromFEN(f, test_allocator);
}

var ENTRY_TEST_CASES = [3]TranspositionData{ TranspositionData.init(1, 50, NodeType.exact, Move.initQuiet(0, 1, Color.white, PieceType.king)), TranspositionData.init(5, -100, NodeType.lowerbound, Move.initQuiet(0, 1, Color.white, PieceType.king)), TranspositionData.init(1, 50, NodeType.exact, Move.initCapture(0, 1, Color.white, PieceType.king, PieceType.bishop)) };

test "Set and get entries (new table)" {
    var pos = fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2") catch unreachable;
    for (ENTRY_TEST_CASES) |test_case| {
        var tt = try TranspositionTable.init(test_allocator, 1);

        tt.put(&pos, test_case);
        var maybe_data = tt.get(&pos);

        if (maybe_data) |got| {
            try expectEqual(test_case.depth, got.depth);
            try expectEqual(test_case.score, got.score);
            try expectEqual(test_case.node_type, got.node_type);
            try expectEqual(test_case.from, got.from);
            try expectEqual(test_case.to, got.to);
            try expectEqual(test_case.move_type, got.move_type);
            try expectEqual(test_case.piece_color, got.piece_color);
            try expectEqual(test_case.piece_type, got.piece_type);
            try expectEqual(test_case.captured_piece_color, got.captured_piece_color);
            try expectEqual(test_case.captured_piece_type, got.captured_piece_type);
        } else {
            try expect(false);
        }

        tt.deinit();
    }
}

test "Set and get entries (shared table)" {
    var pos = fromFEN("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2") catch unreachable;
    var tt = try TranspositionTable.init(test_allocator, 1);
    defer tt.deinit();

    for (ENTRY_TEST_CASES) |test_case| {
        tt.put(&pos, test_case);
        var maybe_data = tt.get(&pos);

        if (maybe_data) |got| {
            try expectEqual(test_case.depth, got.depth);
            try expectEqual(test_case.score, got.score);
            try expectEqual(test_case.node_type, got.node_type);
            try expectEqual(test_case.from, got.from);
            try expectEqual(test_case.to, got.to);
            try expectEqual(test_case.move_type, got.move_type);
            try expectEqual(test_case.piece_color, got.piece_color);
            try expectEqual(test_case.piece_type, got.piece_type);
            try expectEqual(test_case.captured_piece_color, got.captured_piece_color);
            try expectEqual(test_case.captured_piece_type, got.captured_piece_type);
        } else {
            try expect(false);
        }
    }
}
