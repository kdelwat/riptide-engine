const position = @import("./position.zig");
const perft = @import("./perft.zig").perft;
const search = @import("./search.zig");
const logger = @import("./logger.zig");
const PVTable = @import("./pv.zig").PVTable;
const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const evaluate = @import("evaluate.zig").evaluate;

fn fromFEN(f: []const u8) position.Position {
    return position.fromFEN(f, test_allocator) catch unreachable;
}

test "move generation nodes per second" {
    const timer = std.time.Timer.start() catch unreachable;
    expect(perft(&fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"), 5) == 4865609);

    std.debug.print("NPS: {}\n", .{@floatToInt(u64, @intToFloat(f64, 4865609) / (@intToFloat(f64, timer.read()) / @intToFloat(f64, std.time.ns_per_s)))});
}

test "evaluation nodes per second" {
    const timer = std.time.Timer.start() catch unreachable;

    var pos = position.fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", test_allocator) catch unreachable;

    var i: u64 = 0;
    while (i < 1000000) {
        _ = evaluate(&pos);
        i += 1;
    }

    std.debug.print("EPS: {}\n", .{@floatToInt(u64, @intToFloat(f64, 1000000) / (@intToFloat(f64, timer.read()) / @intToFloat(f64, std.time.ns_per_s)))});
}

test "search efficiency (single tree)" {
    var start_pos = &fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    var ctx_cancelled = false;
    var l = logger.Logger.init();
    var stats = search.SearchStats{ .nodes_evaluated = 0, .nodes_visited = 0 };

    var pv = PVTable.init();

    _ = search.search(start_pos, &pv, 6, -search.INFINITY, search.INFINITY, search.SearchContext{ .cancelled = &ctx_cancelled, .logger = l, .a = test_allocator, .stats = &stats });

    std.debug.print("Nodes visited single search: {}/{}\n", .{ stats.nodes_visited, 4865609 });
    std.debug.print("Nodes evaluated single search: {}/{}\n", .{ stats.nodes_evaluated, 4865609 });
}

test "search efficiency (iterative deepening)" {
    var start_pos = &fromFEN("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    var ctx_cancelled = false;
    var l = logger.Logger.init();
    var stats = search.SearchStats{ .nodes_evaluated = 0, .nodes_visited = 0 };

    _ = search.searchUntilDepth(start_pos, 6, search.SearchContext{ .cancelled = &ctx_cancelled, .logger = l, .a = test_allocator, .stats = &stats });

    const tree_nodes =
        20 +
        400 +
        8902 +
        197281 +
        4865609;

    std.debug.print("Nodes visited ID: {}/{}\n", .{ stats.nodes_visited, tree_nodes });
    std.debug.print("Nodes evaluated ID: {}/{}\n", .{ stats.nodes_evaluated, tree_nodes });
}
