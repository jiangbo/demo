const std = @import("std");
const zhu = @import("zhu");

const tiled = zhu.extend.tiled;

const map = @import("map.zig");

const moveForce = 200; // 移动力
const factor = 0.85; // 减速因子
const maxSpeed = 120; // 最大速度
const gravity = 980; // 重力

const size: zhu.Vector2 = .xy(32, 32);
var image: zhu.graphics.Image = undefined;

var force: zhu.Vector2 = .xy(0, gravity);
var velocity: zhu.Vector2 = .zero;
pub var position: zhu.Vector2 = undefined;
var state: State = .idle;

pub fn init(pos: zhu.Vector2) void {
    position = pos;
    const foxy = zhu.getImage("textures/Actors/foxy.png");
    image = foxy.sub(.init(.zero, size));
    state.enter();
}

pub fn update(delta: f32) void {
    state.update(delta);

    velocity = velocity.add(force.scale(delta));
    velocity.x = std.math.clamp(velocity.x, -maxSpeed, maxSpeed);
    const toPosition = position.add(velocity.scale(delta));

    const clamped = map.clamp(position, toPosition, size);
    std.log.info("old: {}, new: {}, clamped: {}", .{ position, toPosition, clamped });
    if (clamped.x == position.x) velocity.x = 0;
    if (clamped.y == position.y) velocity.y = 0;
    position = clamped;
}

pub fn draw() void {
    zhu.batch.drawImage(image, position, .{
        .flipX = velocity.x < 0,
    });
}

const State = union(enum) {
    idle: IdleState,
    walk: WalkState,
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

fn changeState(newState: State) void {
    state = newState;
    state.enter();
}

const IdleState = struct {
    fn enter() void {
        std.log.info("enter idle", .{});
    }

    fn update(_: f32) void {
        if (zhu.window.isAnyKeyDown(&.{ .A, .D })) {
            changeState(.walk);
        } else velocity.x *= factor; // 减速
    }
};

const WalkState = struct {
    fn enter() void {
        std.log.info("enter walk", .{});
    }

    fn update(_: f32) void {
        if (zhu.window.isKeyDown(.A)) {
            if (velocity.x > 0) velocity.x = 0;
            force.x = -moveForce;
        } else if (zhu.window.isKeyDown(.D)) {
            if (velocity.x < 0) velocity.x = 0;
            force.x = moveForce;
        } else {
            force.x = 0;
            changeState(.idle);
        }
    }
};
const JumpState = struct {};
const FallState = struct {};
