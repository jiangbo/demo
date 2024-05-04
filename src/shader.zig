const std = @import("std");
const gl = @import("gl");
const zlm = @import("zlm");

fn errorPanic(message: ?[]const u8) noreturn {
    @panic(message orelse "unknown error");
}
const cstr = [:0]const u8;
pub const Shader = struct {
    program: c_uint,

    pub fn init(vertexSource: cstr, fragmentSource: cstr) Shader {
        return Shader{ .program = compile(vertexSource, fragmentSource) };
    }

    pub fn use(self: Shader) void {
        gl.UseProgram(self.program);
    }

    pub fn getUniformLocation(self: Shader, name: cstr) c_int {
        self.use();
        const location = gl.GetUniformLocation(self.program, name.ptr);
        if (location == -1) errorPanic("uniform not found");
        return location;
    }

    pub fn setUniform1i(self: Shader, name: cstr, value: c_int) void {
        gl.Uniform1i(self.getUniformLocation(name), value);
    }

    pub fn uniformMatrix4fv(location: c_int, value: [*c]const f32) void {
        gl.UniformMatrix4fv(location, 1, gl.FALSE, value);
    }

    pub fn setUniformMatrix4fv(self: Shader, name: cstr, value: [*c]const f32) void {
        gl.UniformMatrix4fv(self.getUniformLocation(name), 1, gl.FALSE, value);
    }

    pub fn setVector3f(self: Shader, name: cstr, v: zlm.Vec3) void {
        gl.Uniform3f(self.getUniformLocation(name), v.x, v.y, v.z);
    }

    pub fn setVector2f(self: Shader, name: cstr, v: zlm.Vec2) void {
        gl.Uniform2f(self.getUniformLocation(name), v.x, v.y);
    }

    pub fn setVector4f(self: Shader, name: cstr, v: zlm.Vec4) void {
        gl.Uniform4f(self.getUniformLocation(name), v.x, v.y, v.z, v.w);
    }

    pub fn deinit(self: Shader) void {
        gl.DeleteProgram(self.program);
    }

    fn compile(vertexSource: cstr, fragmentSource: cstr) c_uint {
        // 顶点着色器
        const vertexShader = gl.CreateShader(gl.VERTEX_SHADER);
        if (vertexShader == 0) errorPanic("create vertex shader failed");
        defer gl.DeleteShader(vertexShader);
        gl.ShaderSource(vertexShader, 1, (&vertexSource.ptr)[0..1], null);
        gl.CompileShader(vertexShader);
        checkCompileErrors(vertexShader, false);

        // 片段着色器
        const fragmentShader = gl.CreateShader(gl.FRAGMENT_SHADER);
        if (fragmentShader == 0) errorPanic("create fragment shader failed");
        defer gl.DeleteShader(fragmentShader);
        gl.ShaderSource(fragmentShader, 1, (&fragmentSource.ptr)[0..1], null);
        gl.CompileShader(fragmentShader);
        checkCompileErrors(fragmentShader, false);

        // 着色器程序
        const program = gl.CreateProgram();
        if (program == 0) errorPanic("create program failed");
        errdefer gl.DeleteProgram(program);

        gl.AttachShader(program, vertexShader);
        gl.AttachShader(program, fragmentShader);
        gl.LinkProgram(program);
        checkCompileErrors(program, true);
        return program;
    }

    fn checkCompileErrors(object: c_uint, isProgram: bool) void {
        var success: c_int = undefined;
        var logBuffer: [512:0]u8 = undefined;
        if (isProgram) {
            gl.GetProgramiv(object, gl.LINK_STATUS, &success);
            if (success == gl.FALSE) {
                gl.GetProgramInfoLog(object, logBuffer.len, null, &logBuffer);
                errorPanic(std.mem.sliceTo(&logBuffer, 0));
            }
            return;
        }

        gl.GetShaderiv(object, gl.COMPILE_STATUS, &success);
        if (success == gl.FALSE) {
            gl.GetShaderInfoLog(object, logBuffer.len, null, &logBuffer);
            errorPanic(std.mem.sliceTo(&logBuffer, 0));
        }
    }
};
