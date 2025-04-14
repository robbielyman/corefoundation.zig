const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const corefoundation = b.addModule("corefoundation", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
    });

    const tests = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
    });

    const objz = b.dependency("objz", .{
        .target = target,
        .optimize = optimize,
    });
    corefoundation.addImport("objz", objz.module("objz"));
    tests.root_module.addImport("objz", objz.module("objz"));
    tests.linkFramework("CoreFoundation");
    corefoundation.linkFramework("CoreFoundation", .{});
    tests.linkFramework("Foundation");
    corefoundation.linkFramework("Foundation", .{});

    const run = b.addRunArtifact(tests);
    const tests_run = b.step("test", "run the tests");
    tests_run.dependOn(&run.step);
}
