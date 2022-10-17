const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_ponderhit = m.map(UciCommand, toUnion("ponderhit", UciCommand), m.string("ponderhit"));
