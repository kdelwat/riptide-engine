const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const UciCommandPosition = @import("../../uci.zig").UciCommandPosition;
const fen = @import("../fen.zig").fen;
const algebraic = @import("../algebraic.zig");
const m = @import("mecha");
const utf8 = m.utf8;

pub const p_position = m.map(UciCommand, toUnion("position", UciCommand), m.combine(.{ m.string("position fen "), m.map(UciCommandPosition, m.toStruct(UciCommandPosition), m.combine(.{ fen, m.discard(m.opt(m.utf8.char(' '))), m.many(algebraic.long_algebraic_notation, .{ .collect = true }) })) }));

pub const p_position_startpos = m.map(UciCommand, toUnion("position_startpos", UciCommand), m.combine(.{ m.string("position startpos"), m.discard(m.opt(utf8.char(' '))), m.many(algebraic.long_algebraic_notation, .{ .collect = true }) }));
