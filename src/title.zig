const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const save = @import("ui/save.zig");
const world = @import("world.zig");
const input = @import("zon.zig").input;

pub const Request = union(enum) { load: u8 };
const Popup = enum { save };

var background: zhu.Image = undefined;
var popup: ?Popup = null;

var displayHeader: bool = false;
var displayTimer: zhu.Timer = .init(0.08);
var textIndex: usize = 0;

pub fn init() void {
    background = zhu.assets.loadImage("title.png", .{
        .size = .xy(640, 480),
    });
}

pub fn enter() void {
    menu.active = 4;
    popup = null;
    zhu.audio.playMusic("voc/title.ogg");
    displayHeader = false;
    textIndex = 0;
    scene.fadeIn();
}

pub fn exit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn update(delta: f32) ?Request {
    if (displayHeader) {
        updateHeader(delta);
        return null;
    }

    if (popup) |active| return updatePopup(active);

    const menuEvent = menu.update();
    if (menuEvent) |event| {
        if (menuSelected(event)) |req| return req;
    }

    if (input.released(.cancel)) {
        menu.active = 4;
    }
    return null;
}

fn menuSelected(index: u8) ?Request {
    switch (index) {
        0 => {
            scene.fadeOut(struct {
                fn call() void {
                    displayHeader = true;
                }
            }.call);
            return null;
        },
        1 => {
            save.open(.load);
            popup = .save;
            return null;
        },
        2 => {
            window.exit();
            return null;
        },
        else => unreachable(),
    }
}

fn updatePopup(active: Popup) ?Request {
    switch (active) {
        .save => if (save.update()) |req| switch (req) {
            .close => popup = null,
            .load => |index| return .{ .load = index },
            .save => unreachable,
        },
    }
    return null;
}

pub fn draw() void {
    if (displayHeader) return drawHeader();
    zhu.batch.drawImage(background, .zero, .{});

    if (popup) |active| {
        switch (active) {
            .save => save.draw(),
        }
        return;
    }
    menu.draw();
}

fn updateHeader(delta: f32) void {
    if (input.released(.confirm) or zhu.mouse.released(.LEFT)) {
        world.back = .none;
        scene.changeScene(.world);
        return;
    }

    if (displayTimer.updateFinished(delta)) {
        if (textIndex >= text.len) return;
        const len = std.unicode.utf8ByteSequenceLength(text[textIndex]);
        textIndex += len catch unreachable;
        displayTimer.restart();
    }
}

const text =
    \\　　在很久很久以前，白云城的居民过着富足而安定的生活。不过
    \\一场巨大的灾难即将降临到这里……
    \\　　一天，我们故事的主人翁'小飞刀'一觉醒来，故事就从这里开
    \\始……　　[按回车键继续]
;

pub fn drawHeader() void {
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(text[0..textIndex], .xy(40, 100), .{});
}
