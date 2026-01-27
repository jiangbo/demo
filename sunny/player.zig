const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const map = @import("map.zig");

const moveForce = 200; // 移动力
const factor = 0.85; // 减速因子
const maxSpeed = 120; // 最大速度
const gravity = 980; // 重力
const jumpSpeed = 350.0; // 跳跃速度
const hurtVelocity: zhu.Vector2 = .xy(-100, -150);

const imageSize: zhu.Vector2 = .xy(32, 32);
var viewSize: zhu.Vector2 = undefined;
var tile: tiled.Tile = undefined;
var tiledObject: tiled.Object = undefined;
var image: zhu.graphics.Image = undefined;

var force: zhu.Vector2 = .xy(0, gravity);
var velocity: zhu.Vector2 = .zero;
pub var position: zhu.Vector2 = undefined;
var state: State = .idle;
var flip: bool = false;

const maxHealth: u8 = 3;
var health: u8 = maxHealth;

pub fn init(pos: zhu.Vector2, size: zhu.Vector2) void {
    position = pos;
    viewSize = size;
    const imageId = zhu.imageId("textures/Actors/foxy.png");
    tile = tiled.getTileByImageId(imageId);
    tiledObject = tile.objectGroup.?.objects[0];

    image = zhu.assets.getImage(imageId).sub(.init(.zero, imageSize));
    inline for (std.meta.fields(State)) |field| field.type.init();

    state.enter();
}

pub fn update(delta: f32) void {
    state.update(delta);

    velocity = velocity.add(force.scale(delta));
    velocity.x = std.math.clamp(velocity.x, -maxSpeed, maxSpeed);
    const toPosition = position.add(velocity.scale(delta));

    if (state == .dead) position = toPosition else {
        const clamped = map.clamp(position, toPosition, viewSize);
        // std.log.info("old: {}, new: {}, clamped: {}", .{ position, toPosition, clamped });
        if (clamped.x == position.x) velocity.x = 0;
        if (clamped.y == position.y) velocity.y = 0;
        position = clamped;
    }

    batch.camera.directFollow(position);
    batch.camera.position = batch.camera.position.round();

    // 模拟受伤
    if (zhu.window.isKeyPress(.K)) {
        health -|= 1;
        if (health == 0) {
            changeState(.dead);
        } else {
            changeState(.hurt);
        }
    }
}

pub fn collideRect() zhu.Rect {
    const pos = position.add(tiledObject.position);
    return .init(pos, tiledObject.size);
}

pub fn draw() void {
    state.draw();
    // 绘制角色的碰撞框
    const pos = position.add(tiledObject.position);
    batch.drawRect(.init(pos, tiledObject.size), .{
        .color = .rgba(0, 1, 0, 0.4),
    });
}

pub fn drawPlayer(img: zhu.graphics.Image) void {
    batch.drawImage(img, position, .{ .flipX = flip, .size = viewSize });
}

const State = union(enum) {
    idle: IdleState,
    walk: WalkState,
    jump: JumpState,
    fall: FallState,
    hurt: HurtState,
    dead: DeadState,

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
    var animation: zhu.graphics.FrameAnimation = undefined;
    const frames = zhu.graphics.loopFramesX(4, imageSize, 0.2);

    pub fn init() void {
        const idleImage = image.sub(.init(.zero, .xy(32, 128)));
        animation = .init(idleImage, &frames);
    }

    fn enter() void {
        std.log.info("enter idle", .{});
        force.x = 0; // 停止水平受力
    }

    fn update(delta: f32) void {
        animation.loopUpdate(delta);
        if (zhu.window.isAnyKeyPress(&.{ .W, .SPACE })) {
            changeState(.jump);
        } else if (zhu.window.isAnyKeyDown(&.{ .A, .D })) {
            changeState(.walk);
        } else velocity.x *= factor; // 减速
    }

    fn draw() void {
        drawPlayer(animation.currentImage());
    }
};

const WalkState = struct {
    var animation: zhu.graphics.FrameAnimation = undefined;
    const frames = zhu.graphics.loopFramesX(6, imageSize, 0.1);

    pub fn init() void {
        const walkImage = image.sub(.init(.xy(0, 32), .xy(32, 198)));
        animation = .init(walkImage, &frames);
    }

    fn enter() void {
        std.log.info("enter walk", .{});
    }

    fn update(delta: f32) void {
        animation.loopUpdate(delta);

        if (zhu.window.isAnyKeyPress(&.{ .W, .SPACE })) {
            changeState(.jump);
        } else if (zhu.window.isKeyDown(.A)) {
            if (velocity.x > 0) velocity.x = 0;
            force.x = -moveForce;
            flip = true;
        } else if (zhu.window.isKeyDown(.D)) {
            if (velocity.x < 0) velocity.x = 0;
            force.x = moveForce;
            flip = false;
        } else {
            changeState(.idle);
        }
    }

    fn draw() void {
        drawPlayer(animation.currentImage());
    }
};
const JumpState = struct {
    var jumpImage: zhu.graphics.Image = undefined;

    pub fn init() void {
        jumpImage = image.sub(.init(.xy(0, 160), imageSize));
    }

    fn enter() void {
        std.log.info("enter jump", .{});
        velocity.y = -jumpSpeed;
    }

    fn update(_: f32) void {
        if (velocity.y > 0) {
            changeState(.fall);
        }
    }

    fn draw() void {
        drawPlayer(jumpImage);
    }
};
const FallState = struct {
    var fallImage: zhu.graphics.Image = undefined;

    pub fn init() void {
        fallImage = image.sub(.init(.xy(32, 160), imageSize));
    }

    fn enter() void {
        std.log.info("enter fall", .{});
    }

    fn update(_: f32) void {
        if (velocity.y == 0) {
            changeState(.idle);
        }
    }

    fn draw() void {
        drawPlayer(fallImage);
    }
};

const HurtState = struct {
    var animation: zhu.graphics.FrameAnimation = undefined;
    const frames = zhu.graphics.framesX(2, imageSize, 0.1);
    var timer: zhu.Timer = .init(0.4);

    pub fn init() void {
        const hurtImage = image.sub(.init(.xy(0, 128), .xy(64, 32)));
        animation = .init(hurtImage, &frames);
    }

    fn enter() void {
        std.log.info("enter hurt", .{});
        var vel = hurtVelocity;
        if (flip) vel.x = -vel.x;
        velocity = .xy(vel.x, velocity.y + vel.y);
        timer.elapsed = 0; // 重置计时器
    }

    fn update(delta: f32) void {
        animation.loopUpdate(delta);

        if (velocity.y == 0) {
            changeState(.idle);
        } else if (timer.isFinishedOnceUpdate(delta)) {
            changeState(.fall);
        }
    }

    fn draw() void {
        drawPlayer(animation.currentImage());
    }
};

const DeadState = struct {
    var animation: zhu.graphics.FrameAnimation = undefined;
    const frames = zhu.graphics.framesX(2, imageSize, 0.1);

    pub fn init() void {
        const hurtImage = image.sub(.init(.xy(0, 128), .xy(64, 32)));
        animation = .init(hurtImage, &frames);
    }

    fn enter() void {
        std.log.info("enter dead", .{});
        velocity = .xy(0, -200);
    }

    fn update(delta: f32) void {
        animation.loopUpdate(delta);
    }

    fn draw() void {
        drawPlayer(animation.currentImage());
    }
};
