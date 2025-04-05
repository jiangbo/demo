const std = @import("std");

const gfx = @import("graphics.zig");
const math = @import("math.zig");
const window = @import("window.zig");

const sharedPlayer = struct {
    const floorY = 620;
    const gravity = 980;

    enableGravity: bool = true,
    position: math.Vector = .{ .x = 100, .y = floorY },
    velocity: math.Vector = .{},
    idleAnimation: gfx.AtlasFrameAnimation = undefined,
    runAnimation: gfx.AtlasFrameAnimation = undefined,
    faceLeft: bool = false,
    running: bool = false,

    pub fn update(self: *sharedPlayer, delta: f32) void {
        if (self.enableGravity) {
            self.velocity.y += gravity * delta;
        }

        self.position = self.position.add(self.velocity.scale(delta));
        if (self.position.y >= floorY) {
            self.position.y = floorY;
            self.velocity.y = 0;
        }

        self.position.x = std.math.clamp(self.position.x, 0, window.width);
        if (self.running) {
            self.runAnimation.update(delta);
        } else {
            self.idleAnimation.update(delta);
        }
    }

    pub fn render(self: *const sharedPlayer) void {
        if (self.running) {
            gfx.playAtlasFlipX(&self.runAnimation, self.position, self.faceLeft);
        } else {
            gfx.playAtlasFlipX(&self.idleAnimation, self.position, self.faceLeft);
        }
    }
};

pub const Player = struct {
    shared: sharedPlayer,

    pub fn init() Player {
        return .{
            .shared = .{
                .idleAnimation = .load("assets/player/idle.png", 5),
                .runAnimation = .load("assets/player/run.png", 10),
            },
        };
    }

    pub fn deinit() void {}

    pub fn event(self: *Player, ev: *const window.Event) void {
        if (ev.type == .KEY_DOWN) {
            switch (ev.key_code) {
                .A => {
                    self.shared.velocity.x = -300;
                    self.shared.faceLeft = true;
                    self.shared.running = true;
                },
                .D => {
                    self.shared.velocity.x = 300;
                    self.shared.faceLeft = false;
                    self.shared.running = true;
                },
                .W => {
                    if (self.shared.velocity.y != 0) return;
                    self.shared.velocity.y -= 780;
                },
                else => {},
            }
        } else if (ev.type == .KEY_UP) {
            switch (ev.key_code) {
                .A, .D => {
                    self.shared.velocity.x = 0;
                    self.shared.running = false;
                },
                else => {},
            }
        }
    }

    pub fn update(self: *Player, delta: f32) void {
        self.shared.update(delta);
    }

    pub fn render(self: *const Player) void {
        self.shared.render();
    }
};
