usingnamespace @import("mecha");

pub const LongAlgebraicMove = struct {
    from: []const u8,
    to: []const u8,
    promotion: ?[]const u8,
};

pub const long_algebraic_notation = map(LongAlgebraicMove, toStruct(LongAlgebraicMove), long_algebraic);

const rank = discard(utf8.range('1', '8'));
const file = discard(utf8.range('a', 'f'));
const pos = asStr(combine(.{file, rank}));
const promo = asStr(oneOf(.{
    utf8.char('r'),
    utf8.char('n'),
    utf8.char('b'),
    utf8.char('q'),
    utf8.char('k'),
    utf8.char('p'),
}));

const long_algebraic = combine(.{pos, pos, opt(promo), discard(opt(utf8.char(' ')))});