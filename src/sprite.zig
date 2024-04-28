const std = @import("std");
const engine = @import("engine.zig");
const zlm = @import("zlm");
const gl = @import("gl");

const Texture = engine.Texture;
const Shader = engine.Shader;
pub const DrawOptions = struct {
    position: zlm.Vec2 = zlm.Vec2.zero,
    size: zlm.Vec2 = zlm.Vec2.zero,
    rotate: f32 = 0,
    color: zlm.Vec3 = zlm.Vec3.new(1, 1, 1),
};

pub const Renderer = struct {
    shader: Shader,
    vao: c_uint = 0,

    pub fn draw(self: Renderer, texture: Texture) void {
        // 准备变换
        self.shader.use();

        // const model = zlm.Mat4.identity;
        // self.shader.setUniformMatrix4fv("model", &model.fields[0][0]);

        // const color = zlm.Vec3.new(0.0, 1.0, 0.0);
        // self.shader.setVector3f("spriteColor", color);

        gl.ActiveTexture(gl.TEXTURE0);
        texture.bind();

        gl.BindVertexArray(self.vao);
        gl.DrawArrays(gl.TRIANGLES, 0, 6);
    }

    pub fn initRenderData(self: *Renderer) void {
        const vertices = [_]f32{
            0.0, 1.0, 0.0, 1.0, //
            1.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 0.0,

            0.0, 1.0, 0.0, 1.0,
            1.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0, 0.0,
        };

        var vbos: [1]c_uint = undefined;
        gl.GenBuffers(vbos.len, &vbos);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

        gl.GenVertexArrays(1, (&self.vao)[0..1]);
        gl.BindVertexArray(self.vao);
        gl.EnableVertexAttribArray(0);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
        gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), 0);

        // gl.BindVertexArray(0);
    }
};
