const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const actor = @import("actor/actor.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

var debug: bool = false;
pub var player: actor.Player = undefined;
pub var enemy: actor.Enemy = undefined;
pub var boxes: std.BoundedArray(actor.CollisionBox, 30) = undefined;

pub fn init() void {
    boxes = std.BoundedArray(actor.CollisionBox, 30).init(0) catch unreachable;
    player = actor.Player.init();
    enemy = actor.Enemy.init();

    audio.playMusic("assets/audio/bgm.ogg");
}

pub fn addCollisionBox(box: actor.CollisionBox) *actor.CollisionBox {
    for (boxes.slice()) |*value| {
        if (!value.valid) value.* = box;
    } else {
        boxes.appendAssumeCapacity(box);
        return &boxes.slice()[boxes.len - 1];
    }
}

pub fn deinit() void {
    audio.stopMusic();
}

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

    for (boxes.slice()) |*srcBox| {
        if (!srcBox.enable or srcBox.dst == .none or !srcBox.valid) continue;
        for (boxes.slice()) |*dstBox| {
            if (!dstBox.enable or srcBox == dstBox or //
                srcBox.dst != dstBox.src or !dstBox.valid) continue;

            if (srcBox.rect.intersects(dstBox.rect)) {
                dstBox.valid = false;
                std.log.info("src box: {any}", .{srcBox});
                std.log.info("dst box: {any}", .{dstBox});
                if (dstBox.callback) |callback| callback();
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
            if (box.enable and box.valid) gfx.drawRectangle(box.rect);
        }
    }
}

pub fn renderBackground() void {
    const background = gfx.loadTexture("assets/background.png");
    const width = window.width - background.width();
    const height = window.height - background.height();
    gfx.draw(background, width / 2, height / 2);
}
