const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const GoOption = @import("../../uci.zig").GoOption;
const GoOptionType = @import("../../uci.zig").GoOptionType;
usingnamespace @import("mecha");

pub const p_go = map(UciCommand, toUnion("go", UciCommand), combine(.{string("go "), go}));

const go = many(combine(.{option, discard(opt(utf8.char(' ')))}), .{});
const algebraic = @import("../algebraic.zig");

const option = oneOf(.{
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

const option_infinite = map(GoOption, toUnion("infinite", GoOption), string("infinite"));
const option_ponder = map(GoOption, toUnion("ponder", GoOption), string("ponder"));
const option_wtime = map(GoOption, toUnion("wtime", GoOption), combine(.{string("wtime "), int(u64, 10)}));
const option_btime = map(GoOption, toUnion("btime", GoOption), combine(.{string("btime "), int(u64, 10)}));
const option_winc = map(GoOption, toUnion("winc", GoOption), combine(.{string("winc "), int(u64, 10)}));
const option_binc = map(GoOption, toUnion("binc", GoOption), combine(.{string("binc "), int(u64, 10)}));
const option_movestogo = map(GoOption, toUnion("movestogo", GoOption), combine(.{string("movestogo "), int(u64, 10)}));
const option_depth = map(GoOption, toUnion("depth", GoOption), combine(.{string("depth "), int(u64, 10)}));
const option_nodes = map(GoOption, toUnion("nodes", GoOption), combine(.{string("nodes "), int(u64, 10)}));
const option_mate = map(GoOption, toUnion("mate", GoOption), combine(.{string("mate "), int(u64, 10)}));
const option_movetime = map(GoOption, toUnion("movetime", GoOption), combine(.{string("movetime "), int(u64, 10)}));
const option_searchmoves = map(GoOption, toUnion("searchmoves", GoOption), combine(.{string("searchmoves "), many(algebraic.long_algebraic_notation, .{.collect = true})}));