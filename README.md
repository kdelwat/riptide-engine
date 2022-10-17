# Riptide

Riptide is a UCI-compatible chess engine and the successor to [ChessSlayer](https://github.com/kdelwat/chess). It
started as a straight port of ChessSlayer from Go to Zig, but is becoming a more performant and advanced engine over
time.

## Features

* Board representation: bitboard
* Move generation: pseudo-legal generation followed by legality check. 100% correct on Perft tests.
* Search: negamax with alpha-beta pruning

## UCI compatibility

Riptide requires a UCI client to use as the frontend during games. It's tested against
[Scid vs. PC](https://sourceforge.net/projects/scidvspc/); your mileage may vary with other clients.

Currently, the following UCI features are unimplemented:

* specifying a list of moves when using the `position` command
* the `nodes`, `movestogo`, and `mate` arguments to the `go` command
* ponder mode

## Installation

1. Install [Zig](https://ziglang.org/) version 0.10.
2. Clone the repository with `git clone --recurse-submodules https://github.com/kdelwat/riptide-engine.git`
3. Run `cd riptide-engine && zig build`
4. The `riptide` binary will be created in `zig-cache/bin`; point your GUI client to this binary.

## Tests

Run unit tests with:

```
zig build test
```

Run [perft](https://www.chessprogramming.org/Perft) correctness tests with:

```
zig build perft
```

Run node-per-second benchmarks with:

```
zig build nps
```

## Profiling

```
zig build
valgrind --tool=callgrind zig-cache/bin/riptide
ucinewgame
position startpos
go infinite
```

Then run `kcachegrind` to analyse.

## Credits

I couldn't have written this engine without the invaluable help of the 
[Chess programming wiki](https://www.chessprogramming.org/Main_Page) and the
[Mediocre chess blog](https://mediocrechess.blogspot.com/) by Jonatan Pettersson.

