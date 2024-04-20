const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");

fn logGlfwError(code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("{}: {s}\n", .{ code, description });
}

fn glfwPanic() noreturn {
    @panic(glfw.getErrorString() orelse "unknown error");
}

pub fn main() void {
    glfw.setErrorCallback(logGlfwError);

    if (!glfw.init(.{})) glfwPanic();
    defer glfw.terminate();

    const window = glfw.Window.create(640, 480, "学习 OpenGL", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
    }) orelse glfwPanic();
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    glfw.swapInterval(1);

    while (!window.shouldClose()) {
        glfw.pollEvents();
        window.swapBuffers();
    }
}
