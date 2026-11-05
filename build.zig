const std = @import("std");
const zhuBuild = @import("zhuyu");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const android = target.result.abi.isAndroid();

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
        .font = .system,
        .midi = true,
        .append = b.option(bool, "append", "Append asset pack") orelse false,
    });
    const migu = b.dependency("migu", .{
        .target = target,
        .optimize = optimize,
    });

    // 生成图片图集，尺寸上限容纳地图素材。
    zhuBuild.atlas.addStep(b, zhuyu, .{
        .input = "raw-assets/atlas",
        .maxSize = 2048,
    });

    // 转换原始音频并统一采样率，其他格式原样拷贝。
    try zhuBuild.audio.addStep(b, zhuyu, .{
        .input = "raw-assets/audio",
        .rate = 11025,
    });

    // 应用模块同时用于构建产物和测试。
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // 所有平台仅 Debug 保留调试符号。
        .strip = optimize != .debug,
        .imports = &.{
            .{ .name = "ecs", .module = migu.module("ecs") },
            .{ .name = "zhu", .module = zhuyu.module("zhu") },
        },
    });

    // SDK 安装命令不依赖目标平台，与 Web 链接共用同一份依赖。
    zhuBuild.installEmsdk(b, zhuyu);

    // 原生和 Web 共用图片复制步骤，在资源安装前执行。
    const copy = b.addUpdateSourceFiles();
    copy.addCopyFileToSource(b.path("raw-assets/icon.png"), "assets/icon.png");
    copy.addCopyFileToSource(b.path("raw-assets/title.png"), "assets/title.png");

    if (android) {
        const lib = try zhuBuild.buildAndroid(b, zhuyu, .{
            .name = "demo",
            .root_module = mod,
        });
        b.installArtifact(lib);
        // Android 使用从 ICO 提取并补齐留白的专用图标。
        try zhuBuild.apk.addStep(b, zhuyu, .{
            .lib = lib,
            .app = .{
                .package = "com.example.demo",
                .label = "英雄救美",
                .icon = b.path("raw-assets/icon-android.png"),
                .iconColor = "#FFEEBB",
            },
        });
    } else if (target.result.os.tag == .emscripten) {
        const web = try zhuBuild.buildWeb(b, zhuyu, .{
            .name = "demo",
            .root_module = mod,
            .shell = b.path("index.html"),
        });
        b.getInstallStep().dependOn(&web.step);

        // Web 资源随 HTML 一起安装，读取目录前先完成图片复制。
        const assets = b.addInstallDirectory(.{
            .source_dir = b.path("assets"),
            .install_dir = .prefix,
            .install_subdir = "web/assets",
        });
        assets.step.dependOn(&copy.step);
        b.getInstallStep().dependOn(&assets.step);
    } else {
        buildNative(b, zhuyu, mod, &copy.step);
    }

    const tests = b.addTest(.{ .name = "tests", .root_module = mod });
    zhuBuild.setLibC(zhuyu, tests);
    const runTests = b.addRunArtifact(tests);
    b.step("test", "Run tests").dependOn(&runTests.step);
}

// 构建原生应用，安装产物并提供运行命令。
fn buildNative(
    b: *std.Build,
    zhuyu: *std.Build.Dependency,
    mod: *std.Build.Module,
    copy: *std.Build.Step,
) void {
    const exe = b.addExecutable(.{ .name = "demo", .root_module = mod });
    zhuBuild.setLibC(zhuyu, exe);
    // Windows 调试时显示控制台日志，发布时不创建控制台窗口。
    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.subsystem = if (mod.optimize.? == .debug) .console else .windows;
        if (exe.rootModuleTarget().abi == .msvc) {
            // 窗口模式也由微软 CRT 初始化后调用 Zig 的 main。
            exe.entry = .{ .symbol_name = "mainCRTStartup" };
        }
        // 在构建缓存中生成资源脚本，将米白底角色图标嵌入 EXE。
        const files = b.addWriteFiles();
        exe.root_module.addWin32ResourceFile(.{
            .file = files.add("icon.rc", "1 ICON \"icon.ico\"\n"),
            .include_paths = &.{b.path("raw-assets")},
        });
    }

    // 图片复制完成后，再将资源目录安装到可执行文件旁边。
    const assets = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    assets.step.dependOn(copy);
    b.getInstallStep().dependOn(&assets.step);

    // 引擎返回最终程序，应用决定安装名称和运行方式。
    const program = zhuBuild.pack.addStep(b, zhuyu, .{ .exe = exe });
    const install = b.addInstallBinFile(program, exe.out_filename);
    b.getInstallStep().dependOn(&install.step);

    const run = b.addRunFile(program);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the app").dependOn(&run.step);
}
