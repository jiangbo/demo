const std = @import("std");
const zlm = @import("zlm");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const resource = @import("resource.zig");
const renderer = @import("renderer.zig");

const GameState = enum { active, menu, win };
pub const Game = struct {
    state: GameState = .active,
    width: u32 = 0,
    height: u32 = 0,
    keys: [1024]bool = [1]bool{false} ** 1024,

    var spriteRenderer: renderer.SpriteRenderer = undefined;
    pub fn init(_: *Game) !void {
        const vs: [:0]const u8 = @embedFile("shader/vertex.glsl");
        const fs: [:0]const u8 = @embedFile("shader/fragment.glsl");
        const shader = try resource.loadShader("shader", vs, fs);

        // // configure shaders
        // glm::mat4 projection = glm::ortho(0.0f, static_cast<float>(this->Width),
        //     static_cast<float>(this->Height), 0.0f, -1.0f, 1.0f);
        const projection = zlm.Mat4.createOrthogonal(0, 1, 1, 0, -1, 1);
        shader.setUniformMatrix4fv("projection", &projection.fields[0][0]);
        shader.setUniform1i("image", 0);

        spriteRenderer = renderer.SpriteRenderer{ .shader = shader };
        spriteRenderer.initRenderData();

        const face = "awesomeface.png";
        _ = try resource.loadTexture(face, "assets/" ++ face);
    }
    // game loop
    pub fn processInput(self: Game, deltaTime: f64) void {
        _ = deltaTime;
        _ = self;
    }
    pub fn update(self: Game, deltaTime: f64) void {
        _ = self;
        _ = deltaTime;
    }
    pub fn render(self: Game) void {
        _ = self;
        const options = renderer.DrawSpriteOptions{
            .texture = resource.getTexture("awesomeface.png"),
            .position = zlm.Vec2.new(200, 200),
            .size = zlm.Vec2.new(300, 400),
            .rotate = 45,
            .color = zlm.Vec3.new(0, 1, 0),
        };
        spriteRenderer.draw(options);
    }
};
