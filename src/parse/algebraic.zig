const m = @import("mecha");
const utf8 = m.utf8;

pub const LongAlgebraicMove = struct {
    from: []const u8,
    to: []const u8,
    promotion: ?[]const u8,
};

pub const long_algebraic_notation = m.map(LongAlgebraicMove, m.toStruct(LongAlgebraicMove), long_algebraic);

const rank = m.discard(utf8.range('1', '8'));
const file = m.discard(utf8.range('a', 'f'));
const pos = m.asStr(m.combine(.{ file, rank }));
const promo = m.asStr(m.oneOf(.{
    utf8.char('r'),
    utf8.char('n'),
    utf8.char('b'),
    utf8.char('q'),
    utf8.char('k'),
    utf8.char('p'),
}));

const long_algebraic = m.combine(.{ pos, pos, m.opt(promo), m.discard(m.opt(utf8.char(' '))) });
