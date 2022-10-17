const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_ucinewgame = m.map(UciCommand, toUnion("ucinewgame", UciCommand), m.string("ucinewgame"));
