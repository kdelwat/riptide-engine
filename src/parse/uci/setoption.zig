const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
usingnamespace @import("mecha");

pub const p_setoption = map(UciCommand, toUnion("setoption", UciCommand), combine(.{string("setoption "), set_option}));

const any_char = oneOf(.{discard(utf8.range('0', '9')), discard(utf8.range('a', 'z')), discard(utf8.range('A', 'Z')), utf8.char(' ')});

const set_option = combine(
    .{
        string("name "),
        asStr(many(any_char, .{.collect = false}))
    }
);
