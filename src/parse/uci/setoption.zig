const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const UciCommandSetOption = @import("../../uci.zig").UciCommandSetOption;
usingnamespace @import("mecha");

pub const p_setoption = map(UciCommand, toUnion("setoption", UciCommand), combine(.{string("setoption "), set_option}));

const any_char = oneOf(.{discard(utf8.range('0', '9')), discard(utf8.range('a', 'z')), discard(utf8.range('A', 'Z'))});

const set_option = map(UciCommandSetOption, toStruct(UciCommandSetOption), combine(
    .{
        string("name "),
        asStr(many(any_char, .{.collect = false})),
        opt(combine(.{string(" value "), asStr(many(oneOf(.{any_char, utf8.char(' ')}), .{.collect = false}))}))
    }
));