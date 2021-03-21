const std = @import("std");
const expect = std.testing.expect;

const position = @import("./position.zig");
const movegen = @import("./movegen.zig");
const isKingInCheck = movegen.isKingInCheck;
const attack = @import("./attack.zig");
const Color = @import("./color.zig").Color;

test "isKingInCheck - bug" {
    var pos: position.Position = position.fromFEN("5RKb/4P1n1/2p4p/3p2p1/3B2Q1/5B2/r6k/4r3 w - - 0 1") catch unreachable;
    pos.board.debug();
    const attack_map = attack.generateAttackMap(&pos, Color.black);

    std.debug.print("attacks: {b}\n", .{attack_map});

    expect(!isKingInCheck(pos, Color.white, attack_map));
}