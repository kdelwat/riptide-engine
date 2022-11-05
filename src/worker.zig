const std = @import("std");
const position = @import("./position.zig");
const search = @import("./search.zig");
const File = std.fs.File;
const Allocator = std.mem.Allocator;
const Logger = @import("./logger.zig").Logger;
const Move = @import("./move.zig").Move;
const TranspositionTable = @import("./TranspositionTable.zig").TranspositionTable;

// Search must run off the main thread, otherwise it will block UCI commands like
// `stop`.

const WorkerThreadStatus = enum {
    running,
    closing,
    not_running,
};

var status: WorkerThreadStatus = WorkerThreadStatus.not_running;
var thread: ?std.Thread = null;

var thread_searcher: ?*search.Searcher = null;

const WorkerError = error{
    WorkerAlreadyRunning,
};

// Spawn the worker thread, or return an error if it has already been started
pub fn start(s: *search.Searcher) !void {
    if (status != WorkerThreadStatus.not_running) {
        return WorkerError.WorkerAlreadyRunning;
    }

    thread_searcher = s;
    thread = try std.Thread.spawn(.{}, run, .{});
}

// Entrypoint for worker
fn run() !void {
    if (thread_searcher) |s| {
        try s.searchInfinite();
    }
}

// Stop the worker and block until it finishes
pub fn stop() !void {
    status = WorkerThreadStatus.closing;
    if (thread_searcher) |s| {
        s.cancel();
    }

    if (thread) |t| {
        t.join();
        status = WorkerThreadStatus.not_running;
    }
}

pub fn isReady() bool {
    return status == WorkerThreadStatus.not_running;
}
