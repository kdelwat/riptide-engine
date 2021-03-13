const std = @import("std");
const File = std.fs.File;
const position = @import("./position.zig");

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
};

// Store the global options set via Universal Chess Interface commands for the
// engine to follow during runtime.
const AnalysisOptions = struct {
    search_mode: SearchMode,

    // searchMoves is a list of moves to consider when searching, to the exclusion of others
    searchMoves: []u32,

    // ponder places the engine in ponder mode, which searches for the next move during
    // the opponent's turn.
    ponder: bool,

    // wtime and btime control the amount of time each player has in the game. winc and
    // binc determine the time increment added to each player after each move.
    wtime: i64,
    btime: i64,
    winc: i64,
    binc: i64,

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

        try handleCommand(input, stdout, stderr);
    }
}

fn handleCommand(input: []const u8, stdout: File, stderr: File) !void {
    if (std.mem.eql(u8, input, "uci")) {
        try stdout.writer().print(
            "id name Riptide\nid author Cadel Watson\nuciok\n",
            .{},
        );
    } else if (std.mem.eql(u8, input, "isready")) {
        try stdout.writer().print(
            "readyok\n",
            .{},
        );
    } else if (std.mem.eql(u8, input, "ucinewgame")) {
        engine_data = GlobalData{
            .pos = position.fromFEN(start_position),
            .best_move = 0,
        };
        try stdout.writer().print(
            "isready\n",
            .{},
        );
    } else if (std.mem.eql(u8, input[0..8], "position")) {
        var end_of_first_arg: usize = 0;
        for (input[9..]) |c, i| {
            try stderr.writer().print(
                "c: {c}, i: {}\n",
                .{c, i},
            );

            if (c == ' ') {
                end_of_first_arg = i - 1;
                break;
            }
        }

        if (end_of_first_arg == 0) {
            end_of_first_arg = input.len - 2;
        }

        try stderr.writer().print(
            "end_of_first_arg: {}\n",
            .{end_of_first_arg},
        );

        if (std.mem.eql(u8, input[9..end_of_first_arg], "startpos")) {
            engine_data = GlobalData{
                .pos = position.fromFEN(start_position),
                .best_move = 0,
            };
        } else {
            var end_of_fen: usize = 0;
            var fen_spaces_remaining: u8 = 6;

            for (input[end_of_first_arg + 1..]) |c, i| {
                if (c == ' ') {
                    fen_spaces_remaining -= 1;
                    if (fen_spaces_remaining == 0) {
                        end_of_fen = i - 1;
                        break;
                    }
                }
            }

            engine_data = GlobalData{
                .pos = position.fromFEN(input[end_of_first_arg + 1..end_of_fen]),
                .best_move = 0,
            };
        }
    }
}
