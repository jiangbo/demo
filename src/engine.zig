const std = @import("std");
const gl = @import("gl");
const zlm = @import("zlm");

const GameStateEnum = enum { menu, running, win };

const GraphicWindow = struct {
    state: GameStateEnum,
    keys: [1024]bool,
    width: usize,
    height: usize,
    fn init(width: usize, height: usize) void {
        _ = width;
        _ = height;
    }

    fn processInput() void {}
    fn update() void {}
    fn render() void {}
    fn deinit() void {}
};

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

pub const Texture = struct {
    id: c_uint = 0,
    data: []const u8,
    width: c_int = 0,
    height: c_int = 0,

    pub fn init(data: []const u8) Texture {
        var texture = Texture{ .data = data };
        gl.GenTextures(1, (&texture.id)[0..1]);
        return texture;
    }

    pub fn generate(self: *Texture, internalformat: c_int, imageFormat: c_uint) void {
        gl.BindTexture(gl.TEXTURE_2D, self.id);
        gl.TexImage2D(gl.TEXTURE_2D, 0, internalformat, self.width, self.height, //
            0, imageFormat, gl.UNSIGNED_BYTE, self.data.ptr);

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        // unbind texture
        gl.BindTexture(gl.TEXTURE_2D, 0);
    }

    pub fn bind(self: Texture) void {
        gl.BindTexture(gl.TEXTURE_2D, self.id);
    }

    pub fn deinit(self: *Texture) void {
        gl.DeleteTextures(1, (&self.id)[0..1]);
    }
};
