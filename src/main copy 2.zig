const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const zstbi = @import("zstbi");
const zlm = @import("zlm");
const engine = @import("engine.zig");
const resource = @import("resource.zig");

fn logGlfwError(code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("{}: {s}\n", .{ code, description });
}

fn glfwPanic() noreturn {
    @panic(glfw.getErrorString() orelse "unknown error");
}

var glProcs: gl.ProcTable = undefined;
const vertices = [_]f32{
    // pos      // tex
    0.0, 1.0, 0.0, 1.0,
    1.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 0.0,

    0.0, 1.0, 0.0, 1.0,
    1.0, 1.0, 1.0, 1.0,
    1.0, 0.0, 1.0, 0.0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const window = initWindow();
    defer deinit(window);

    zstbi.init(gpa.allocator());
    defer zstbi.deinit();
    zstbi.setFlipVerticallyOnLoad(true);

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);
    glfw.swapInterval(1);

    if (!glProcs.init(glfw.getProcAddress)) glfwPanic();

    gl.makeProcTableCurrent(&glProcs);
    defer gl.makeProcTableCurrent(null);
    gl.Enable(gl.DEPTH_TEST);

    resource.init(gpa.allocator());
    defer resource.deinit();

    // VBO 顶点缓冲对象
    var vbos: [1]c_uint = undefined;
    gl.GenBuffers(vbos.len, &vbos);
    defer gl.DeleteBuffers(vbos.len, &vbos);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

    // VAO 顶点数组对象
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), 0);

    const vs: [:0]const u8 = @embedFile("vertex.glsl");
    const fs: [:0]const u8 = @embedFile("fragment.glsl");
    const shader = try resource.loadShader("shader", vs, fs);
    defer shader.deinit();
    shader.use();

    gl.ActiveTexture(gl.TEXTURE0);
    const name = "container.jpg";
    var texture1 = try resource.loadTexture(name, "assets/" ++ name, false);
    defer texture1.deinit();
    texture1.bind();
    shader.setUniform1i("texture1", 0);

    gl.ActiveTexture(gl.TEXTURE1);
    const face = "awesomeface.png";
    var texture2 = try resource.loadTexture(face, "assets/" ++ face, true);
    defer texture2.deinit();
    texture2.bind();
    shader.setUniform1i("texture2", 1);

    const projection = zlm.Mat4.createOrthogonal(0, 800, 600, 0, -1, 1);
    shader.setUniformMatrix4fv("projection", &projection.fields[0][0]);

    while (!window.shouldClose()) {
        glfw.pollEvents();
        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const model = zlm.Mat4.identity;
        shader.setUniformMatrix4fv("model", &model.fields[0][0]);
        gl.DrawArrays(gl.TRIANGLES, 0, 6);

        window.swapBuffers();
    }
}

fn initWindow() glfw.Window {
    glfw.setErrorCallback(logGlfwError);

    if (!glfw.init(.{})) glfwPanic();

    return glfw.Window.create(800, 600, "学习 OpenGL", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
    }) orelse glfwPanic();
}

fn deinit(window: glfw.Window) void {
    window.destroy();
    glfw.terminate();
}