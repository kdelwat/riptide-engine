const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_quit = m.map(UciCommand, toUnion("quit", UciCommand), m.string("quit"));
