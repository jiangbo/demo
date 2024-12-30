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

    // exe.subsystem = .Windows;
    b.installArtifact(exe);

    const win32 = b.dependency("zigwin32", .{});
    exe.root_module.addImport("win32", win32.module("zigwin32"));

    const dir = "C:/software/Microsoft DirectX SDK (June 2010)/";
    // exe.addIncludePath(.{ .cwd_relative = dir ++ "Include" });
    exe.addObjectFile(.{ .cwd_relative = dir ++ "lib/x64/d3dx10.lib" });
    exe.addObjectFile(.{ .cwd_relative = dir ++ "lib/x64/d3dx10d.lib" });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
