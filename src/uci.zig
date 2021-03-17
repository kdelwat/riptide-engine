const algebraic = @import("./parse/algebraic.zig");
const fen = @import("./parse/fen.zig");

pub const UciCommandType = enum {
    uci,
    isready,
    position_startpos,
    position,
    ucinewgame,
    debug,
    setoption,
    // go
    stop,
    quit,
    ponderhit,
};

pub const UciCommandPosition = struct {
    fen: fen.Fen,
    moves: []algebraic.LongAlgebraicMove,
};

pub const UciCommandSetOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

pub const UciCommand = union(UciCommandType) {
    uci: void,
    isready: void,
    position_startpos: []algebraic.LongAlgebraicMove,
    position: UciCommandPosition,
    ucinewgame: void,
    debug: bool,
    setoption: UciCommandSetOption,
    quit: void,
    stop: void,
    ponderhit: void,
};