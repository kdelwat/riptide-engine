const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const m = @import("mecha");

pub const p_debug = m.map(UciCommand, toUnion("debug", UciCommand), m.combine(.{ m.string("debug "), boolean }));

const boolean = m.oneOf(.{ parse_on, parse_off });
const parse_on = m.map(bool, struct {
    fn f(_: anytype) bool {
        return true;
    }
}.f, m.string("on"));
const parse_off = m.map(bool, struct {
    fn f(_: anytype) bool {
        return false;
    }
}.f, m.string("off"));
