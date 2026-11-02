const std = @import("std");
const zhuBuild = @import("zhuyu");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const android = target.result.abi.isAndroid();

    // 两张独立图片原样复制到资源目录，供运行和打包读取。
    var dir = try std.Io.Dir.cwd().openDir(b.graph.io, //
        try b.root.joinString(b.allocator, "."), .{});
    defer dir.close(b.graph.io);
    try dir.createDirPath(b.graph.io, "assets");
    try dir.copyFile("raw-assets/icon.png", dir, "assets/icon.png", b.graph.io, .{});
    try dir.copyFile("raw-assets/title.png", dir, "assets/title.png", b.graph.io, .{});

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
        // Web 资源随 HTML 一起安装。
        b.installDirectory(.{
            .source_dir = b.path("assets"),
            .install_dir = .prefix,
            .install_subdir = "web/assets",
        });
    } else {
        buildNative(b, zhuyu, mod);
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
) void {
    const exe = b.addExecutable(.{ .name = "demo", .root_module = mod });
    zhuBuild.setLibC(zhuyu, exe);
    // Windows 调试时显示控制台日志，发布时不创建控制台窗口。
    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.subsystem = if (mod.optimize.? == .debug) .console else .windows;
        // 在构建缓存中生成资源脚本，将米白底角色图标嵌入 EXE。
        const files = b.addWriteFiles();
        exe.root_module.addWin32ResourceFile(.{
            .file = files.add("icon.rc", "1 ICON \"icon.ico\"\n"),
            .include_paths = &.{b.path("raw-assets")},
        });
    }
    b.installArtifact(exe);

    // 原生资源安装到可执行文件旁边，供引擎按相对路径读取。
    b.installDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });

    // 由引擎注册资源打包命令，普通构建和运行使用原始程序。
    zhuBuild.pack.addStep(b, zhuyu, .{ .exe = exe });

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the app").dependOn(&run.step);
}
