const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const glfw_dep = b.dependency("mach-glfw", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));

    const options = .{ .api = .gl, .version = .@"3.3", .profile = .core };
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, options);
    exe.root_module.addImport("gl", gl_bindings);

    const zstbi = b.dependency("zstbi", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zstbi", zstbi.module("root"));
    exe.linkLibrary(zstbi.artifact("zstbi"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
