const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_isready = m.map(UciCommand, toUnion("isready", UciCommand), m.string("isready"));
