const std = @import("std");
const gfx = @import("graphics.zig");
const animation = @import("animation.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");
const window = @import("window.zig");

pub const Player = struct {
    x: f32 = 500,
    y: f32 = 500,
    speed: f32 = 0.4,
    faceLeft: bool = true,
    animation: animation.FrameAnimation,
    shadow: gfx.Texture,
    moveUp: bool = false,
    moveDown: bool = false,
    moveLeft: bool = false,
    moveRight: bool = false,

    pub fn init() Player {
        const leftFmt: []const u8 = "assets/img/player_left_{}.png";
        const left = animation.FixedSizeFrameAnimation.load(leftFmt, 50).?;

        const rightFmt = "assets/img/player_right_{}.png";
        const right = animation.FixedSizeFrameAnimation.load(rightFmt, 50).?;

        return .{
            .animation = .{ .left = left, .right = right },
            .shadow = cache.TextureCache.load("assets/img/shadow_player.png").?,
        };
    }

    pub fn processEvent(self: *Player, event: *const window.Event) void {
        if (event.type == .KEY_DOWN) switch (event.key_code) {
            .W => self.moveUp = true,
            .S => self.moveDown = true,
            .A => self.moveLeft = true,
            .D => self.moveRight = true,
            else => {},
        } else if (event.type == .KEY_UP) switch (event.key_code) {
            .W => self.moveUp = false,
            .S => self.moveDown = false,
            .A => self.moveLeft = false,
            .D => self.moveRight = false,
            else => {},
        };
    }

    pub fn update(self: *Player, delta: f32) void {
        var vector2: Vector2 = .{};
        if (self.moveUp) vector2.y -= 1;
        if (self.moveDown) vector2.y += 1;
        if (self.moveLeft) vector2.x -= 1;
        if (self.moveRight) vector2.x += 1;

        const normalized = vector2.normalize();
        self.x += normalized.x * delta * self.speed;
        self.y += normalized.y * delta * self.speed;

        self.x = std.math.clamp(self.x, 0, context.width - self.currentTexture().width);
        self.y = std.math.clamp(self.y, 0, context.height - self.currentTexture().height);

        if (self.moveLeft) self.faceLeft = true;
        if (self.moveRight) self.faceLeft = false;

        if (self.faceLeft)
            self.animation.left.play(delta)
        else
            self.animation.right.play(delta);
    }

    pub fn currentTexture(self: Player) gfx.Texture {
        return if (self.faceLeft)
            self.animation.left.currentTexture()
        else
            self.animation.right.currentTexture();
    }

    pub fn shadowX(self: *Player) f32 {
        const w = self.currentTexture().width - self.shadow.width;
        return self.x + w / 2;
    }

    pub fn shadowY(self: *Player) f32 {
        return self.y + self.currentTexture().height - 8;
    }
};

const Vector2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn normalize(self: Vector2) Vector2 {
        if (self.x == 0 and self.y == 0) return .{};
        const length = std.math.sqrt(self.x * self.x + self.y * self.y);
        return .{ .x = self.x / length, .y = self.y / length };
    }
};
