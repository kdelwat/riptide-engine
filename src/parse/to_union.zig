const std = @import("std");

// toUnion is based on toStruct from mecha, but takes in a union tag name and converts the parse result
// into a union.
fn ToUnionResult(comptime T: type) type {
    return @TypeOf(struct {
        fn func(_: anytype) T {
            return undefined;
        }
    }.func);
}

pub fn toUnion(name: []const u8, comptime T: type) ToUnionResult(T) {
    return struct {
        fn func(tuple: anytype) T {
            if (@TypeOf(tuple) == void) {
                return @unionInit(T, name, .{});
            }

            return @unionInit(T, name, tuple);
        }
    }.func;
}
