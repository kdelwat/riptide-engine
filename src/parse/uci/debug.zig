const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
usingnamespace @import("mecha");

pub const p_debug = map(UciCommand, toUnion("debug", UciCommand), combine(.{string("debug "), boolean}));

const boolean = oneOf(.{parse_on, parse_off});
const parse_on = map(bool, struct {fn f(_: anytype) bool {return true;}}.f, string("on"));
const parse_off = map(bool, struct {fn f(_: anytype) bool {return false;}}.f, string("off"));
