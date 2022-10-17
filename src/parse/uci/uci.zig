const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_uci = m.map(UciCommand, toUnion("uci", UciCommand), m.string("uci"));
