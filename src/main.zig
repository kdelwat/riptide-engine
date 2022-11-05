const std = @import("std");
const File = std.fs.File;
const TranspositionTable = @import("TranspositionTable.zig").TranspositionTable;
const position = @import("./position.zig");
const evaluate = @import("evaluate.zig");
const PVTable = @import("./pv.zig").PVTable;
const parse_uci = @import("./parse/uci.zig").uci_command;
const uci = @import("./uci.zig");
const make_move = @import("./make_move.zig");
const algebraic = @import("./parse/algebraic.zig");
const UciCommandType = @import("./uci.zig").UciCommandType;
const GoOption = @import("./uci.zig").GoOption;
const EngineOption = @import("./uci.zig").EngineOption;
const GoOptionType = @import("./uci.zig").GoOptionType;
const fen = @import("./parse/fen.zig");
const Move = @import("./move.zig").Move;
const search = @import("./search.zig");
const worker = @import("./worker.zig");
const Allocator = std.mem.Allocator;
const test_allocator = std.testing.allocator;
const Logger = @import("./logger.zig").Logger;
const GameData = @import("GameData.zig").GameData;
const game = @import("GameData.zig");
const builtin = @import("builtin");
const Searcher = @import("search.zig").Searcher;
const Color = @import("color.zig").Color;

const start_position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

// When searching with mode movetime, apply a safety factor to allow clean
// exits and avoid being timed out
const MOVETIME_SAFETY_FACTOR = 0.9;

var game_data: GameData = undefined;
var has_game_data: bool = false;
var game_options: game.GameOptions = game.DEFAULTS;
var searcher: Searcher = undefined;

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
    depth: search.Depth,
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

    if (@import("builtin").os.tag == .windows) {
        line = std.mem.trimRight(u8, line[0..], "\r");
    }

    return line;
}

pub fn main() anyerror!void {
    // Get file descriptors for IO
    const stdin = std.io.getStdIn();

    // Set up allocator with default options
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }

    // Create logger
    const time = std.time.nanoTimestamp();
    const logfile_path: []const u8 = try std.fmt.allocPrint(gpa.allocator(), "/mnt/ext/riptide.{}.txt", .{time});

    const logfile = try std.fs.createFileAbsolute(
        logfile_path,
        .{ .read = true },
    );
    defer logfile.close();

    const logger: Logger = try Logger.initFile(logfile_path);
    defer logger.deinit();

    var quit: bool = false;

    var buffer: [10000]u8 = undefined;

    while (!quit) {
        const input = (try nextLine(stdin.reader(), &buffer)).?;
        try logger.incoming(
            "{s}",
            .{input},
        );

        if (std.mem.eql(u8, input, "quit")) {
            quit = true;
        }

        quit = try handleCommand(input, logger, gpa.allocator());
    }
}

fn handleCommand(input: []const u8, logger: Logger, a: Allocator) !bool {
    const c: uci.UciCommand = (try parse_uci(a, input)).value;

    try switch (c) {
        UciCommandType.uci => {
            try logger.outgoing("id name Riptide", .{});
            try logger.outgoing("id author Cadel Watson", .{});
            try logger.outgoing("option name Hash type spin default 1 min 1 max 256", .{});
            try logger.outgoing("uciok", .{});
        },

        UciCommandType.isready => {
            // Spin until ready
            while (true) {
                if (worker.isReady()) {
                    break;
                }
            }

            try logger.outgoing("readyok", .{});
        },

        UciCommandType.position_startpos => |moves| {
            var p = try position.fromFEN(start_position, a);

            for (moves) |an| {
                var m = Move.fromLongAlgebraic(&p, an);
                //std.debug.print("make move {} {}\n", .{ an, m });
                _ = make_move.makeMove(&p, m);
            }

            try startNewPosition(p, a, logger);
        },

        UciCommandType.ucinewgame => try startNewGame(a),

        UciCommandType.position => |pos| {
            try startNewPosition(position.fromFENStruct(pos.fen), a, logger);
        },

        UciCommandType.debug => |enabled| debug_mode = enabled,
        UciCommandType.setoption => |opt| {
            switch (opt) {
                EngineOption.hash => |hash_size| {
                    game_options.hash_table_size = hash_size;
                },
                EngineOption.threads => |threads| {
                    game_options.threads = threads;
                },
                else => {},
            }
            return false;
        },
        UciCommandType.quit => return true,
        UciCommandType.ponderhit => return false,
        UciCommandType.go => |options| startAnalysis(options, logger, a),
        UciCommandType.stop => stopAnalysis(logger),
    };

    return false;
}

