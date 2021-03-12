const std = @import("std");
const expect = std.testing.expect;

const position = @import("./position.zig");
const movegen = @import("./movegen.zig");
const isKingInCheck = movegen.isKingInCheck;

test "isKingInCheck - bug" {
    const pos = position.fromFEN("5RKb/4P1n1/2p4p/3p2p1/3B2Q1/5B2/r6k/4r3 w - - 0 1");

    expect(!isKingInCheck(pos));
}