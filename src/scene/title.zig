const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const scene = @import("../scene.zig");
const camera = @import("../camera.zig");

var background: gfx.Texture = undefined;

const MainMenu = struct {
    background: gfx.Texture = undefined,
    position: gfx.Vector,
    names: [3][]const u8,
    areas: [3]gfx.Rectangle = undefined,
    current: usize,
    const color = gfx.color(0.73, 0.72, 0.53, 1);
};

var menu: MainMenu = .{
    .position = .{ .x = 11, .y = 375 },
    .names = .{ "新游戏", "读进度", "退　出" },
    .current = 0,
};

pub fn init() void {
    background = gfx.loadTexture("assets/pic/title.png", .init(640, 480));

    for (&menu.areas, 0..) |*area, i| {
        const offsetY: f32 = @floatFromInt(10 + i * 24);
        area.* = .init(menu.position.addY(offsetY), .init(58, 25));
    }
}

pub fn event(ev: *const window.Event) void {
    if (ev.type != .MOUSE_MOVE) return;

    for (&menu.areas, 0..) |area, i| {
        if (area.contains(window.mousePosition)) {
            menu.current = i;
        }
    }
}

pub fn enter() void {
    menu.current = 0;
    window.playMusic("assets/voc/title.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    _ = delta;
    if (window.isAnyKeyRelease(&.{ .DOWN, .S })) {
        menu.current = (menu.current + 1) % menu.names.len;
    }
    if (window.isAnyKeyRelease(&.{ .UP, .W })) {
        menu.current += menu.names.len;
        menu.current = (menu.current - 1) % menu.names.len;
    }

    var confirm = window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
    if (window.isButtonRelease(.LEFT)) {
        for (&menu.areas, 0..) |area, i| {
            if (area.contains(window.mousePosition)) {
                menu.current = i;
                confirm = true;
            }
        }
    }

    if (confirm) {
        switch (menu.current) {
            0 => scene.changeScene(.world),
            1 => {},
            2 => window.exit(),
            else => unreachable(),
        }
    }
}

pub fn render() void {
    camera.draw(background, .zero);

    for (&menu.areas, &menu.names, 0..) |area, name, i| {
        if (i == menu.current) {
            camera.drawRectangle(area, MainMenu.color);
        }
        camera.drawText(name, area.min.addX(5));
    }
}
