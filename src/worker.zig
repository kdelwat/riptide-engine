const std = @import("std");
const position = @import("./position.zig");
const search = @import("./search.zig");
const File = std.fs.File;
const Allocator = std.mem.Allocator;
const Logger = @import("./logger.zig").Logger;

// Search must run off the main thread, otherwise it will block UCI commands like
// `stop`.

const WorkerThreadStatus = enum {
    running,
    closing,
    not_running,
};

var status: WorkerThreadStatus = WorkerThreadStatus.not_running;
var thread: ?*std.Thread = null;

// Used to signal to the search thread that it should exit
var cancel_search: bool = false;

const WorkerError = error {
    WorkerAlreadyRunning,
};

// Spawn the worker thread, or return an error if it has already been started
pub fn start(pos: *position.Position, best_move: *u32, logger: Logger, a: *Allocator) !void {
    if (status != WorkerThreadStatus.not_running) {
        return WorkerError.WorkerAlreadyRunning;
    }

    const ctx = search.InfiniteSearchContext{
        .pos = pos,
        .best_move = best_move,
        .thread_ctx = search.SearchContext{
            .cancelled = &cancel_search,
            .a = a,
            .logger = logger,
        },
    };

    thread = try std.Thread.spawn(ctx, search.searchInfinite);
}

// Stop the worker and block until it finishes
pub fn stop() !void {
    status = WorkerThreadStatus.closing;
    cancel_search = true;
    if (thread) |t| {
        t.wait();
        status = WorkerThreadStatus.not_running;
        cancel_search = false;
    }
}

pub fn isReady() bool {
    return status == WorkerThreadStatus.not_running;
}
