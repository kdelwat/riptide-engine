const m = @import("mecha");
const utf8 = m.utf8;

pub const Fen = struct {
    board: []const u8,
    to_move: []const u8,
    castling: []const u8,
    en_passant: []const u8,
    halfmove: u64,
    fullmove: u64,
};

pub const fen = m.map(Fen, m.toStruct(Fen), m.combine(.{
    board,
    space,
    to_move,
    space,
    castling,
    space,
    en_passant,
    space,
    m.int(u64, .{ .base = 10 }),
    space,
    m.int(u64, .{ .base = 10 }),
}));

const board = m.asStr(m.combine(.{ rank, slash, rank, slash, rank, slash, rank, slash, rank, slash, rank, slash, rank, slash, rank }));

const rank = m.many(board_char, .{ .min = 1, .max = 8, .collect = false });
const slash = utf8.char('/');

const board_char = m.oneOf(.{
    m.discard(utf8.range('1', '8')),
    utf8.char('r'),
    utf8.char('n'),
    utf8.char('b'),
    utf8.char('q'),
    utf8.char('k'),
    utf8.char('p'),
    utf8.char('R'),
    utf8.char('N'),
    utf8.char('B'),
    utf8.char('Q'),
    utf8.char('K'),
    utf8.char('P'),
});

const to_move = m.asStr(m.oneOf(.{
    utf8.char('w'),
    utf8.char('b'),
}));

const castling = m.many(castle_char, .{ .min = 1, .max = 4, .collect = false });

const castle_char = m.oneOf(.{
    utf8.char('Q'),
    utf8.char('K'),
    utf8.char('q'),
    utf8.char('k'),
    utf8.char('-'),
});

const en_passant = m.oneOf(.{
    m.asStr(utf8.char('-')),
    m.asStr(m.combine(.{ utf8.range('a', 'h'), utf8.range('1', '8') })),
});

const space = m.discard(utf8.char(' '));

//pub const Fen = struct {
//    board: []const u8,
//    to_move: []const u8,
//    castling: []const u8,
//    en_passant: []const u8,
//    halfmove: u64,
//    fullmove: u64,
//};
//
//pub const fen = map(Fen, toStruct(Fen),
//    m.combine(.{
//        board, // []const u8
//        space, // void
//        to_move, // []const u8
//        space, // void
//        castling, // []const u8
//        space, // void
//        en_passant, // []const u8
//        space,
//        int(u64, 10),
//        space,
//        int(u64, 10)
//}));
//
//const space= discard(utf8.char(' '));
//
//const board = asStr(m.combine(.{rank, slash, rank, slash, rank, slash, rank, slash, rank, slash, rank, slash, rank, slash, rank}));
//
//// []u21
//const rank = many(board_char, .{.min = 1, .max = 8});
//
//const board_char = oneOf(.{
//    utf8.range('1', '8'),
//    utf8.char('r'),
//    utf8.char('n'),
//    utf8.char('b'),
//    utf8.char('q'),
//    utf8.char('k'),
//    utf8.char('p'),
//    utf8.char('R'),
//    utf8.char('N'),
//    utf8.char('B'),
//    utf8.char('Q'),
//    utf8.char('K'),
//    utf8.char('P'),
//});
//
//const slash = discard(utf8.char('/'));
//
//const castling = asStr(many(castle_char, .{.min = 1, .max = 4}));
//
//const castle_char = oneOf(.{
//    utf8.char('Q'),
//    utf8.char('K'),
//    utf8.char('q'),
//    utf8.char('k'),
//    utf8.char('-'),
//});
//
//const to_move = asStr(oneOf(.{
//    utf8.char('w'),
//    utf8.char('b'),
//}));
//
//const en_passant = asStr(oneOf(.{
//    utf8.char('-'),
//    m.combine(.{utf8.range('a', 'h'), utf8.range('1','8')}),
//}));
