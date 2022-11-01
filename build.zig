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

    exe.addPackagePath("mecha", "libs/mecha/mecha.zig");
    exe.addPackagePath("position", "src/position.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.use_stage1 = true;

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_files: [7][]const u8 = [_][]const u8{
        "src/move_test.zig",
        "src/movegen_test.zig",
        "src/attack_test.zig",
        "src/position_test.zig",
        "src/evaluate_test.zig",
        "src/make_move_test.zig",
        "src/transposition/zobrist_test.zig",
    };

    const test_step = b.step("test", "Run all tests");

    for (test_files) |test_file| {
        const test_target = b.addTest(test_file);
        test_target.use_stage1 = true;
        test_target.addPackagePath("mecha", "libs/mecha/mecha.zig");
        test_target.addPackagePath("position", "src/position.zig");
        test_step.dependOn(&test_target.step);
    }

    const perft_test_target = b.addTest("src/perft_test.zig");
    perft_test_target.use_stage1 = true;
    perft_test_target.addPackagePath("mecha", "libs/mecha/mecha.zig");
    const perft_test_step = b.step("perft", "Run perft move generation tests (slow)");
    perft_test_step.dependOn(&perft_test_target.step);

    const nps_test_target = b.addTest("src/nps_test.zig");
    nps_test_target.use_stage1 = true;
    nps_test_target.addPackagePath("mecha", "libs/mecha/mecha.zig");
    const nps_test_step = b.step("nps", "Run nodes per second benchmark");
    nps_test_step.dependOn(&nps_test_target.step);
}
