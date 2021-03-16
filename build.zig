const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("riptide", "src/main.zig");

    exe.addPackage(.{
        .name = "mecha",
        .path = "libs/mecha/mecha.zig",
    });

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_files: [5][]const u8 = [_][]const u8{
        "src/attack_test.zig",
        "src/evaluate_test.zig",
        "src/make_move_test.zig",
        "src/movegen_test.zig",
        "src/position_test.zig"
    };

    const test_step = b.step("test", "Run all tests");

    for (test_files) |test_file| {
        const test_target = b.addTest(test_file);
        test_target.addPackage(.{
            .name = "mecha",
            .path = "libs/mecha/mecha.zig",
        });
        test_step.dependOn(&test_target.step);
    }

    const perft_test_target = b.addTest("src/perft_test.zig");
    perft_test_target.addPackage(.{
        .name = "mecha",
        .path = "libs/mecha/mecha.zig",
    });
    const perft_test_step = b.step("perft", "Run perft move generation tests (slow)");
    perft_test_step.dependOn(&perft_test_target.step);

}
