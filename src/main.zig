const std = @import("std");
const File = std.fs.File;
const position = @import("./position.zig");
const parse_uci = @import("./parse/uci.zig").uci_command;
const uci = @import("./uci.zig");
const algebraic = @import("./parse/algebraic.zig");
const UciCommandType = @import("./uci.zig").UciCommandType;
const GoOption = @import("./uci.zig").GoOption;
const GoOptionType = @import("./uci.zig").GoOptionType;
const fen = @import("./parse/fen.zig");
const start_position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

// Store the current position and current best move of the engine, used globally
// to ensure that search can continue in the background while the engine
// continue to receive commands.
const GlobalData = struct {
    pos: position.Position,
    best_move: u32,
};

var engine_data: GlobalData = undefined;

const SearchMode = enum {
    infinite,
    depth,
    nodes,
    movetime,
    ponder,
    mate,
};

// Whether or not debug mode has been requested by the client
var debug_mode: bool = false;

// Store the global options set via Universal Chess Interface commands for the
// engine to follow during runtime.
const AnalysisOptions = struct {
    search_mode: SearchMode,

    // search_moves is a list of moves to consider when searching, to the exclusion of others
    search_moves: []const algebraic.LongAlgebraicMove,

    // ponder places the engine in ponder mode, which searches for the next move during
    // the opponent's turn.
    ponder: bool,

    // wtime and btime control the amount of time each player has in the game. winc and
    // binc determine the time increment added to each player after each move.
    wtime: u64,
    btime: u64,
    winc: u64,
    binc: u64,

    // depth, nodes, movesToMate, and movetime provide the options for the search
    // algorithm chosen.
    movestogo: u64,
    depth: u64,
    nodes: u64,
    moves_to_mate: u64,
    movetime: u64,
};

// From https://ziglearn.org/chapter-2/#readers-and-writers
fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    var line: []const u8 = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;

    if (std.builtin.Target.current.os.tag == .windows) {
        line = std.mem.trimRight(u8, line[0..], "\r");
    }

    return line;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();
    const stdin = std.io.getStdIn();

    var quit: bool = false;

    var buffer: [300]u8 = undefined;

    while (!quit) {
        const input = (try nextLine(stdin.reader(), &buffer)).?;
        try stderr.writer().print(
            "Command: \"{s}\"\n",
            .{input},
        );

        if (std.mem.eql(u8, input, "quit")) {
            quit = true;
        }

        quit = try handleCommand(input, stdout, stderr);
    }
}

fn handleCommand(input: []const u8, stdout: File, stderr: File) !bool {
    const c: uci.UciCommand = (try parse_uci(std.testing.allocator, input)).value;

    switch (c) {
        UciCommandType.uci =>
            try stdout.writer().print(
                "id name Riptide\nid author Cadel Watson\nuciok\n",
                .{},
            ),

        UciCommandType.isready =>
            try stdout.writer().print(
                "readyok\n",
                .{},
            ),

        UciCommandType.position_startpos => |moves| {
            startNewGame(start_position);
        },

        UciCommandType.ucinewgame =>
            startNewGame(start_position),

        UciCommandType.position => |pos| {
            try stderr.writer().print(
                "moves = {}, moves.len = {}\n",
                .{pos.moves, pos.moves.len},
            );

            engine_data = GlobalData{
               .pos = position.fromFENStruct(pos.fen),
               .best_move = 0,
            };
        },

        UciCommandType.debug => |enabled|
            debug_mode = enabled,

        UciCommandType.setoption => |opt|
            try stderr.writer().print(
                "opt: input = {s}\n",
                .{opt},
            ),
        UciCommandType.quit =>
            return true,
        UciCommandType.ponderhit =>
            return false,
        UciCommandType.go => |options|
            startAnalysis(options),
        UciCommandType.stop =>
            return false,
    }

    return false;
}

fn startNewGame(pos: []const u8) void {
    engine_data = GlobalData{
       .pos = position.fromFEN(start_position) catch unreachable,
       .best_move = 0,
    };
}

fn startAnalysis(options: []GoOption) void {
    var default_search_moves: []const algebraic.LongAlgebraicMove = ([_]algebraic.LongAlgebraicMove{})[0..];
    var opts: AnalysisOptions = .{
        .search_mode = SearchMode.infinite,
        .search_moves = default_search_moves,
        .ponder = false,
        .wtime = 0,
        .btime = 0,
        .winc = 0,
        .binc = 0,
        .movestogo = 0,
        .depth = 0,
        .nodes = 0,
        .moves_to_mate = 0,
        .movetime = 0,
    };

    for (options) |option| {
        switch (option) {
            GoOptionType.infinite =>
                opts.search_mode = SearchMode.infinite,

            GoOptionType.ponder =>
                opts.search_mode = SearchMode.ponder,

            GoOptionType.nodes => |nodes|
                {
                    opts.search_mode = SearchMode.nodes;
                    opts.nodes = nodes;
                },

            GoOptionType.depth => |depth|
                {
                    opts.search_mode = SearchMode.depth;
                    opts.depth = depth;
                },

            GoOptionType.mate => |mate|
                {
                    opts.search_mode = SearchMode.mate;
                    opts.moves_to_mate = mate;
                },

            GoOptionType.movetime => |movetime|
                {
                    opts.search_mode = SearchMode.movetime;
                    opts.movetime = movetime;
                },

            GoOptionType.wtime => |wtime|
                opts.wtime = wtime,

            GoOptionType.btime => |btime|
                opts.btime = btime,
                
            GoOptionType.winc => |winc|
                opts.winc = winc,
                
            GoOptionType.binc => |binc|
                opts.binc = binc,

            GoOptionType.movestogo => |movestogo|
                opts.movestogo = movestogo,

            GoOptionType.searchmoves => |searchmoves|
                opts.search_moves = searchmoves,

        }
    }
}