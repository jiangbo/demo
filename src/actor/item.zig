const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const scene = @import("../scene.zig");
const SharedActor = @import("actor.zig").SharedActor;

pub const Sword = struct {
    const SPEED_MOVE = 1250;

    position: math.Vector,
    moveLeft: bool,
    valid: bool = true,
    animation: gfx.SliceFrameAnimation,

    pub fn init(pos: math.Vector, moveLeft: bool) Sword {
        var self: Sword = .{
            .position = pos,
            .moveLeft = moveLeft,
            .animation = .load("assets/enemy/sword/{}.png", 3),
        };

        self.animation.anchor = .centerCenter;
        return self;
    }

    pub fn update(self: *Sword, delta: f32) void {
        self.animation.update(delta);

        const direction: f32 = if (self.moveLeft) -1 else 1;
        self.position.x += direction * SPEED_MOVE * delta;

        if (self.position.x < -200 or self.position.x > window.width + 200) {
            self.valid = false;
        }
    }

    pub fn render(self: *const Sword) void {
        gfx.playSliceFlipX(&self.animation, self.position, self.moveLeft);
    }
};

pub const Barb = struct {
    const SPEED_DASH = 1500;

    const State = enum { idle, aim, dash, death };

    basePosition: math.Vector,
    position: math.Vector,
    velocity: math.Vector = .zero,
    valid: bool = true,

    idleTimer: window.Timer = undefined,
    aimTimer: window.Timer = .init(0.75),
    totalTime: f32 = 0,
    diffPeriod: f32 = 0,

    looseAnimation: gfx.SliceFrameAnimation,
    deathAnimation: gfx.SliceFrameAnimation,
    state: State = .idle,

    pub fn init(pos: math.Vector) Barb {
        var self: Barb = .{
            .basePosition = pos,
            .position = pos,
            .diffPeriod = window.randomFloat(0, 6),
            .looseAnimation = .load("assets/enemy/barb_loose/{}.png", 5),
            .deathAnimation = .load("assets/enemy/barb_break/{}.png", 3),
        };

        self.looseAnimation.timer.duration = 0.15;
        self.looseAnimation.anchor = .centerCenter;

        self.deathAnimation.loop = false;
        self.deathAnimation.anchor = .centerCenter;

        self.idleTimer = .init(window.randomFloat(3, 10));

        return self;
    }

    pub fn update(self: *Barb, delta: f32) void {
        self.looseAnimation.update(delta);
        self.totalTime += delta;

        switch (self.state) {
            .idle => {
                const offsetY = 30 * @sin(self.totalTime * 2 + self.diffPeriod);
                self.position.y = self.basePosition.y + offsetY;
                if (self.idleTimer.isFinishedAfterUpdate(delta)) {
                    self.state = .aim;
                }
            },
            .aim => {
                const offsetX = window.randomFloat(-10, 10);
                self.position.x = self.basePosition.x + offsetX;
                if (self.aimTimer.isFinishedAfterUpdate(delta)) {
                    self.state = .dash;
                    const direction = scene.player.shared.position.sub(self.position);
                    self.velocity = direction.normalize().scale(SPEED_DASH);
                }
            },
            .dash => {
                self.position = self.position.add(self.velocity.scale(delta));
                if (self.position.y > SharedActor.FLOOR_Y) {
                    self.state = .death;
                    self.velocity = .zero;
                    self.position.y = SharedActor.FLOOR_Y;
                }
            },
            .death => {
                self.deathAnimation.update(delta);
                if (self.deathAnimation.finished()) {
                    self.valid = false;
                }
            },
        }
    }

    pub fn render(self: *const Barb) void {
        if (self.state == .death) {
            gfx.playSlice(&self.deathAnimation, self.position);
        } else {
            gfx.playSlice(&self.looseAnimation, self.position);
        }
    }
};
