pub const Color = enum(u1) {
    white = 0,
    black = 1,
};

pub fn invert(c: Color) Color {
    return switch (c) {
        Color.white => Color.black,
        Color.black => Color.white,
    };
}

pub const ALL_COLORS: [2]Color = .{ .white, .black };
