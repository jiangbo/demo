const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const Bullet = @import("bullet.zig").Bullet;
const Vector = @import("bullet.zig").Vector;

pub const Player = struct {
    x: f32,
    y: f32,
    facingLeft: bool,
    leftKeyDown: bool = false,
    rightKeyDown: bool = false,
    velocity: f32 = 0,
    width: f32 = 96,
    height: f32 = 96,

    attackInterval: f32 = 200,
    attackTimer: f32 = 0,

    hp: u32 = 100,
    mp: u32 = 100,

    animationIdle: gfx.FrameAnimation = undefined,
    animationRun: gfx.FrameAnimation = undefined,

    const runVelocity: f32 = 0.55;
    const gravity: f32 = 1.6e-3;
    const jumpVelocity: f32 = -0.85;

    pub fn init(playerType: scene.PlayerType, x: f32, y: f32, faceLeft: bool) Player {
        var self: Player = .{ .x = x, .y = y, .facingLeft = faceLeft };

        if (playerType == .peaShooter) {
            self.animationIdle = .load("assets/peashooter_idle_{}.png", 9);
            self.animationRun = .load("assets/peashooter_run_{}.png", 5);
        } else {
            self.animationIdle = .load("assets/sunflower_idle_{}.png", 8);
            self.animationRun = .load("assets/sunflower_run_{}.png", 5);
        }

        return self;
    }

    pub fn event(self: *Player, ev: *const window.Event) void {
        switch (ev.type) {
            .KEY_DOWN => switch (ev.key_code) {
                .A, .LEFT => {
                    self.leftKeyDown = true;
                    self.facingLeft = true;
                },
                .D, .RIGHT => {
                    self.rightKeyDown = true;
                    self.facingLeft = false;
                },
                .W, .UP => {
                    if (self.velocity != 0) return;
                    self.velocity += Player.jumpVelocity;
                },
                .F => self.attack(true),
                .PERIOD => self.attack(false),
                else => {},
            },
            .KEY_UP => switch (ev.key_code) {
                .A, .LEFT => self.leftKeyDown = false,
                .D, .RIGHT => self.rightKeyDown = false,
                else => {},
            },
            else => {},
        }
    }

    pub fn update(self: *Player, delta: f32) void {
        var direction: f32 = 0;
        if (self.leftKeyDown) direction -= 1;
        if (self.rightKeyDown) direction += 1;
        self.x += direction * Player.runVelocity * delta;

        if (self.leftKeyDown or self.rightKeyDown) {
            self.animationRun.update(delta);
        } else {
            self.animationIdle.update(delta);
        }

        moveAndCollide(self, delta);

        self.attackTimer -= delta;
    }

    fn moveAndCollide(self: *Player, delta: f32) void {
        const velocity = self.velocity + Player.gravity * delta;
        const y = self.y + velocity * delta;

        const platforms = &scene.gameScene.platforms;
        for (platforms) |*platform| {
            if (self.x + self.width < platform.shape.left) continue;
            if (self.x > platform.shape.right) continue;
            if (y + self.height < platform.shape.y) continue;

            const deltaPosY = self.velocity * delta;
            const lastFootPosY = self.y + self.height - deltaPosY;

            if (lastFootPosY <= platform.shape.y) {
                self.y = platform.shape.y - self.height;
                self.velocity = 0;
                break;
            }
        } else {
            self.y = y;
            self.velocity = velocity;
        }
    }

    pub fn render(self: *Player) void {
        if (self.leftKeyDown) {
            self.animationRun.playFlipX(self.x, self.y, true);
        } else if (self.rightKeyDown) {
            self.animationRun.playFlipX(self.x, self.y, false);
        } else {
            self.animationIdle.playFlipX(self.x, self.y, self.facingLeft);
        }
    }

    pub fn attack(self: *Player, p1: bool) void {
        if (self.attackTimer > 0) return;

        self.attackTimer = self.attackInterval;

        var bullet: Bullet = Bullet.init(p1, false);
        const x: f32 = if (self.facingLeft) self.x else self.x + self.width;
        bullet.position = .{ .x = x - bullet.texture.width / 2, .y = self.y };
        bullet.velocity = .{ .x = if (self.facingLeft) -0.5 else 0.5 };

        scene.gameScene.bullets.append(bullet) catch unreachable;
    }

    pub fn vectorIn(self: Player, vector: Vector) bool {
        if (vector.x < self.x or vector.x > self.x + self.width) return false;
        if (vector.y < self.y or vector.y > self.y + self.height) return false;
        return true;
    }
};
