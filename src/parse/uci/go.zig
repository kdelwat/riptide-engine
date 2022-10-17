const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const GoOption = @import("../../uci.zig").GoOption;
const GoOptionType = @import("../../uci.zig").GoOptionType;
const m = @import("mecha");

pub const p_go = m.map(UciCommand, toUnion("go", UciCommand), m.combine(.{ m.string("go "), go }));

const go = m.many(m.combine(.{ option, m.discard(m.opt(m.utf8.char(' '))) }), .{});
const algebraic = @import("../algebraic.zig");

const option = m.oneOf(.{
    option_infinite,
    option_ponder,
    option_wtime,
    option_btime,
    option_winc,
    option_binc,
    option_movestogo,
    option_depth,
    option_nodes,
    option_mate,
    option_movetime,
    option_searchmoves,
});

const option_infinite = m.map(GoOption, toUnion("infinite", GoOption), m.string("infinite"));
const option_ponder = m.map(GoOption, toUnion("ponder", GoOption), m.string("ponder"));
const option_wtime = m.map(GoOption, toUnion("wtime", GoOption), m.combine(.{ m.string("wtime "), m.int(u64, .{ .base = 10 }) }));
const option_btime = m.map(GoOption, toUnion("btime", GoOption), m.combine(.{ m.string("btime "), m.int(u64, .{ .base = 10 }) }));
const option_winc = m.map(GoOption, toUnion("winc", GoOption), m.combine(.{ m.string("winc "), m.int(u64, .{ .base = 10 }) }));
const option_binc = m.map(GoOption, toUnion("binc", GoOption), m.combine(.{ m.string("binc "), m.int(u64, .{ .base = 10 }) }));
const option_movestogo = m.map(GoOption, toUnion("movestogo", GoOption), m.combine(.{ m.string("movestogo "), m.int(u64, .{ .base = 10 }) }));
const option_depth = m.map(GoOption, toUnion("depth", GoOption), m.combine(.{ m.string("depth "), m.int(u64, .{ .base = 10 }) }));
const option_nodes = m.map(GoOption, toUnion("nodes", GoOption), m.combine(.{ m.string("nodes "), m.int(u64, .{ .base = 10 }) }));
const option_mate = m.map(GoOption, toUnion("mate", GoOption), m.combine(.{ m.string("mate "), m.int(u64, .{ .base = 10 }) }));
const option_movetime = m.map(GoOption, toUnion("movetime", GoOption), m.combine(.{ m.string("movetime "), m.int(u64, .{ .base = 10 }) }));
const option_searchmoves = m.map(GoOption, toUnion("searchmoves", GoOption), m.combine(.{ m.string("searchmoves "), m.many(algebraic.long_algebraic_notation, .{ .collect = true }) }));