fn startNewGame(a: Allocator) !void {
    if (has_game_data) {
        game_data.deinit();
    }

    game_data = try GameData.init(a, game_options);
}

fn startNewPosition(pos: position.Position, allocator: Allocator, logger: Logger) !void {
    searcher = Searcher.init(pos, &game_data, allocator, logger);
}

fn startAnalysis(options: []GoOption, logger: Logger, _: Allocator) !void {
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
            GoOptionType.infinite => opts.search_mode = SearchMode.infinite,

            GoOptionType.ponder => opts.search_mode = SearchMode.ponder,

            GoOptionType.nodes => |nodes| {
                opts.search_mode = SearchMode.nodes;
                opts.nodes = nodes;
            },

            GoOptionType.depth => |depth| {
                opts.search_mode = SearchMode.depth;
                opts.depth = depth;
            },

            GoOptionType.mate => |mate| {
                opts.search_mode = SearchMode.mate;
                opts.moves_to_mate = mate;
            },

            GoOptionType.movetime => |movetime| {
                opts.search_mode = SearchMode.movetime;
                opts.movetime = movetime;
            },

            GoOptionType.wtime => |wtime| opts.wtime = wtime,

            GoOptionType.btime => |btime| opts.btime = btime,

            GoOptionType.winc => |winc| opts.winc = winc,

            GoOptionType.binc => |binc| opts.binc = binc,

            GoOptionType.movestogo => |movestogo| opts.movestogo = movestogo,

            GoOptionType.searchmoves => |searchmoves| opts.search_moves = searchmoves,
        }

        switch (opts.search_mode) {
            SearchMode.depth => {
                const res = searcher.search(opts.depth, -evaluate.INFINITY, evaluate.INFINITY);
                if (res) |r| {
                    try sendBestMove(r.move, logger);
                } else {
                    try sendBestMove(null, logger);
                }
            },
            SearchMode.mate => {},
            SearchMode.ponder => {},
            SearchMode.movetime => {
                var then = std.time.milliTimestamp();
                _ = try worker.start(&searcher);
                std.time.sleep(@floatToInt(u64, @intToFloat(f64, opts.movetime * std.time.ns_per_ms) * MOVETIME_SAFETY_FACTOR));
                try stopAnalysis(logger);
                var now = std.time.milliTimestamp();
                try logger.log("main", "Elapsed: {}ms\n", .{now - then});
            },
            SearchMode.nodes => {},
            SearchMode.infinite => {
                _ = try worker.start(&searcher);
            },
        }
    }
}

fn stopAnalysis(logger: Logger) !void {
    try worker.stop();

    // Send the best move found so far
    try sendBestMove(searcher.getBestMove(), logger);
}

fn sendBestMove(opt_m: ?Move, logger: Logger) !void {
    if (opt_m) |m| {
        var buf: [5]u8 = [_]u8{ 0, 0, 0, 0, 0 };
        try m.toLongAlgebraic(buf[0..]);
        if (buf[4] == 0) {
            try logger.outgoing("bestmove {s}", .{buf[0..4]});
        } else {
            try logger.outgoing("bestmove {s}", .{buf});
        }
    } else {
        try logger.log("MAIN", "null move returned from search", .{});
    }
}
