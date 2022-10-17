const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_stop = m.map(UciCommand, toUnion("stop", UciCommand), m.string("stop"));
