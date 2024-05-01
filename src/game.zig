const std = @import("std");
const zlm = @import("zlm");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const resource = @import("resource.zig");
const SpriteRenderer = @import("renderer.zig").SpriteRenderer;
const sprite = @import("sprite.zig");

const Allocator = std.mem.Allocator;
const GameState = enum { active, menu, win };
const playerSpeed: f32 = 500;
const ballRadius: f32 = 12.5;
pub const Game = struct {
    state: GameState = .active,
    width: f32,
    height: f32,
    keys: [1024]bool = [_]bool{false} ** 1024,
    spriteRenderer: SpriteRenderer = undefined,
    levels: [4]GameLevel = undefined,
    level: usize = 0,
    player: sprite.Sprite = undefined,
    ball: sprite.Ball = undefined,

    pub fn init(self: *Game, allocator: std.mem.Allocator) !void {
        resource.init(allocator);

        const vs: [:0]const u8 = @embedFile("shader/vertex.glsl");
        const fs: [:0]const u8 = @embedFile("shader/fragment.glsl");
        const shader = resource.loadShader(.shader, vs, fs);

        const projection = zlm.Mat4.createOrthogonal(0, self.width, self.height, 0, -1, 1);
        shader.setUniformMatrix4fv("projection", &projection.fields[0][0]);
        shader.setUniform1i("image", 0);

        self.spriteRenderer = SpriteRenderer{ .shader = shader };
        self.spriteRenderer.initRenderData();

        var buffer: [30]u8 = undefined;
        for (&self.levels, 1..) |*value, i| {
            value.* = .{ .width = self.width, .height = self.height / 2 };
            const path = std.fmt.bufPrint(&buffer, "assets/lv{}.json", .{i});
            try value.init(allocator, try path);
        }

        self.player = sprite.Sprite{
            .texture = resource.getTexture(.paddle),
            .position = zlm.Vec2.new(self.width / 2 - 50, self.height - 20),
            .size = zlm.Vec2.new(100, 20),
        };

        self.ball = sprite.Ball{ .sprite = sprite.Sprite{
            .size = zlm.Vec2.new(ballRadius * 2, ballRadius * 2),
            .texture = resource.getTexture(.face),
        }, .radius = ballRadius };
        self.ball.sprite.position = self.ballPositionWithPlayer();
    }

    fn ballPositionWithPlayer(self: Game) zlm.Vec2 {
        if (!self.ball.stuck) return self.ball.sprite.position;
        const x = self.player.size.x / 2 - ballRadius;
        return self.player.position.add(zlm.Vec2.new(x, -ballRadius * 2));
    }

    fn doCollisions(self: *Game) void {
        for (self.levels[self.level].bricks.items) |*box| {
            if (box.destroyed or box.solid) continue;
            if (box.checkCollision(self.ball.sprite)) box.destroyed = true;
        }
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

        self.doCollisions();
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
        self.spriteRenderer.draw(self.ball.sprite);
    }

    pub fn deinit(self: Game) void {
        for (self.levels) |level| level.deinit();
        resource.deinit();
    }
};

const GameLevel = struct {
    bricks: std.ArrayList(sprite.Sprite) = undefined,
    width: f32 = 0,
    height: f32 = 0,

    fn draw(self: GameLevel, renderer: SpriteRenderer) void {
        for (self.bricks.items) |brick| {
            if (!brick.destroyed) renderer.draw(brick);
        }
    }

    fn deinit(self: GameLevel) void {
        self.bricks.deinit();
    }
    // fn isCompleted() bool{
    //     return false;
    // };
    fn init(self: *GameLevel, allocator: std.mem.Allocator, path: []const u8) !void {
        try self.doInit(allocator, path);
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

    fn parse(self: *GameLevel, allocator: std.mem.Allocator, level: FileLevel) !void {
        const size = level.width * level.height;
        self.bricks = try std.ArrayList(sprite.Sprite).initCapacity(allocator, size);

        const unitWidth = self.width / @as(f32, @floatFromInt(level.width));
        const unitHeight = self.height / @as(f32, @floatFromInt(level.height));

        for (level.level, 0..) |unit, index| {
            const x: f32 = @floatFromInt(index % level.width);
            const y: f32 = @floatFromInt(index / level.width);
            if (unit == 1) {
                try self.bricks.append(sprite.Sprite{
                    .position = zlm.Vec2.new(x * unitWidth, y * unitHeight),
                    .size = zlm.Vec2.new(unitWidth, unitHeight),
                    .texture = resource.getTexture(.solid_block),
                    .solid = true,
                });
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

            try self.bricks.append(sprite.Sprite{
                .position = zlm.Vec2.new(x * unitWidth, y * unitHeight),
                .size = zlm.Vec2.new(unitWidth, unitHeight),
                .texture = resource.getTexture(.block),
                .color = color,
            });
        }
    }
};

const FileLevel = struct {
    level: []const u8,
    width: usize,
    height: usize,
};
