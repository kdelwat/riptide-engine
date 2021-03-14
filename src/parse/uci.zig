const std = @import("std");
usingnamespace @import("mecha");
const Fen = @import("./fen.zig").Fen;
const fen = @import("./fen.zig").fen;

pub const UciCommandType = enum {
    uci,
    isready,
    position_startpos,
    position,
    ucinewgame,
};

const UciCommandUci = struct {};
const UciCommandVoid = struct {};
const UciCommandPositionStartpos = struct {};
const UciCommandUciNewGame = struct {};

pub const UciCommand = union(UciCommandType) {
    uci: UciCommandUci,
    isready: UciCommandVoid,
    position_startpos: UciCommandPositionStartpos,
    position: Fen,
    ucinewgame: UciCommandUciNewGame,
};

// toUnion is based on toStruct from mecha, but takes in a union tag name and converts the parse result
// into a union.
fn ToUnionResult(comptime T: type) type {
    return @TypeOf(struct {
        fn func(tuple: anytype) T {
            return undefined;
        }
    }.func);
}

pub fn toUnion(name: []const u8, comptime T: type) ToUnionResult(T) {
    return struct {
        fn func(tuple: anytype) T {
            const union_fields = @typeInfo(T).Union.fields;
            const struct_type = comptime for (union_fields) |union_field| {
                if (std.mem.eql(u8, union_field.name, name)) {
                    break union_field.field_type;
                }
            } else {
                @compileError("union does not have field " ++ name);
            };


            const struct_fields = @typeInfo(struct_type).Struct.fields;

            if (@TypeOf(tuple) == void) {
                return @unionInit(UciCommand, name, .{});
            }

            return @unionInit(UciCommand, name, tuple);
        }
    }.func;
}

const p_uci = map(UciCommand, toUnion("uci", UciCommand), string("uci"));
const p_isready = map(UciCommand, toUnion("isready", UciCommand), string("isready"));
const p_position = map(UciCommand, toUnion("position", UciCommand), combine(.{string("position "), fen}));
const p_position_startpos = map(UciCommand, toUnion("position_startpos", UciCommand), string("position startpos"));
const p_ucinewgame = map(UciCommand, toUnion("ucinewgame", UciCommand), string("ucinewgame"));

pub const uci_command = combine(.{oneOf(.{ p_isready, p_position, p_position_startpos, p_ucinewgame, p_uci})});