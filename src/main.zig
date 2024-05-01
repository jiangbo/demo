const std = @import("std");
const zlm = @import("zlm");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const resource = @import("resource.zig");
const zstbi = @import("zstbi");
const Game = @import("game.zig").Game;

fn logGlfwError(code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("{}: {s}\n", .{ code, description });
}

fn glfwPanic() noreturn {
    @panic(glfw.getErrorString() orelse "unknown error");
}

var breakout: Game = Game{ .width = 800, .height = 600 };
var glProcs: gl.ProcTable = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    glfw.setErrorCallback(logGlfwError);
    if (!glfw.init(.{})) glfwPanic();
    defer glfw.terminate();
    const window = glfw.Window.create(800, 600, "学习 OpenGL", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
    }) orelse glfwPanic();
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);
    glfw.swapInterval(1);
    glfw.Window.setFramebufferSizeCallback(window, windowChange);
    glfw.Window.setKeyCallback(window, keyCallback);

    if (!glProcs.init(glfw.getProcAddress)) glfwPanic();

    gl.makeProcTableCurrent(&glProcs);
    defer gl.makeProcTableCurrent(null);
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    try breakout.init(gpa.allocator());
    defer breakout.deinit();
    var lastFrame: f32 = 0.0;

    while (!window.shouldClose()) {
        const currentFrame = @as(f32, @floatCast(glfw.getTime()));
        defer lastFrame = currentFrame;
        const deltaTime = currentFrame - lastFrame;

        glfw.pollEvents();
        breakout.processInput(deltaTime);
        breakout.update(deltaTime);

        gl.ClearColor(0, 0, 0, 0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        breakout.render();
        window.swapBuffers();
    }
}

fn windowChange(_: glfw.Window, w: u32, h: u32) void {
    gl.Viewport(0, 0, @as(c_int, @intCast(w)), @as(c_int, @intCast(h)));
}

fn keyCallback(
    window: glfw.Window,
    key: glfw.Key,
    scancode: i32,
    action: glfw.Action,
    _: glfw.Mods,
) void {
    if (key == .escape and action == .press)
        window.setShouldClose(true);
    if (scancode >= 0 and scancode < 1024) {
        const index: usize = @intCast(scancode);
        if (action == .press) breakout.keys[index] = true //
        else if (action == .release) breakout.keys[index] = false;
    }
}
