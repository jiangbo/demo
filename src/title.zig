const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const world = @import("world.zig");
const input = @import("input.zig");

var background: zhu.Image = undefined;
var menuBackground: zhu.Image = undefined;

var displayHeader: bool = false;
var displayTimer: zhu.Timer = .init(0.08);
var textIndex: usize = 0;

pub fn init() void {
    background = zhu.assets.loadImage("pic/title.png", .{
        .size = .xy(640, 480),
    });
    menuBackground = zhu.getImage("mainmenu2.png").?;
}

pub fn enter() void {
    menu.active = 4;
    zhu.audio.playMusic("voc/title.ogg");
    displayHeader = false;
    textIndex = 0;
    scene.fadeIn();
}

pub fn exit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn update(delta: f32) void {
    if (displayHeader) return updateHeader(delta);

    const menuEvent = menu.update();
    if (menuEvent) |event| menuSelected(event);

    if (input.released(.cancel)) {
        menu.active = 4;
    }
}

fn menuSelected(index: u8) void {
    switch (index) {
        0 => scene.fadeOut(struct {
            fn call() void {
                displayHeader = true;
            }
        }.call),
        1 => menu.active = 5,
        2 => window.exit(),
        3, 4, 5, 6, 7 => |event| {
            world.load(event) catch return;
            world.back = .battle;
            scene.changeScene(.world);
        },
        8 => menu.active = 4,
        else => unreachable(),
    }
}

pub fn draw() void {
    if (displayHeader) return drawHeader();
    zhu.batch.drawImage(background, .zero, .{});

    if (menu.current().background) {
        zhu.batch.drawImage(menuBackground, menu.current().position, .{});
    }
    menu.draw();
}

fn updateHeader(delta: f32) void {
    if (input.released(.confirm) or input.mouseReleased(.LEFT)) {
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
