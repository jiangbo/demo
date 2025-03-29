const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (optimize != .Debug) exe.subsystem = .Windows;

    b.installArtifact(exe);

    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("sokol", sokol.module("sokol"));

    const writeFiles = b.addWriteFiles();
    exe.step.dependOn(&writeFiles.step);

    // const stb = b.dependency("stb", .{ .target = target, .optimize = optimize });
    // exe.root_module.addIncludePath(stb.path("."));
    // const stbImagePath = writeFiles.add("stb_image.c", stbImageSource);
    // exe.root_module.addCSourceFile(.{ .file = stbImagePath, .flags = &.{"-O3"} });

    const zstbi = b.dependency("zstbi", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("stbi", zstbi.module("root"));

    const zaudio = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zaudio", zaudio.module("root"));
    exe.linkLibrary(zaudio.artifact("miniaudio"));

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const stbImageSource =
    \\
    \\#define STB_IMAGE_IMPLEMENTATION
    \\#include "stb_image.h"
    \\
;
