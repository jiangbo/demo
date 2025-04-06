const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const SharedActor = @import("actor.zig").SharedActor;

const Player = @This();

shared: SharedActor,

state: State,
leftKeyDown: bool = false,
rightKeyDown: bool = false,
jumpKeyDown: bool = false,

idleAnimation: gfx.AtlasFrameAnimation,
runAnimation: gfx.AtlasFrameAnimation,
jumpAnimation: gfx.AtlasFrameAnimation,
fallAnimation: gfx.AtlasFrameAnimation,

rollKeyDown: bool = false,
rollAnimation: gfx.AtlasFrameAnimation,
rollTimer: window.Timer = .init(0.35),
rollCoolDown: window.Timer = .init(0.75),

attackKeyDown: bool = false,
attackAnimation: gfx.AtlasFrameAnimation,
attackLeft: gfx.AtlasFrameAnimation,
attackRight: gfx.AtlasFrameAnimation,
attackTimer: window.Timer = .init(0.3),
attackCoolDown: window.Timer = .init(0.5),

deadTimer: window.Timer = .init(0.5),

pub fn init() Player {
    var player: Player = .{
        .shared = .{
            .position = .{ .x = 100, .y = SharedActor.FLOOR_Y },
        },
        .idleAnimation = .load("assets/player/idle.png", 5),
        .runAnimation = .load("assets/player/run.png", 10),
        .jumpAnimation = .load("assets/player/jump.png", 5),
        .fallAnimation = .load("assets/player/fall.png", 5),

        .state = .idle,
        .rollAnimation = .load("assets/player/roll.png", 7),
        .attackAnimation = .load("assets/player/attack.png", 5),
        .attackLeft = .load("assets/player/vfx_attack_left.png", 5),
        .attackRight = .load("assets/player/vfx_attack_right.png", 5),
    };

    player.rollAnimation.loop = false;
    player.rollAnimation.timer = .init(0.005);
    player.attackAnimation.loop = false;
    player.attackAnimation.timer = .init(0.05);
    player.attackLeft.loop = false;
    player.attackLeft.timer = .init(0.05);
    player.attackRight.loop = false;
    player.attackRight.timer = .init(0.05);
    return player;
}

pub fn deinit() void {}

pub fn event(self: *Player, ev: *const window.Event) void {
    if (ev.type == .KEY_DOWN) {
        switch (ev.key_code) {
            .A => self.leftKeyDown = true,
            .D => self.rightKeyDown = true,
            .W => self.jumpKeyDown = true,
            .F => self.attackKeyDown = true,
            .SPACE => self.rollKeyDown = true,
            else => {},
        }
    } else if (ev.type == .KEY_UP) {
        switch (ev.key_code) {
            .A => self.leftKeyDown = false,
            .D => self.rightKeyDown = false,
            .W => self.jumpKeyDown = false,
            .F => self.attackKeyDown = false,
            .SPACE => self.rollKeyDown = false,
            else => {},
        }
    }
}

pub fn update(self: *Player, delta: f32) void {
    self.rollCoolDown.update(delta);
    self.attackCoolDown.update(delta);
    self.shared.update(delta);
    self.state.update(self, delta);
}

pub fn render(self: *const Player) void {
    self.shared.render();
    self.state.render(self);
}

fn changeState(self: *Player, new: State) void {
    self.state.exit(self);
    new.enter(self);
}

fn play(self: *const Player, animation: *const gfx.AtlasFrameAnimation) void {
    gfx.playAtlasFlipX(animation, self.shared.position, self.shared.faceLeft);
}

const State = union(enum) {
    idle: IdleState,
    run: RunState,
    jump: JumpState,
    fall: FallState,
    roll: RollState,
    attack: AttackState,
    // dead: DeadState,

    fn enter(self: State, player: *Player) void {
        switch (self) {
            inline else => |case| @TypeOf(case).enter(player),
        }
    }

    fn update(self: State, player: *Player, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(player, delta),
        }
    }

    fn render(self: State, player: *const Player) void {
        switch (self) {
            inline else => |case| @TypeOf(case).render(player),
        }
    }

    fn exit(self: State, player: *Player) void {
        switch (self) {
            inline else => |case| @TypeOf(case).exit(player),
        }
    }
};

