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
                        s.leftKeyDown = true;
                        s.facingLeft = true;
                    },
                    .D, .RIGHT => {
                        s.rightKeyDown = true;
                        s.facingLeft = false;
                    },
                    else => {},
                },
                .KEY_UP => switch (ev.key_code) {
                    .A, .LEFT => s.leftKeyDown = false,
                    .D, .RIGHT => s.rightKeyDown = false,
                    else => {},
                },
                else => {},
            },
        }
    }

    pub fn update(self: *Player, delta: f32) void {
        switch (self.*) {
            inline else => |*s| s.animationIdle.update(delta),
        }
    }

    pub fn draw(self: Player) void {
        switch (self) {
            inline else => |*s| s.animationIdle.playFlipX(s.x, s.y, s.facingLeft),
        }
    }
};

const PeaShooterPlayer = struct {
    x: f32,
    y: f32,
    facingLeft: bool = false,
    leftKeyDown: bool = false,
    rightKeyDown: bool = false,

    animationIdle: gfx.BoundedFrameAnimation(9),

    pub fn init(x: f32, y: f32, faceLeft: bool) PeaShooterPlayer {
        return .{
            .x = x,
            .y = y,
            .facingLeft = faceLeft,
            .animationIdle = .init("assets/peashooter_idle_{}.png"),
        };
    }
};

const SunFlowerPlayer = struct {
    x: f32,
    y: f32,
    facingLeft: bool,
    leftKeyDown: bool = false,
    rightKeyDown: bool = false,

    animationIdle: gfx.BoundedFrameAnimation(8),

    pub fn init(x: f32, y: f32, faceLeft: bool) SunFlowerPlayer {
        return .{
            .x = x,
            .y = y,
            .facingLeft = faceLeft,
            .animationIdle = .init("assets/sunflower_idle_{}.png"),
        };
    }
};
