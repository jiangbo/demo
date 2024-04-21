const std = @import("std");
const gl = @import("gl");

fn errorPanic(message: ?[]const u8) noreturn {
    @panic(message orelse "unknown error");
}

pub fn init(vertexSource: [:0]const u8, fragmentSource: [:0]const u8) c_uint {
    var success: c_int = undefined;
    var logBuffer: [512:0]u8 = undefined;
    // 顶点着色器
    const vertexShader = gl.CreateShader(gl.VERTEX_SHADER);
    if (vertexShader == 0) errorPanic("create vertex shader failed");
    defer gl.DeleteShader(vertexShader);
    gl.ShaderSource(vertexShader, 1, (&vertexSource.ptr)[0..1], null);
    gl.CompileShader(vertexShader);
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(vertexShader, logBuffer.len, null, &logBuffer);
        errorPanic(std.mem.sliceTo(&logBuffer, 0));
    }

    // 片段着色器
    const fragmentShader = gl.CreateShader(gl.FRAGMENT_SHADER);
    if (fragmentShader == 0) errorPanic("create fragment shader failed");
    defer gl.DeleteShader(fragmentShader);
    gl.ShaderSource(fragmentShader, 1, (&fragmentSource.ptr)[0..1], null);
    gl.CompileShader(fragmentShader);
    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(fragmentShader, logBuffer.len, null, &logBuffer);
        errorPanic(std.mem.sliceTo(&logBuffer, 0));
    }

    // 着色器程序
    const program = gl.CreateProgram();
    if (program == 0) errorPanic("create program failed");
    errdefer gl.DeleteProgram(program);

    gl.AttachShader(program, vertexShader);
    gl.AttachShader(program, fragmentShader);
    gl.LinkProgram(program);
    gl.GetProgramiv(program, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetProgramInfoLog(program, logBuffer.len, null, &logBuffer);
        errorPanic(std.mem.sliceTo(&logBuffer, 0));
    }
    return program;
}
