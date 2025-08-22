const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // EPANET is a C library, so we need to link against the C standard library.
    const flags = [_][]const u8{
        "-std=c99",
        "-lm",
        "-I.",
        "-fPIC",
        switch (target.result.os.tag) {
            .macos => switch (target.result.cpu.arch) {
                .x86_64 => "--target=x86_64-apple-macos11",
                .aarch64 => "--target=arm64-apple-macos11",
                else => std.debug.panic("Unsuported target CPU architecture for MAC: {}", .{target.result.cpu.arch}),
            },
            .linux => switch (target.result.cpu.arch) {
                .x86_64 => "--target=x86_64-unknown-linux-gnu",
                .aarch64 => "--target=aarch64-unknown-linux-gnu",
                else => std.debug.panic("Unsuported target CPU architecture for Linux: {}", .{target.result.cpu.arch}),
            },
            .windows => "--target=x86_64-pc-windows-msvc",
            // error
            else => std.debug.panic("Unsuported target OS: {}", .{target.result.os.tag}),
        },
    };

    const mod = b.addModule("zepanet", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
    });

    for (epanet_source_files) |s| {
        mod.addCSourceFile(.{
            .file = b.path(s),
            .flags = &flags,
            .language = .c,
        });
    }
    mod.addIncludePath(b.path("epanetsrc"));

    const exe = b.addExecutable(.{
        .name = "zepanet",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zepanet", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the zepanet executable");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

const epanet_source_files = [_][]const u8{
    "epanetsrc/hash.c",
    "epanetsrc/epanet.c",
    "epanetsrc/epanet2.c",
    "epanetsrc/genmmd.c",
    "epanetsrc/hydcoeffs.c",
    "epanetsrc/hydraul.c",
    "epanetsrc/hydsolver.c",
    "epanetsrc/hydstatus.c",
    "epanetsrc/inpfile.c",
    "epanetsrc/input1.c",
    "epanetsrc/input2.c",
    "epanetsrc/input3.c",
    // "epanetsrc/main.c",
    "epanetsrc/mempool.c",
    "epanetsrc/output.c",
    "epanetsrc/project.c",
    "epanetsrc/qualreact.c",
    "epanetsrc/qualroute.c",
    "epanetsrc/quality.c",
    "epanetsrc/report.c",
    "epanetsrc/rules.c",
    "epanetsrc/smatrix.c",
};