const IdleState = struct {
    fn enter(player: *Player) void {
        player.state = .idle;
        player.shared.velocity.x = 0;
    }

    fn update(player: *Player, delta: f32) void {
        if (player.attackKeyDown and player.attackCoolDown.finished) {
            player.changeState(.attack);
        }

        if (player.leftKeyDown or player.rightKeyDown) {
            player.changeState(.run);
        }

        if (player.rollKeyDown and player.rollCoolDown.finished) {
            player.changeState(.roll);
        }

        if (player.jumpKeyDown and player.shared.velocity.y == 0) {
            player.changeState(.jump);
        }

        player.idleAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.idleAnimation);
    }

    fn exit(player: *Player) void {
        player.idleAnimation.reset();
    }
};

const JumpState = struct {
    const SPEED_JUMP = 780;

    fn enter(player: *Player) void {
        player.state = .jump;
        player.shared.velocity.y = -SPEED_JUMP;
    }

    fn update(player: *Player, delta: f32) void {
        if (player.shared.velocity.y > 0) {
            player.changeState(.fall);
        }

        player.jumpAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.jumpAnimation);
    }

    fn exit(player: *Player) void {
        player.jumpAnimation.reset();
    }
};

const FallState = struct {
    fn enter(player: *Player) void {
        player.state = .fall;
    }

    fn update(player: *Player, delta: f32) void {
        if (player.shared.velocity.y == 0) {
            player.changeState(.idle);
        }

        player.fallAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.fallAnimation);
    }

    fn exit(player: *Player) void {
        player.fallAnimation.reset();
    }
};

const RunState = struct {
    const SPEED_RUN = 300;

    fn enter(player: *Player) void {
        player.state = .run;

        if (player.leftKeyDown) {
            player.shared.velocity.x = -SPEED_RUN;
            player.shared.faceLeft = true;
        } else if (player.rightKeyDown) {
            player.shared.velocity.x = SPEED_RUN;
            player.shared.faceLeft = false;
        }
    }

    fn update(player: *Player, delta: f32) void {
        if (player.attackKeyDown and player.attackCoolDown.finished) {
            player.changeState(.attack);
        }

        if (!player.leftKeyDown and !player.rightKeyDown) {
            player.changeState(.idle);
        }

        if (player.rollKeyDown and player.rollCoolDown.finished) {
            player.changeState(.roll);
        }

        if (player.jumpKeyDown and player.shared.velocity.y == 0) {
            player.changeState(.jump);
        }

        player.runAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.runAnimation);
    }

    fn exit(player: *Player) void {
        player.runAnimation.reset();
    }
};

const RollState = struct {
    const SPEED_ROLL = 800;
    fn enter(player: *Player) void {
        player.state = .roll;
        player.rollTimer.reset();
        player.rollCoolDown.reset();

        if (player.shared.faceLeft) {
            player.shared.velocity.x = -SPEED_ROLL;
        } else {
            player.shared.velocity.x = SPEED_ROLL;
        }
    }

    fn update(player: *Player, delta: f32) void {
        if (player.rollTimer.isFinishedAfterUpdate(delta)) {
            player.changeState(.idle);
        }

        player.rollAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.rollAnimation);
    }

    fn exit(player: *Player) void {
        player.rollAnimation.reset();
    }
};

const AttackState = struct {
    fn enter(player: *Player) void {
        player.state = .attack;
        player.attackTimer.reset();
        player.attackCoolDown.reset();
    }

    fn update(player: *Player, delta: f32) void {
        if (player.attackTimer.isFinishedAfterUpdate(delta)) {
            player.changeState(.idle);
        }

        player.attackAnimation.update(delta);
        player.attackLeft.update(delta);
        player.attackRight.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.attackAnimation);
        const pos = player.shared.position.add(.{ .y = 100 });
        if (player.shared.faceLeft) {
            gfx.playAtlas(&player.attackLeft, pos);
        } else {
            gfx.playAtlas(&player.attackRight, pos);
        }
    }

    fn exit(player: *Player) void {
        player.attackAnimation.reset();
        player.attackLeft.reset();
        player.attackRight.reset();
    }
};
