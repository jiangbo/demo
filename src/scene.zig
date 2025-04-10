const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const actor = @import("actor/actor.zig");
const math = @import("math.zig");

pub const CollisionLayer = enum { none, player, enemy };

pub const CollisionBox = struct {
    rect: math.Rectangle,
    enable: bool = true,
    src: CollisionLayer = .none,
    dst: CollisionLayer = .none,
    callback: ?*const fn () void = null,
    valid: bool = true,
};

var debug: bool = false;
pub var player: actor.Player = undefined;
pub var enemy: actor.Enemy = undefined;
pub var boxes: std.BoundedArray(CollisionBox, 30) = undefined;

pub fn init() void {
    player = actor.Player.init();
    enemy = actor.Enemy.init();
    boxes = std.BoundedArray(CollisionBox, 30).init(0) catch unreachable;

    boxes.appendAssumeCapacity(.{
        .rect = .{ .x = 200, .y = 200, .w = 100, .h = 100 },
        .dst = .enemy,
    });

    boxes.appendAssumeCapacity(.{
        .rect = .{ .x = 800, .y = 200, .w = 100, .h = 100 },
        .src = .enemy,
        .callback = struct {
            fn callback() void {
                std.log.info("collision enemy", .{});
            }
        }.callback,
    });
}

pub fn deinit() void {}

pub fn event(ev: *const window.Event) void {
    if (ev.type == .KEY_UP and ev.key_code == .X) {
        debug = !debug;
        return;
    }

    player.event(ev);
}

pub fn update() void {
    const delta = window.deltaSecond();
    player.update(delta);
    enemy.update(delta);

    boxes.buffer[0].rect.x += delta * 50;

    for (boxes.slice()) |*srcBox| {
        if (!srcBox.enable or srcBox.dst == .none) continue;
        for (boxes.slice()) |*dstBox| {
            if (!dstBox.enable or srcBox == dstBox or dstBox.src == .none) continue;
            if (srcBox.rect.intersects(dstBox.rect)) {
                dstBox.valid = false;
                if (dstBox.callback) |callback| callback();
            }
        }
    }

    {
        var i: usize = boxes.len;
        while (i > 0) : (i -= 1) {
            if (!boxes.slice()[i - 1].valid) {
                _ = boxes.swapRemove(i - 1);
            }
        }
    }
}
pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    renderBackground();
    enemy.render();
    player.render();

    if (debug) {
        for (boxes.slice()) |box| {
            if (!box.enable) continue;
            gfx.drawRectangle(box.rect);
        }
    }
}

pub fn renderBackground() void {
    const background = gfx.loadTexture("assets/background.png");
    const width = window.width - background.width();
    const height = window.height - background.height();
    gfx.draw(background, width / 2, height / 2);
}
