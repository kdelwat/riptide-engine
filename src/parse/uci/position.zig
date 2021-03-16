const toUnion = @import("../to_union.zig").toUnion;
const UciCommand = @import("../../uci.zig").UciCommand;
const UciCommandPosition = @import("../../uci.zig").UciCommandPosition;
const fen = @import("../fen.zig").fen;
const algebraic = @import("../algebraic.zig");
usingnamespace @import("mecha");

pub const p_position = map(
    UciCommand,
    toUnion("position", UciCommand),
    combine(.{
        string("position "),
        map(UciCommandPosition, toStruct(UciCommandPosition), combine(.{
            fen,
            discard(opt(utf8.char(' '))),
            many(algebraic.long_algebraic_notation, .{.collect = true})
        }))
    })
);

pub const p_position_startpos = map(
    UciCommand,
    toUnion("position_startpos", UciCommand),
    combine(.{
        string("position startpos"),
        discard(opt(utf8.char(' '))),
        many(algebraic.long_algebraic_notation, .{.collect = true})
    })
);
