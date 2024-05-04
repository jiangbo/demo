const std = @import("std");
const gl = @import("gl");
const zlm = @import("zlm");

const Texture2D = @import("texture.zig").Texture2D;
const Shader = @import("shader.zig").Shader;
const Sprite = @import("sprite.zig").Sprite;
const Particle = @import("sprite.zig").Particle;

pub const SpriteRenderer = struct {
    shader: Shader,
    vao: c_uint = 0,

    pub fn draw(self: SpriteRenderer, sprite: Sprite) void {
        self.shader.use();

        var model = zlm.Mat4.createScale(sprite.size.x, sprite.size.y, 1);

        const x, const y = .{ -0.5 * sprite.size.x, -0.5 * sprite.size.y };
        model = model.mul(zlm.Mat4.createTranslationXYZ(x, y, 0));
        const angle = zlm.toRadians(sprite.rotate);
        model = model.mul(zlm.Mat4.createAngleAxis(zlm.Vec3.new(0, 0, 1), angle));
        x, y = .{ 0.5 * sprite.size.x, 0.5 * sprite.size.y };
        model = model.mul(zlm.Mat4.createTranslationXYZ(x, y, 0));

        x, y = .{ sprite.position.x, sprite.position.y };
        model = model.mul(zlm.Mat4.createTranslationXYZ(x, y, 0));

        self.shader.setUniformMatrix4fv("model", &model.fields[0][0]);

        self.shader.setVector3f("spriteColor", sprite.color);

        gl.ActiveTexture(gl.TEXTURE0);
        sprite.texture.bind();

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

pub const ParticleRenderer = struct {
    shader: Shader,
    vao: c_uint = 0,

    pub fn initRenderData(self: *ParticleRenderer) void {
        // Set up mesh and attribute properties
        var vbos: [1]c_uint = undefined;
        const vertices = [_]f32{
            0.0, 1.0, 0.0, 1.0, //
            1.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 0.0,

            0.0, 1.0, 0.0, 1.0,
            1.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0, 0.0,
        };

        gl.GenVertexArrays(1, (&self.vao)[0..1]);
        gl.GenBuffers(vbos.len, &vbos);
        gl.BindVertexArray(self.vao);
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

    pub fn draw(self: ParticleRenderer, particles: []const Particle) void {

        // Use additive blending to give it a 'glow' effect
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE);
        self.shader.use();
        for (particles) |particle| {
            if (particle.life <= 0.0) continue;
            self.shader.setVector2f("offset", particle.position);
            self.shader.setVector4f("color", particle.color);
            particle.texture.bind();
            gl.BindVertexArray(self.vao);
            gl.DrawArrays(gl.TRIANGLES, 0, 6);
            gl.BindVertexArray(0);
        }
        // Don't forget to reset to default blending mode
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    }
};
