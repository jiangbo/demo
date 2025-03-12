const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");

pub const Player = union(scene.PlayerType) {
    peaShooter: PeaShooterPlayer,
    sunFlower: SunFlowerPlayer,

    pub fn init(playerType: scene.PlayerType, x: f32, y: f32, faceLeft: bool) Player {
        return switch (playerType) {
            .peaShooter => .{ .peaShooter = .init(x, y, faceLeft) },
            .sunFlower => .{ .sunFlower = .init(x, y, faceLeft) },
        };
    }

    pub fn event(self: *Player, ev: *const window.Event) void {
        switch (self.*) {
            inline else => |*s| switch (ev.type) {
                .KEY_DOWN => switch (ev.key_code) {
                    .A, .LEFT => {
                        s.shared.leftKeyDown = true;
                        s.shared.facingLeft = true;
                    },
                    .D, .RIGHT => {
                        s.shared.rightKeyDown = true;
                        s.shared.facingLeft = false;
                    },
                    .W, .UP => {
                        if (s.shared.velocity != 0) return;
                        s.shared.velocity += SharedPlayer.jumpVelocity;
                    },
                    else => {},
                },
                .KEY_UP => switch (ev.key_code) {
                    .A, .LEFT => s.shared.leftKeyDown = false,
                    .D, .RIGHT => s.shared.rightKeyDown = false,
                    else => {},
                },
                else => {},
            },
        }
    }

    pub fn update(self: *Player, delta: f32) void {
        switch (self.*) {
            inline else => |*player| {
                var direction: f32 = 0;
                if (player.shared.leftKeyDown) direction -= 1;
                if (player.shared.rightKeyDown) direction += 1;
                player.shared.x += direction * SharedPlayer.runVelocity * delta;

                if (player.shared.leftKeyDown or player.shared.rightKeyDown) {
                    player.animationRun.update(delta);
                } else {
                    player.animationIdle.update(delta);
                }

                moveAndCollide(&player.shared, delta);
            },
        }
    }

    fn moveAndCollide(player: anytype, delta: f32) void {
        const velocity = player.velocity + SharedPlayer.gravity * delta;
        const y = player.y + velocity * delta;

        const platforms = &scene.gameScene.platforms;
        for (platforms) |*platform| {
            if (player.x + player.width < platform.shape.left) continue;
            if (player.x > platform.shape.right) continue;
            if (y + player.height < platform.shape.y) continue;

            const deltaPosY = player.velocity * delta;
            const lastFootPosY = player.y + player.height - deltaPosY;

            if (lastFootPosY <= platform.shape.y) {
                player.y = platform.shape.y - player.height;
                player.velocity = 0;
                break;
            }
        } else {
            player.y = y;
            player.velocity = velocity;
        }
    }

    pub fn draw(self: Player) void {
        switch (self) {
            inline else => |*s| {
                if (s.shared.leftKeyDown) {
                    s.animationRun.playFlipX(s.shared.x, s.shared.y, true);
                } else if (s.shared.rightKeyDown) {
                    s.animationRun.playFlipX(s.shared.x, s.shared.y, false);
                } else {
                    s.animationIdle.playFlipX(s.shared.x, s.shared.y, s.shared.facingLeft);
                }
            },
        }
    }
};

const SharedPlayer = struct {
    x: f32,
    y: f32,
    facingLeft: bool,
    leftKeyDown: bool = false,
    rightKeyDown: bool = false,
    velocity: f32 = 0,
    width: f32 = 96,
    height: f32 = 96,

    const runVelocity: f32 = 0.55;
    const gravity: f32 = 1.6e-3;
    const jumpVelocity: f32 = -0.85;
};

const PeaShooterPlayer = struct {
    shared: SharedPlayer,

    animationIdle: gfx.BoundedFrameAnimation(9),
    animationRun: gfx.BoundedFrameAnimation(5),

    pub fn init(x: f32, y: f32, faceLeft: bool) PeaShooterPlayer {
        return .{
            .shared = .{ .x = x, .y = y, .facingLeft = faceLeft },
            .animationIdle = .init("assets/peashooter_idle_{}.png"),
            .animationRun = .init("assets/peashooter_run_{}.png"),
        };
    }
};

const SunFlowerPlayer = struct {
    shared: SharedPlayer,

    animationIdle: gfx.BoundedFrameAnimation(8),
    animationRun: gfx.BoundedFrameAnimation(5),

    pub fn init(x: f32, y: f32, faceLeft: bool) SunFlowerPlayer {
        return .{
            .shared = .{ .x = x, .y = y, .facingLeft = faceLeft },
            .animationIdle = .init("assets/sunflower_idle_{}.png"),
            .animationRun = .init("assets/sunflower_run_{}.png"),
        };
    }
};
