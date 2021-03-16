const std = @import("std");

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
                return @unionInit(T, name, .{});
            }

            return @unionInit(T, name, tuple);
        }
    }.func;
}
