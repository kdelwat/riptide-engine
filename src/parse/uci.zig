usingnamespace @import("mecha");

const p_isready = @import("./uci/isready.zig").p_isready;
const p_position = @import("./uci/position.zig").p_position;
const p_position_startpos = @import("./uci/position.zig").p_position_startpos;
const p_ucinewgame = @import("./uci/ucinewgame.zig").p_ucinewgame;
const p_uci = @import("./uci/uci.zig").p_uci;
const p_debug = @import("./uci/debug.zig").p_debug;
const p_setoption = @import("./uci/setoption.zig").p_setoption;
const p_quit = @import("./uci/quit.zig").p_quit;

pub const uci_command = combine(
    .{oneOf(
        .{
            p_isready,
            p_position,
            p_position_startpos,
            p_ucinewgame,
            p_uci,
            p_debug,
            p_setoption,
            p_quit
        }
    )}
);