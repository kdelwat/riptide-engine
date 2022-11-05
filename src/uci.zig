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
    go,
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
    go: []GoOption,
    stop: void,
    ponderhit: void,
};

pub const GoOptionType = enum {
    infinite,
    ponder,
    wtime,
    btime,
    winc,
    binc,
    movestogo,
    depth,
    nodes,
    mate,
    movetime,
    searchmoves,
};

pub const GoOption = union(GoOptionType) {
    infinite: void,
    ponder: void,
    wtime: u64,
    btime: u64,
    winc: u64,
    binc: u64,
    movestogo: u64,
    depth: u8,
    nodes: u64,
    mate: u64,
    movetime: u64,
    searchmoves: []algebraic.LongAlgebraicMove,
};
