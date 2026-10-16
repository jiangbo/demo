const std = @import("std");
const zhuBuild = @import("zhuyu");
const sk = zhuBuild.sokol;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const android = target.result.abi.isAndroid();

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
    });
    const migu = b.dependency("migu", .{
        .target = target,
        .optimize = optimize,
    });

    // 应用模块同时用于构建产物和测试。
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ecs", .module = migu.module("ecs") },
            .{ .name = "zhu", .module = zhuyu.module("zhu") },
        },
    });

    // SDK 安装命令不依赖目标平台，与 Web 链接共用同一份依赖。
    const sokol = zhuyu.builder.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const emsdk = sokol.builder.dependency("emsdk", .{});
    const installEmsdk = sk.emSdkInstallStep(b, emsdk, .{});
    b.step("install-emsdk", "Install Emscripten SDK").dependOn(installEmsdk);

    if (android) {
        const ndk = b.option([]const u8, "ndk", "Android NDK directory");
        const lib = try zhuBuild.buildAndroid(b, zhuyu, .{
            .name = "demo",
            .root_module = mod,
            .ndk = ndk orelse @panic("Pass -Dndk=<Android NDK directory>"),
        });
        b.installArtifact(lib);
    } else if (target.result.os.tag == .emscripten) {
        try buildWeb(b, mod, emsdk);
    } else {
        buildNative(b, mod);
    }

    const tests = b.addTest(.{ .name = "tests", .root_module = mod });
    const runTests = b.addRunArtifact(tests);
    b.step("test", "Run tests").dependOn(&runTests.step);
}

// 构建原生应用，安装产物并提供运行命令。
fn buildNative(b: *std.Build, mod: *std.Build.Module) void {
    const exe = b.addExecutable(.{ .name = "demo", .root_module = mod });
    // Windows 所有构建模式都使用窗口子系统，不创建控制台窗口。
    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.subsystem = .windows;
    }
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the app").dependOn(&run.step);
}

// 构建 Web 静态库，再交给 Emscripten 链接和安装。
fn buildWeb(
    b: *std.Build,
    mod: *std.Build.Module,
    emsdk: *std.Build.Dependency,
) !void {
    const lib = b.addLibrary(.{ .name = "demo", .root_module = mod });
    const link = try sk.emLinkStep(b, .{
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
        .lib_main = lib,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        // TODO: Zig 修复 std.Io 未使用函数保留问题后，确认 Web 的 Debug 和
        // ReleaseSafe 在 false 下均可链接并正常运行，再关闭文件系统。
        // https://codeberg.org/ziglang/zig/issues/31421
        .use_filesystem = true,
        .shell_file_path = b.path("index.html"),
    });
    b.getInstallStep().dependOn(&link.step);

    // Web 资源随 HTML 一起安装；原生运行直接读取项目目录。
    b.installDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .prefix,
        .install_subdir = "web/assets",
    });
}
