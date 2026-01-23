const std = @import("std");
const zhu = @import("zhu");

const moveForce = 200; // 移动力
const factor = 0.85; // 减速因子
const maxSpeed = 120; // 最大速度

const size: zhu.Vector2 = .xy(32, 32);
var image: zhu.graphics.Image = undefined;

var velocity: zhu.Vector2 = .zero;
var position: zhu.Vector2 = undefined;
var state: State = .idle;

pub fn init(pos: zhu.Vector2) void {
    position = pos;
    const foxy = zhu.getImage("textures/Actors/foxy.png");
    image = foxy.sub(.init(.zero, size));
    state.enter();
}

pub fn update(delta: f32) void {
    state.update(delta);
}

pub fn draw() void {
    zhu.batch.drawImage(image, position, .{
        .flipX = velocity.x < 0,
    });
}

const State = union(enum) {
    idle: IdleState,
    // walk: WalkState,
    // jump: JumpState,
    // fall: FallState,

    fn enter(self: State) void {
        switch (self) {
            inline else => |case| @TypeOf(case).enter(),
        }
    }

    fn update(self: State, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    fn draw(self: State) void {
        switch (self) {
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};

const IdleState = struct {
    fn enter() void {
        std.log.info("enter idle", .{});
    }

    fn update(delta: f32) void {
        if (zhu.window.isKeyDown(.A)) {
            if (velocity.x > 0) velocity.x = 0;
            velocity.x -= moveForce * delta;
        } else if (zhu.window.isKeyDown(.D)) {
            if (velocity.x < 0) velocity.x = 0;
            velocity.x += moveForce * delta;
        } else {
            // 没有按的时候，减少速度
            velocity.x *= factor;
        }

        velocity.x = std.math.clamp(velocity.x, -maxSpeed, maxSpeed);
        position = position.add(velocity.scale(delta));
    }
};

const WalkState = struct {};
const JumpState = struct {};
const FallState = struct {};
