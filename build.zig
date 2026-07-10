const std = @import("std");
const zhuBuild = @import("zhuyu");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
    });
    const zhuModule = zhuyu.module("zhu");

    const imports = [_]std.Build.Module.Import{
        .{ .name = "zhu", .module = zhuModule },
    };

    var emLink = zhuBuild.defaultEmLinkOptions;
    emLink.use_webgl2 = true;
    emLink.use_emmalloc = true;
    emLink.use_filesystem = true;
    emLink.shell_file_path = b.path("index.html");
    emLink.extra_args = &.{"-sINITIAL_MEMORY=64MB"};

    // Sunny 是当前迁移目标。
    _ = try zhuBuild.addApp(b, .{
        .name = "demo",
        .root_source_file = b.path("shooter/main.zig"),
        .target = target,
        .optimize = optimize,
        .zhuyu = zhuyu,
        .imports = &imports,
        .em_link = emLink,
    });

    const testModule = b.createModule(.{
        .root_source_file = b.path("shooter/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &imports,
    });

    const tests = b.addTest(.{
        .name = "tests",
        .root_module = testModule,
    });
    const runTests = b.addRunArtifact(tests);
    b.step("test", "Run sunny tests").dependOn(&runTests.step);
}
