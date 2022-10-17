const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const UciCommandSetOption = @import("../../uci.zig").UciCommandSetOption;
const m = @import("mecha");

pub const p_setoption = m.map(UciCommand, toUnion("setoption", UciCommand), m.combine(.{ m.string("setoption "), set_option }));

const any_char = m.oneOf(.{ m.discard(m.utf8.range('0', '9')), m.discard(m.utf8.range('a', 'z')), m.discard(m.utf8.range('A', 'Z')) });

const set_option = m.map(UciCommandSetOption, m.toStruct(UciCommandSetOption), m.combine(.{ m.string("name "), m.asStr(m.many(any_char, .{ .collect = false })), m.opt(m.combine(.{ m.string(" value "), m.asStr(m.many(m.oneOf(.{ any_char, m.utf8.char(' ') }), .{ .collect = false })) })) }));
