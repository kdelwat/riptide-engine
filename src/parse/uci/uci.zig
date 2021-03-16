const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
usingnamespace @import("mecha");

pub const p_uci = map(UciCommand, toUnion("uci", UciCommand), string("uci"));
