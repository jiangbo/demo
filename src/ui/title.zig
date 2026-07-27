const std = @import("std");
const zhu = @import("zhu");

const save = @import("save.zig");
const input = @import("../zon.zig").input;
const Typing = @import("Typing.zig");

pub const Request = union(enum) {
    fadeOut: *const fn () void,
    start,
    load: u8,
};
const Button = enum { start, load, exit };
const State = enum { menu, save, intro };

var background: zhu.Image = undefined;
var menu: zhu.widget.Menu = @import("title.zon");
var state: State = .menu;

// 开场文字的逐字显示状态。
var introTyping: Typing = .{ .content = introText };

pub fn init() void {
    background = zhu.assets.loadImage("title.png", .{
        .size = .xy(640, 480),
    });
}

pub fn enter() void {
    menu.reset();
    menu.selected = 0;
    state = .menu;
    zhu.audio.playMusic("voc/title.ogg");
    introTyping.reset();
}

pub fn exit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn update(delta: f32) ?Request {
    switch (state) {
        .menu => if (menu.update(.{})) |event| {
            if (select(@enumFromInt(event))) |req| return req;
        },
        .save => if (save.update()) |req| switch (req) {
            .close => state = .menu,
            .load => |index| return .{ .load = index },
            .save => unreachable,
        },
        .intro => if (updateIntro(delta)) |req| return req,
    }
    return null;
}

fn select(button: Button) ?Request {
    switch (button) {
        .start => return .{ .fadeOut = showIntro },
        .load => {
            save.open(.load);
            state = .save;
        },
        .exit => zhu.window.exit(),
    }
    return null;
}

fn showIntro() void {
    state = .intro;
}

pub fn draw() void {
    switch (state) {
        .menu => {
            zhu.batch.drawImage(background, .zero, .{});
            menu.drawImage();
            zhu.text.msdf.begin();
            defer zhu.text.msdf.end();
            menu.drawText();
        },
        .save => {
            zhu.batch.drawImage(background, .zero, .{});
            save.draw();
        },
        .intro => drawIntro(),
    }
}

fn updateIntro(delta: f32) ?Request {
    if (input.released(.confirm) or zhu.mouse.released(.LEFT)) {
        return .start;
    }

    introTyping.update(delta);
    return null;
}

const introText =
    \\　　在很久很久以前，白云城的居民过着富足而安定的生活。不过
    \\一场巨大的灾难即将降临到这里……
    \\　　一天，我们故事的主人翁'小飞刀'一觉醒来，故事就从这里开
    \\始……　　[按回车键继续]
;

fn drawIntro() void {
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(introTyping.text(), .xy(40, 100), .{});
}
