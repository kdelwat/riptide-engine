const std = @import("std");
usingnamespace @import("mecha");

pub const UciCommandType = enum {
    uci,
    isready,
    position_startpos,
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
    ucinewgame: UciCommandUciNewGame,
};

// toUnionStruct is based on toStruct from mecha, but takes in a union tag name and converts the parse result
// into the struct type corresponding to that tag. It also supports void parsers, by creating an empty struct.
fn ToUnionStructResult(comptime T: type) type {
    return @TypeOf(struct {
        fn func(tuple: anytype) T {
            return undefined;
        }
    }.func);
}

pub fn toUnionStruct(name: []const u8, comptime T: type) ToUnionStructResult(T) {
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

            var res: T = undefined;
            if (@TypeOf(tuple) == void) {
                return @unionInit(UciCommand, name, .{});
            }

            res = @unionInit(UciCommand, name, .{});
            if (struct_fields.len != tuple.len)
                @compileError(@typeName(T) ++ " and " ++ @typeName(@TypeOf(tuple)) ++ " does not have " ++
                    "same number of fields. Conversion is not possible.");

            inline for (struct_fields) |field, i|
                @field(res, field.name) = tuple[i];

            return res;
        }
    }.func;
}

const p_uci = map(UciCommand, toUnionStruct("uci", UciCommand), string("uci"));
const p_isready = map(UciCommand, toUnionStruct("isready", UciCommand), string("isready"));
const p_position_startpos = map(UciCommand, toUnionStruct("position_startpos", UciCommand), string("position startpos"));
const p_ucinewgame = map(UciCommand, toUnionStruct("ucinewgame", UciCommand), string("ucinewgame"));

pub const uci_command = combine(.{oneOf(.{ p_isready, p_position_startpos, p_ucinewgame, p_uci})});