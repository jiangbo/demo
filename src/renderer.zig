const std = @import("std");
const gl = @import("gl");
const zlm = @import("zlm");

const Texture2D = @import("texture.zig").Texture2D;
const Shader = @import("shader.zig").Shader;

pub const DrawSpriteOptions = struct {
    texture: Texture2D,
    position: zlm.Vec2 = zlm.Vec2.zero,
    size: zlm.Vec2 = zlm.Vec2.new(10, 10),
    rotate: f32 = 0,
    color: zlm.Vec3 = zlm.Vec3.one,
};

pub const SpriteRenderer = struct {
    shader: Shader,
    vao: c_uint = 0,

    pub fn draw(self: SpriteRenderer, options: DrawSpriteOptions) void {
        self.shader.use();

        // var x, var y = .{ options.position.x, options.position.y };
        // var model = zlm.Mat4.createTranslationXYZ(x, y, 0);

        // x, y = .{ 0.5 * options.size.x, options.size.y };
        // model = model.mul(zlm.Mat4.createTranslationXYZ(x, y, 0));

        // const angle = zlm.toRadians(options.rotate);
        // model = model.mul(zlm.Mat4.createAngleAxis(zlm.Vec3.new(0, 0, 1), angle));

        // x, y = .{ -0.5 * options.size.x, -0.5 * options.size.y };
        // model = model.mul(zlm.Mat4.createTranslationXYZ(x, y, 0));

        // model = model.mul(zlm.Mat4.createScale(options.size.x, options.size.y, 1));
        const model = zlm.Mat4.identity;
        self.shader.setUniformMatrix4fv("model", &model.fields[0][0]);

        self.shader.setVector3f("spriteColor", options.color);

        gl.ActiveTexture(gl.TEXTURE0);
        options.texture.bind();

        gl.BindVertexArray(self.vao);
        gl.DrawArrays(gl.TRIANGLES, 0, 6);
    }

    pub fn initRenderData(self: *SpriteRenderer) void {
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
        const size = @sizeOf(@TypeOf(vertices));
        gl.BufferData(gl.ARRAY_BUFFER, size, &vertices, gl.STATIC_DRAW);

        gl.GenVertexArrays(1, (&self.vao)[0..1]);
        gl.BindVertexArray(self.vao);
        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), 0);

        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.BindVertexArray(0);
    }
};
