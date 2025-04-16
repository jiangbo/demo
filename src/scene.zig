const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub const Chicken = struct {
    const ChickenType = enum { fast, medium, slow };

    position: math.Vector = .{ .x = -50, .y = -50 },
    speed: f32,
    animationRun: gfx.SliceFrameAnimation,
    animationExplosion: gfx.SliceFrameAnimation = undefined,

    alive: bool = true,
    valid: bool = true,
};

const ChickenArray = std.BoundedArray(Chicken, 1000);
var chickens: ChickenArray = undefined;

var spawnIntervalTimer: window.Timer = .init(1.5);
var spawnNumberTimer: window.Timer = .init(8);
var spawnNumber: usize = 0;

pub fn init() void {
    chickens = ChickenArray.init(0) catch unreachable;
}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}
pub fn update(delta: f32) void {
    if (spawnIntervalTimer.isFinishedAfterUpdate(delta)) {
        spawnIntervalTimer.reset();
        spawnChicken();
    }

    if (spawnNumberTimer.isFinishedAfterUpdate(delta)) {
        spawnNumberTimer.reset();
        spawnNumber += 1;
    }

    for (chickens.slice()) |*chicken| {
        chicken.position.y += chicken.speed * delta;
        chicken.animationRun.update(delta);
    }
}

fn spawnChicken() void {
    std.log.info("spawn number: {d}", .{spawnNumber});
    for (0..spawnNumber) |_| {
        var chicken: Chicken = switch (math.randomU8(0, 100)) {
            0...49 => .{
                .speed = 80,
                .animationRun = .load("assets/chicken_fast_{}.png", 4),
            },
            50...79 => .{
                .speed = 50,
                .animationRun = .load("assets/chicken_medium_{}.png", 6),
            },
            80...99 => .{
                .speed = 30,
                .animationRun = .load("assets/chicken_slow_{}.png", 8),
            },
            else => unreachable,
        };
        chicken.position = .{ .x = math.randomF32(40, 1240), .y = -50 };
        chicken.animationExplosion = .load("assets/explosion_{}.png", 5);
        chicken.animationExplosion.loop = false;
        chicken.animationExplosion.timer.duration = 0.08;

        chickens.appendAssumeCapacity(chicken);
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, window.size.sub(background.size()).scale(0.5));

    for (chickens.slice()) |*chicken| {
        gfx.playSlice(&chicken.animationRun, chicken.position);
    }
}

pub fn deinit() void {}
