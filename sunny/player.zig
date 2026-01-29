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
pub var velocity: zhu.Vector2 = .zero;
pub var position: zhu.Vector2 = undefined;
pub var state: State = .idle;
var flip: bool = false;

const maxHealth: u8 = 3;
var health: u8 = maxHealth;
var hurtTimer: zhu.Timer = .init(2.0); // 受伤的间隔时间

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
    hurtTimer.update(delta);
    state.update(delta);

    velocity = velocity.add(force.scale(delta));
    velocity.x = std.math.clamp(velocity.x, -maxSpeed, maxSpeed);
    var toPosition = position.add(velocity.scale(delta));
    // 角色不移动到屏幕外
    const max = batch.camera.bound.x - tiledObject.size.x;
    toPosition.x = std.math.clamp(toPosition.x, 0, max);

    if (state == .dead) position = toPosition else {
        const size = tiledObject.size;
        const onTop = map.isTopLadder(toPosition, size);
        if (state != .climb and onTop) {
            velocity.y = 0;
            position = .xy(toPosition.x, position.y);
            const canClimb = map.canClimb(toPosition, size);
            if (zhu.window.isKeyDown(.S) and canClimb) {
                changeState(.climb);
                position = toPosition;
            }
        } else {
            const clamped = map.clamp(position, toPosition, size);
            if (clamped.x == position.x) velocity.x = 0;
            if (clamped.y == position.y) velocity.y = 0;
            position = clamped;
        }
    }
    if (state == .climb) {
        if (toPosition.y > position.y) changeState(.idle);
        velocity = .zero;
    } else force.y = gravity;

    batch.camera.directFollow(position);
    batch.camera.position = batch.camera.position.round();
}

pub fn collideRect() zhu.Rect {
    return .init(position, tiledObject.size);
}

pub fn hurt() void {
    if (hurtTimer.isRunning()) return; // 受伤间隔时间内，忽略伤害
    health -|= 1;
    hurtTimer.elapsed = 0; // 重置计时器
    if (health == 0) changeState(.dead) else changeState(.hurt);
}

pub fn draw() void {
    state.draw();
}

pub fn drawPlayer(img: zhu.graphics.Image) void {
    const pos = position.sub(tiledObject.position);
    batch.drawImage(img, pos, .{ .flipX = flip, .size = viewSize });
}

const State = union(enum) {
    idle: IdleState,
    walk: WalkState,
    jump: JumpState,
    fall: FallState,
    hurt: HurtState,
    dead: DeadState,
    climb: ClimbState,

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
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.loopFramesX(4, imageSize, 0.2);

    pub fn init() void {
        const idleImage = image.sub(.init(.zero, .xy(32, 128)));
        animation = .init(idleImage, &frames);
    }

    fn enter() void {
        std.log.info("enter idle", .{});
        force.x = 0;
    }

    fn update(delta: f32) void {
        animation.loopUpdate(delta);

        if (map.isTouchLadder(position, tiledObject.size) and
            zhu.window.isKeyDown(.W))
        {
            changeState(.climb);
        }
        if (zhu.window.isKeyPressed(.SPACE)) {
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
    var animation: zhu.graphics.Animation = undefined;
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
        force.x = 0;

        if (velocity.y > 0) return changeState(.fall);

        if (zhu.window.isAnyKeyPressed(&.{ .W, .SPACE })) {
            changeState(.jump);
        }

        if (zhu.window.isKeyDown(.A)) {
            force.x = -moveForce;
            flip = true;
        } else if (zhu.window.isKeyDown(.D)) {
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
    var animation: zhu.graphics.Animation = undefined;
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
    var animation: zhu.graphics.Animation = undefined;
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

const ClimbState = struct {
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.loopFramesX(4, imageSize, 0.1);
    const speed = 100;

    pub fn init() void {
        const climbImage = image.sub(.init(.xy(0, 64), .xy(128, 32)));
        animation = .init(climbImage, &frames);
    }

    fn enter() void {
        std.log.info("enter climb", .{});
        velocity = .zero;
        force = .zero;
    }

    fn update(delta: f32) void {
        if (zhu.window.isKeyDown(.W)) {
            velocity.y = -speed;
        } else if (zhu.window.isKeyDown(.S)) {
            velocity.y = speed;
        } else if (zhu.window.isKeyDown(.A)) {
            velocity.x = -speed;
        } else if (zhu.window.isKeyDown(.D)) {
            velocity.x = speed;
        } else velocity = .zero;

        if (velocity.x != 0 or velocity.y != 0) {
            animation.loopUpdate(delta);
        }

        if (!map.isTouchLadder(position, tiledObject.size)) {
            changeState(.fall);
        }
    }

    fn draw() void {
        drawPlayer(animation.currentImage());
    }
};
