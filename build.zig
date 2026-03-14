const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("geomath", .{
        .root_source_file = b.path("src/shape_mesher.zig"),
        .target = target,
    });

    const bench_mod = b.addModule("test", .{
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const exe = b.addExecutable(.{
        .name = "geomath",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "geomath", .module = mod },
            },
            .strip = false,
            // .omit_frame_pointer = false,
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);

    const mod_test = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_test = b.addRunArtifact(mod_test);

    const bench_test = b.addTest(.{
        .root_module = bench_mod,
    });
    const run_bench = b.addRunArtifact(bench_test);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_test.step);

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
