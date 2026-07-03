const std = @import("std");
const sk = @import("sokol");

const Options = struct {
    mod: *std.Build.Module,
    sokolModule: *std.Build.Module,
    emsdk: *std.Build.Dependency,
    shader: *std.Build.Module,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const sokolModule = sokol.module("sokol");
    const emsdk = sokol.builder.dependency("emsdk", .{});
    const emsdkStep = sk.emSdkInstallStep(b, emsdk, .{});
    b.step("install-emsdk", "install emsdk").dependOn(emsdkStep);

    const shader = try createShader(b, sokol, sokolModule);
    const exeModule = b.createModule(.{
        .root_source_file = b.path("farm/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = sokolModule },
        },
    });

    const options = Options{
        .mod = exeModule,
        .sokolModule = sokolModule,
        .emsdk = emsdk,
        .shader = shader,
    };
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, options);
    } else {
        try buildNative(b, options);
    }
}

fn createShader(
    b: *std.Build,
    sokol: *std.Build.Dependency,
    sokolModule: *std.Build.Module,
) !*std.Build.Module {
    return try sk.shdc.createModule(b, "shader", sokolModule, .{
        .shdc_dep = sokol.builder.dependency("shdc", .{}),
        .input = "src/engine/shader/quad.glsl",
        .output = "quad.glsl.zig",
        .slang = .{
            .glsl410 = true,
            .metal_macos = true,
            .hlsl5 = true,
            .glsl300es = true,
            .wgsl = true,
        },
        .reflection = true,
    });
}

fn createZhu(b: *std.Build, options: Options) *std.Build.Module {
    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;
    const zhuModule = b.createModule(.{
        .root_source_file = b.path("src/engine/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zhuModule.addImport("sokol", options.sokolModule);
    zhuModule.addImport("shader", options.shader);
    return zhuModule;
}

fn buildNative(b: *std.Build, options: Options) !void {
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = options.mod,
    });

    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;
    if (optimize != .Debug) exe.subsystem = .Windows;

    const zhuModule = createZhu(b, options);
    exe.root_module.addImport("zhu", zhuModule);

    b.installArtifact(exe);

    const stb = b.dependency("stb", .{
        .target = target,
        .optimize = optimize,
    });
    zhuModule.addIncludePath(stb.path("."));

    const cFlags = &.{"-O2"};
    zhuModule.addCSourceFile(.{
        .file = b.path("src/engine/internal/stb_audio.c"),
        .flags = cFlags,
    });

    const testModule = b.createModule(.{
        .root_source_file = b.path("farm/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    testModule.addImport("zhu", zhuModule);

    const tests = b.addTest(.{ .name = "tests", .root_module = testModule });

    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run farm tests").dependOn(&run_tests.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}

fn buildWeb(b: *std.Build, options: Options) !void {
    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;

    const exe = b.addLibrary(.{
        .name = "demo",
        .root_module = options.mod,
    });

    const zhuModule = createZhu(b, options);
    exe.root_module.addImport("zhu", zhuModule);

    const include = options.emsdk.path(b.pathJoin(&.{
        "upstream",
        "emscripten",
        "cache",
        "sysroot",
        "include",
    }));
    zhuModule.addSystemIncludePath(include);

    const stb = b.dependency("stb", .{
        .target = target,
        .optimize = optimize,
    });
    zhuModule.addIncludePath(stb.path("."));

    const cFlags = &.{ "-O2", "-fno-sanitize=undefined" };
    zhuModule.addCSourceFile(.{
        .file = b.path("src/engine/internal/stb_audio.c"),
        .flags = cFlags,
    });

    const link_step = try sk.emLinkStep(b, .{
        .lib_main = exe,
        .target = target,
        .optimize = optimize,
        .use_webgl2 = true,
        .emsdk = options.emsdk,
        .use_emmalloc = true,
        // TODO Zig 0.17 重新验证，能关闭就改回 false。
        // 当前先保持 Web 文件读写可用。
        .use_filesystem = true,
        .extra_args = &.{
            "-sINITIAL_MEMORY=64MB",
            "--js-library",
            b.pathFromRoot("src/engine/internal/em.js"),
            // TODO sokol 修复文件依赖刷新后，删除 emJsCacheStamp。
            // sokol 的 extra_args 不追踪文件输入，用 hash stamp 触发重链。
            "--pre-js",
            try emJsCacheStamp(b),
        },
        .shell_file_path = b.path("index.html"),
    });

    // 将 Emscripten 链接输出接到默认安装步骤。
    b.getInstallStep().dependOn(&link_step.step);
}

// 让 em.js 内容变化体现在 emcc 参数里，避免 Zig 缓存复用旧输出。
fn emJsCacheStamp(b: *std.Build) ![]const u8 {
    const bytes = @embedFile("src/engine/internal/em.js");
    const hash = std.hash.Wyhash.hash(0, bytes);
    const stamp = b.pathFromRoot(b.fmt(".zig-cache/em-js-{x}.js", .{hash}));

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(b.graph.io, b.pathFromRoot(".zig-cache"));
    try cwd.writeFile(b.graph.io, .{
        .sub_path = stamp,
        .data = "// em.js cache stamp\n",
    });
    return stamp;
}
