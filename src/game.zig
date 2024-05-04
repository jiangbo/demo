const std = @import("std");
const zlm = @import("zlm");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const resource = @import("resource.zig");
const renderer = @import("renderer.zig");
const sprite = @import("sprite.zig");

const Allocator = std.mem.Allocator;
const GameState = enum { active, menu, win };
const playerSpeed: f32 = 500;
const ballRadius: f32 = 12.5;
const ballVelocity: zlm.Vec2 = zlm.Vec2.new(100, -350);
var lastUsedParticle: usize = 0;

pub const Game = struct {
    state: GameState = .active,
    width: f32,
    height: f32,
    keys: [1024]bool = [_]bool{false} ** 1024,
    spriteRenderer: renderer.SpriteRenderer = undefined,
    particleRenderer: renderer.ParticleRenderer = undefined,
    levels: [4]GameLevel = undefined,
    level: usize = 0,
    player: sprite.Sprite = undefined,
    ball: sprite.Ball = undefined,
    particles: [500]sprite.Particle = undefined,

    pub fn init(self: *Game, allocator: std.mem.Allocator) !void {
        resource.init(allocator);

        const shader = resource.getShader(.shader);
        const projection = zlm.Mat4.createOrthogonal(0, self.width, self.height, 0, -1, 1);
        shader.setUniformMatrix4fv("projection", &projection.fields[0][0]);
        shader.setUniform1i("image", 0);

        self.spriteRenderer = renderer.SpriteRenderer{ .shader = shader };
        self.spriteRenderer.initRenderData();

        const particle = resource.getShader(.particle);
        particle.setUniformMatrix4fv("projection", &projection.fields[0][0]);
        shader.setUniform1i("image", 0);

        self.particleRenderer = renderer.ParticleRenderer{ .shader = particle };
        self.particleRenderer.initRenderData();

        for (&self.particles) |*value| value.*.texture = resource.getTexture(.particle);

        var buffer: [30]u8 = undefined;
        for (&self.levels, 1..) |*value, i| {
            value.* = .{ .width = self.width, .height = self.height / 2 };
            const path = std.fmt.bufPrint(&buffer, "assets/lv{}.json", .{i});
            try value.init(allocator, try path);
        }

        self.resetPlayer();
    }

    fn ballPositionWithPlayer(self: Game) zlm.Vec2 {
        if (!self.ball.stuck) return self.ball.sprite.position;
        const x = self.player.size.x / 2 - ballRadius;
        return self.player.position.add(zlm.Vec2.new(x, -ballRadius * 2));
    }

    fn doCollisions(self: *Game) void {
        for (self.levels[self.level].bricks.items) |*box| {
            if (box.destroyed) continue;

            const collision = self.ball.checkCollision(box.*);
            if (!collision.collisioned) continue;
            if (!box.solid) box.destroyed = true;

            if (collision.direction == .left or collision.direction == .right) {
                self.ball.sprite.velocity.x = -self.ball.sprite.velocity.x;
                var delta = self.ball.radius - @abs(collision.vector.x);
                delta = if (collision.direction == .left) -delta else delta;
                self.ball.sprite.position.x += delta;
            } else {
                self.ball.sprite.velocity.y = -self.ball.sprite.velocity.y;
                var delta = self.ball.radius - @abs(collision.vector.y);
                delta = if (collision.direction == .up) -delta else delta;
                self.ball.sprite.position.y += delta;
            }
        }

        const collision = self.ball.checkCollision(self.player);
        if (!collision.collisioned) return;

        const ballSprite = &self.ball.sprite;
        const center = self.player.position.x + self.player.size.x / 2;
        const distance = (ballSprite.position.x + self.ball.radius) - center;
        const percentage = distance / (self.player.size.x / 2);

        const old = self.ball.sprite.velocity;
        ballSprite.velocity.x = ballVelocity.x * percentage * 2;
        ballSprite.velocity.y = -@abs(ballSprite.velocity.y);
        ballSprite.velocity = ballSprite.velocity.normalize().scale(old.length());
    }

    pub fn processInput(self: *Game, deltaTime: f32) void {
        if (self.state != .active) return;

        const distance = playerSpeed * deltaTime;

        if (self.keys[@as(usize, @intCast(glfw.Key.a.getScancode()))]) {
            self.player.position.x -= distance;
            if (self.player.position.x < 0) self.player.position.x = 0;
            self.ball.sprite.position = self.ballPositionWithPlayer();
        }

        if (self.keys[@as(usize, @intCast(glfw.Key.d.getScancode()))]) {
            self.player.position.x += distance;
            const maxX = self.width - self.player.size.x;
            if (self.player.position.x > maxX) self.player.position.x = maxX;
            self.ball.sprite.position = self.ballPositionWithPlayer();
        }

        if (self.keys[@as(usize, @intCast(glfw.Key.space.getScancode()))]) {
            self.ball.stuck = false;
        }
    }

    pub fn update(self: *Game, deltaTime: f32) void {
        _ = self.ball.move(deltaTime, self.width);

        if (!self.ball.stuck) self.doCollisions();

        if (self.ball.sprite.position.y >= self.height) {
            self.levels[self.level].reset();
            self.resetPlayer();
        }

        for (0..2) |_| {
            const unusedParticle = self.firstUnusedParticle();
            const offset = zlm.Vec2.all(self.ball.radius / 2.0);
            self.particles[unusedParticle].respawn(self.ball.sprite, offset);
        }

        for (&self.particles) |*particle| {
            particle.life -= deltaTime;
            if (particle.life <= 0) continue;

            const velocity = particle.velocity.scale(deltaTime);
            particle.position = particle.position.sub(velocity);
            particle.color.w -= deltaTime * 2.5;
        }
    }

    pub fn render(self: Game) void {
        if (self.state != .active) return;
        const background = resource.getTexture(.background);
        self.spriteRenderer.draw(sprite.Sprite{
            .texture = background,
            .size = zlm.Vec2.new(self.width, self.height),
        });

        self.levels[self.level].draw(self.spriteRenderer);
        self.spriteRenderer.draw(self.player);
        self.particleRenderer.draw(&self.particles);
        self.spriteRenderer.draw(self.ball.sprite);
    }

    fn resetPlayer(self: *Game) void {
        self.player = sprite.Sprite{
            .texture = resource.getTexture(.paddle),
            .position = zlm.Vec2.new(self.width / 2 - 50, self.height - 20),
            .size = zlm.Vec2.new(100, 20),
        };
        self.ball = sprite.Ball{ .radius = ballRadius, .sprite = sprite.Sprite{
            .size = zlm.Vec2.new(ballRadius * 2, ballRadius * 2),
            .texture = resource.getTexture(.face),
            .velocity = ballVelocity,
        } };
        self.ball.sprite.position = self.ballPositionWithPlayer();
    }

    pub fn deinit(self: Game) void {
        for (self.levels) |level| level.deinit();
        resource.deinit();
    }

    fn firstUnusedParticle(self: Game) usize {
        // search from last used particle, this will usually return almost instantly
        for (lastUsedParticle..self.particles.len) |index| {
            if (self.particles[index].life <= 0) {
                lastUsedParticle = index;
                return index;
            }
        }

        // otherwise, do a linear search
        for (0..lastUsedParticle) |index| {
            if (self.particles[index].life <= 0) {
                lastUsedParticle = index;
                return index;
            }
        }
        // override first particle if all others are alive
        lastUsedParticle = 0;
        return 0;
    }
};

