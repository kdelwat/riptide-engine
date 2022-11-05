const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const UciCommandSetOption = @import("../../uci.zig").UciCommandSetOption;
const EngineOption = @import("../../uci.zig").EngineOption;
const EngineOptionType = @import("../../uci.zig").EngineOptionType;
const m = @import("mecha");

pub const p_setoption = m.map(UciCommand, toUnion("setoption", UciCommand), m.combine(.{ m.string("setoption "), option }));

const any_char = m.oneOf(.{ m.discard(m.utf8.range('0', '9')), m.discard(m.utf8.range('a', 'z')), m.discard(m.utf8.range('A', 'Z')) });

const name = m.string("name ");
const value = m.string(" value ");

const option = m.oneOf(.{
    option_hash,
    option_threads,
    option_unknown,
});

const option_hash = m.map(EngineOption, toUnion("hash", EngineOption), m.combine(.{ name, m.string("Hash "), value, m.int(u64, .{ .base = 10 }) }));

const option_threads = m.map(EngineOption, toUnion("threads", EngineOption), m.combine(.{ name, m.string("Threads "), value, m.int(u64, .{ .base = 10 }) }));

const option_unknown = m.map(EngineOption, toUnion("unknown", EngineOption), m.discard(m.combine(.{ name, m.many(m.oneOf(.{ any_char, m.utf8.char(' ') }), .{ .collect = false }) })));
