const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const scene = @import("../scene.zig");
const SharedActor = @import("actor.zig").SharedActor;

const Enemy = @This();

shared: SharedActor,
state: State = .idle,

idleTimer: window.Timer = .init(0.5),
idleAnimation: gfx.SliceFrameAnimation,

pub fn init() Enemy {
    var enemy: Enemy = .{
        .shared = .{
            .position = .{ .x = 700, .y = SharedActor.FLOOR_Y },
            .faceLeft = true,
            .health = 10,
        },
        .idleAnimation = .load("assets/enemy/idle/{}.png", 5),
    };

    enemy.state.enter(&enemy);
    return enemy;
}

pub fn update(self: *Enemy, delta: f32) void {
    self.shared.update(delta);
    self.state.update(self, delta);
}

pub fn render(self: *const Enemy) void {
    self.shared.render();
    self.state.render(self);
}

fn changeState(self: *Enemy, new: State) void {
    self.state.exit(self);
    new.enter(self);
}

fn play(self: *const Enemy, animation: *const gfx.SliceFrameAnimation) void {
    gfx.playSliceFlipX(animation, self.shared.position, !self.shared.faceLeft);
}

const State = union(enum) {
    idle: IdleState,

    fn enter(self: State, enemy: *Enemy) void {
        switch (self) {
            inline else => |case| @TypeOf(case).enter(enemy),
        }
    }

    fn update(self: State, enemy: *Enemy, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(enemy, delta),
        }
    }

    fn render(self: State, enemy: *const Enemy) void {
        switch (self) {
            inline else => |case| @TypeOf(case).render(enemy),
        }
    }

    fn exit(self: State, enemy: *Enemy) void {
        switch (self) {
            inline else => |case| @TypeOf(case).exit(enemy),
        }
    }
};

const IdleState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .idle;
        enemy.shared.velocity.x = 0;

        const max: f32 = if (enemy.shared.health > 5) 0.5 else 0.25;
        enemy.idleTimer.duration = window.randomFloat(0, max);
        enemy.idleTimer.reset();
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.idleAnimation.update(delta);
        if (enemy.idleTimer.isRunningAfterUpdate(delta)) return;

        enemy.changeState(.idle);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.idleAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.idleAnimation.reset();
        const playerPosition = scene.player.shared.position;
        enemy.shared.faceLeft = playerPosition.x < enemy.shared.position.x;
    }
};