const GameLevel = struct {
    bricks: std.ArrayList(sprite.Sprite) = undefined,
    width: f32 = 0,
    height: f32 = 0,
    copy: std.ArrayList(sprite.Sprite) = undefined,

    fn draw(self: GameLevel, render: renderer.SpriteRenderer) void {
        for (self.bricks.items) |brick| {
            if (!brick.destroyed) render.draw(brick);
        }
    }

    fn deinit(self: GameLevel) void {
        self.bricks.deinit();
        self.copy.deinit();
    }
    // fn isCompleted() bool{
    //     return false;
    // };
    fn init(self: *GameLevel, allocator: std.mem.Allocator, path: []const u8) !void {
        try self.doInit(allocator, path);
        self.copy = try self.bricks.clone();
    }

    fn doInit(self: *GameLevel, allocator: std.mem.Allocator, path: []const u8) !void {
        std.log.info("load level: {s}", .{path});
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const text = try file.readToEndAlloc(allocator, 1024 * 4);
        defer allocator.free(text);

        const parsed = try std.json.parseFromSlice(FileLevel, allocator, text, .{});
        defer parsed.deinit();

        try self.parse(allocator, parsed.value);
    }

    fn parse(self: *GameLevel, allocator: std.mem.Allocator, file: FileLevel) !void {
        const size = file.width * file.height;
        self.bricks = try std.ArrayList(sprite.Sprite).initCapacity(allocator, size);
        const unitWidth = self.width / @as(f32, @floatFromInt(file.width));
        const unitHeight = self.height / @as(f32, @floatFromInt(file.height));

        for (file.level, 0..) |unit, index| {
            const x: f32 = @floatFromInt(index % file.width);
            const y: f32 = @floatFromInt(index / file.width);
            if (unit == 1) {
                self.bricks.append(sprite.Sprite{
                    .position = zlm.Vec2.new(x * unitWidth, y * unitHeight),
                    .size = zlm.Vec2.new(unitWidth, unitHeight),
                    .texture = resource.getTexture(.solid_block),
                    .solid = true,
                }) catch unreachable;
                continue;
            }

            const color = switch (unit) {
                0 => continue,
                2 => zlm.Vec3.new(0.2, 0.6, 1.0),
                3 => zlm.Vec3.new(0.0, 0.7, 0.0),
                4 => zlm.Vec3.new(0.8, 0.8, 0.4),
                5 => zlm.Vec3.new(1.0, 0.5, 0.0),
                else => zlm.Vec3.new(1.0, 1.0, 1.0),
            };

            self.bricks.append(sprite.Sprite{
                .position = zlm.Vec2.new(x * unitWidth, y * unitHeight),
                .size = zlm.Vec2.new(unitWidth, unitHeight),
                .texture = resource.getTexture(.block),
                .color = color,
            }) catch unreachable;
        }
    }

    fn reset(self: *GameLevel) void {
        @memcpy(self.bricks.items, self.copy.items);
    }
};

const FileLevel = struct { level: []const u8, width: usize, height: usize };
