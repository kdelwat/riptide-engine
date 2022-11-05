const position = @import("./position.zig");
const perft = @import("./perft.zig").perft;
const search = @import("./search.zig");
const logger = @import("./logger.zig");
const PVTable = @import("./pv.zig").PVTable;
const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const evaluate = @import("evaluate.zig").evaluate;
const INFINITY = @import("evaluate.zig").INFINITY;
const GameData = @import("GameData.zig").GameData;
const GameOptions = @import("GameData.zig").GameOptions;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

test "move generation nodes per second" {
    var timer = std.time.Timer.start() catch unreachable;
    try expect(perft(&fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), 5) == 4865609);

    std.debug.print("NPS: {}\n", .{@floatToInt(u64, @intToFloat(f64, 4865609) / (@intToFloat(f64, timer.read()) / @intToFloat(f64, std.time.ns_per_s)))});
}

test "evaluation nodes per second" {
    var timer = std.time.Timer.start() catch unreachable;

    var pos = position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", test_allocator) catch unreachable;

    var i: u64 = 0;
    while (i < 1000000) {
        _ = evaluate(&pos);
        i += 1;
    }

    std.debug.print("EPS: {}\n", .{@floatToInt(u64, @intToFloat(f64, 1000000) / (@intToFloat(f64, timer.read()) / @intToFloat(f64, std.time.ns_per_s)))});
}

test "search efficiency (single tree)" {
    var start_pos = fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    var l = logger.Logger.init();
    var game_data = try GameData.init(test_allocator, GameOptions{ .hash_table_size = 0, .threads = 1 });
    defer game_data.deinit();

    var searcher = search.Searcher.init(start_pos, &game_data, test_allocator, l);

    _ = searcher.search(6, -INFINITY, INFINITY);

    std.debug.print("Nodes visited single search: {}/{}\n", .{ searcher.stats.nodes_visited, 4865609 });
    std.debug.print("Nodes evaluated single search: {}/{}\n", .{ searcher.stats.nodes_evaluated, 4865609 });
}

test "search efficiency (iterative deepening)" {
    var start_pos = fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    var l = logger.Logger.init();
    var game_data = try GameData.init(test_allocator, GameOptions{ .hash_table_size = 128, .threads = 1 });

    var searcher = search.Searcher.init(start_pos, &game_data, test_allocator, l);

    _ = searcher.searchUntilDepthIterative(6);

    const tree_nodes =
        20 +
        400 +
        8902 +
        197281 +
        4865609;

    std.debug.print("Nodes visited ID: {}/{}\n", .{ searcher.stats.nodes_visited, tree_nodes });
    std.debug.print("Nodes evaluated ID: {}/{}\n", .{ searcher.stats.nodes_evaluated, tree_nodes });

    game_data.deinit();

    start_pos = fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    game_data = try GameData.init(test_allocator, GameOptions{ .hash_table_size = 0, .threads = 1 });

    searcher = search.Searcher.init(start_pos, &game_data, test_allocator, l);

    _ = searcher.searchUntilDepthIterative(6);

    std.debug.print("Nodes visited ID (no hash): {}/{}\n", .{ searcher.stats.nodes_visited, tree_nodes });
    std.debug.print("Nodes evaluated ID (no hash): {}/{}\n", .{ searcher.stats.nodes_evaluated, tree_nodes });

    game_data.deinit();
}
