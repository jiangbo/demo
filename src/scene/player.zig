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
    p1: bool = true,

    attackTimer: window.Timer = .init(attackInterval),
    attackExTimer: window.Timer = .init(2500),

    hp: u32 = 100,
    mp: u32 = 100,

    animationIdle: gfx.FrameAnimation = undefined,
    animationRun: gfx.FrameAnimation = undefined,
    animationAttack: gfx.FrameAnimation = undefined,
    animationSunText: gfx.FrameAnimation = undefined,

    const runVelocity: f32 = 0.55;
    const gravity: f32 = 1.6e-3;
    const jumpVelocity: f32 = -0.85;
    const attackInterval: f32 = 500;
    const attackIntervalEx: f32 = 100;

    pub fn init(playerType: scene.PlayerType, x: f32, y: f32, faceLeft: bool) Player {
        var self: Player = .{ .x = x, .y = y, .facingLeft = faceLeft };
        self.attackExTimer.finished = true;
        if (playerType == .peaShooter) {
            self.animationIdle = .load("assets/peashooter_idle_{}.png", 9);
            self.animationRun = .load("assets/peashooter_run_{}.png", 5);
            self.animationAttack = .load("assets/peashooter_attack_ex_{}.png", 3);
        } else {
            self.animationIdle = .load("assets/sunflower_idle_{}.png", 8);
            self.animationRun = .load("assets/sunflower_run_{}.png", 5);
            self.animationAttack = .load("assets/sunflower_attack_ex_{}.png", 9);
            self.animationSunText = .load("assets/sun_text_{}.png", 5);
        }

        return self;
    }

    pub fn event(self: *Player, ev: *const window.Event) void {
        if (self.attackExTimer.isRun() and ev.type == .KEY_DOWN) return;

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
                .F, .PERIOD => self.attack(),
                .G, .SLASH => self.attackEx(),
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
        self.attackTimer.update(delta);

        if (self.attackExTimer.isRun()) {
            self.animationAttack.update(delta);
            self.attackExTimer.update(delta);
            if (self.attackExTimer.finished) {
                self.attackTimer.duration = attackInterval;
            } else if (self.attackTimer.finished) {
                const bullet = self.spawnBullet();
                scene.gameScene.bullets.append(bullet) catch unreachable;
            }
            return;
        }

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
        if (self.attackExTimer.isRun()) {
            self.animationAttack.playFlipX(self.x, self.y, self.facingLeft);
        } else if (self.leftKeyDown) {
            self.animationRun.playFlipX(self.x, self.y, true);
        } else if (self.rightKeyDown) {
            self.animationRun.playFlipX(self.x, self.y, false);
        } else {
            self.animationIdle.playFlipX(self.x, self.y, self.facingLeft);
        }
    }

    pub fn attack(self: *Player) void {
        if (self.attackTimer.isRun()) return;

        var bullet = self.spawnBullet();
        bullet.playShootSound();

        scene.gameScene.bullets.append(bullet) catch unreachable;
    }

    fn spawnBullet(self: *Player) Bullet {
        self.attackTimer.reset();

        var bullet = Bullet.init(self.p1);

        const x: f32 = if (self.facingLeft) self.x else self.x + self.width;
        bullet.position = .{ .x = x - bullet.texture.width / 2, .y = self.y };
        if (self.facingLeft) bullet.velocity.x = -bullet.velocity.x;

        return bullet;
    }

    pub fn attackEx(self: *Player) void {
        if (self.mp < 100) return;

        const playerType = if (self.p1) scene.playerType1 else scene.playerType2;

        if (playerType == .peaShooter) {
            self.attackExTimer.reset();
            self.attackTimer.duration = attackIntervalEx;
        } else {
            var bullet = Bullet.initSunBulletEx();
            const player = if (self.p1)
                scene.gameScene.player2
            else
                scene.gameScene.player1;
            bullet.p1 = self.p1;
            bullet.position.x = player.x + player.width / 2 - bullet.texture.width / 2;
            scene.gameScene.bullets.append(bullet) catch unreachable;
        }

        Bullet.playShootExSound(playerType);
        // self.mp = 0;
    }

    pub fn collide(self: *Player, bullet: *Bullet) bool {
        if (bullet.type != .sunEx) {
            const pos = bullet.center();
            if (pos.x < self.x or pos.x > self.x + self.width) return false;
            if (pos.y < self.y or pos.y > self.y + self.height) return false;
            return true;
        }

        if (self.x < bullet.position.x) return false;
        if (self.x + self.width > bullet.position.x + bullet.texture.width) return false;
        if (self.y < bullet.position.y) return false;
        if (self.y + self.height > bullet.position.y + bullet.texture.height) return false;
        return true;
    }
};
