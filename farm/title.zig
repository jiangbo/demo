const std = @import("std");
const zhu = @import("zhu");

const context = @import("context.zig");
const save_slot = @import("ui/save_slot.zig");
const ui = @import("ui.zig");

const menus: []const zhu.widget.Menu = @import("zon/menu.zon");

pub const Request = union(enum) { start, load: usize };
const Button = enum(u8) { start, load, exit };
const Layer = enum { main, pause, save };

var mainMenu: zhu.widget.Menu = menus[0];
var pauseButton: zhu.widget.Menu = menus[1];
var background: zhu.Image = undefined;
var logo: zhu.Image = undefined;
var elapsed: f32 = 0;
var layerBuffer: [4]Layer = undefined;
var layers: std.ArrayList(Layer) = .initBuffer(&layerBuffer);

pub fn init() void {
    const bgPath = "textures/UI/farm-rpg-bg.png";
    background = zhu.assets.loadImage(bgPath, .xy(1280, 800));
    logo = zhu.getImage("textures/UI/farm-rpg-logo.png").?;
    const size = pauseButton.buttons[0].rect.size;
    const x = zhu.window.size.x - 10 - size.x;
    pauseButton.position = .xy(x, 10);
}

pub fn enter() void {
    zhu.camera.main = .window;
    zhu.audio.playMusic("audio/02_spring_fairy_tale.ogg");
    mainMenu.click = .empty;
    pauseButton.click = .empty;
    layers.clearRetainingCapacity();
    pushLayer(.main);
}

pub fn exit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn update(world: *zhu.ecs.World, delta: f32) ?Request {
    elapsed += delta;

    return switch (topLayer()) {
        .main => updateMain(),
        .pause => updatePause(),
        .save => updateSave(world),
    };
}

fn updateMain() ?Request {
    if (context.input.pressed(.pause)) {
        ui.pause.enter(true);
        pushLayer(.pause);
        return null;
    }

    if (pauseButton.update() != null) {
        ui.pause.enter(true);
        pushLayer(.pause);
        return null;
    }

    if (mainMenu.update()) |event| {
        switch (@as(Button, @enumFromInt(event))) {
            .start => return .start,
            .load => {
                save_slot.enter(.titleLoad);
                pushLayer(.save);
            },
            .exit => zhu.window.exit(),
        }
    }
    return null;
}

fn updatePause() ?Request {
    ui.pause.update();
    if (!ui.pause.active) popLayer();
    return null;
}

fn updateSave(world: *zhu.ecs.World) ?Request {
    if (save_slot.update(world)) |result| {
        switch (result) {
            .farmLoad => |slot| return .{ .load = slot },
            .message => {},
        }
    }
    if (!save_slot.active) popLayer();
    return null;
}

fn topLayer() Layer {
    return layers.items[layers.items.len - 1];
}

fn pushLayer(layer: Layer) void {
    layers.appendBounded(layer) catch @panic("title layer overflow");
}

fn popLayer() void {
    if (layers.items.len <= 1) return;
    _ = layers.pop();
}

pub fn draw() void {
    zhu.batch.drawImage(background, .zero, .{
        .size = zhu.window.size,
    });
    const y = 115 + @sin(elapsed * 2) * 5;
    zhu.batch.drawImage(logo, .xy(320, y), .{
        .size = .xy(293, 125),
        .anchor = .center,
    });

    mainMenu.draw();
    pauseButton.draw();

    switch (topLayer()) {
        .main => {},
        .pause => ui.pause.draw(),
        .save => save_slot.draw(),
    }
}
