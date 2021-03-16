const std = @import("std");
usingnamespace @import("mecha");
const Fen = @import("./fen.zig").Fen;
const fen = @import("./fen.zig").fen;

pub const UciCommandType = enum {
    uci,
    isready,
    position_startpos,
    position, // TODO: moves
    ucinewgame,
    debug,
    setoption,
    // go
    // stop
    quit,
    // ponderhit

};

pub const UciCommand = union(UciCommandType) {
    uci: void,
    isready: void,
    position_startpos: void,
    position: Fen,
    ucinewgame: void,
    debug: bool,
    setoption: []const u8,
    quit: void,
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

            if (@TypeOf(tuple) == void) {
                return @unionInit(UciCommand, name, .{});
            }

            return @unionInit(UciCommand, name, tuple);
        }
    }.func;
}

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

const p_uci = map(UciCommand, toUnion("uci", UciCommand), string("uci"));
const p_isready = map(UciCommand, toUnion("isready", UciCommand), string("isready"));
const p_position = map(UciCommand, toUnion("position", UciCommand), combine(.{string("position "), fen}));
const p_position_startpos = map(UciCommand, toUnion("position_startpos", UciCommand), string("position startpos"));
const p_ucinewgame = map(UciCommand, toUnion("ucinewgame", UciCommand), string("ucinewgame"));
const p_debug = map(UciCommand, toUnion("debug", UciCommand), combine(.{string("debug "), boolean}));
const p_setoption = map(UciCommand, toUnion("setoption", UciCommand), combine(.{string("setoption "), set_option}));
const p_quit = map(UciCommand, toUnion("quit", UciCommand), string("quit"));

const boolean = oneOf(.{parse_on, parse_off});
const parse_on = map(bool, struct {fn f(_: anytype) bool {return true;}}.f, string("on"));
const parse_off = map(bool, struct {fn f(_: anytype) bool {return false;}}.f, string("off"));

const any_char = oneOf(.{discard(utf8.range('0', '9')), discard(utf8.range('a', 'z')), discard(utf8.range('A', 'Z')), utf8.char(' ')});

const set_option = combine(
    .{
        string("name "),
        asStr(many(any_char, .{.collect = false}))
    }
);

const p: ParserResult(u8) = asStr(many(any_char, .{.collect = false}));