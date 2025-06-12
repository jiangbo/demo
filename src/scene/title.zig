const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const scene = @import("../scene.zig");
const camera = @import("../camera.zig");

var background: gfx.Texture = undefined;

const Menu = struct {
    position: gfx.Vector,
    names: [3][]const u8,
    current: usize,
    const color = gfx.color(0.73, 0.72, 0.53, 1);
};

var menu: Menu = .{
    .position = .{ .x = 16, .y = 380 },
    .names = .{ "新游戏", "读进度", "退　出" },
    .current = 0,
};

pub fn init() void {
    background = gfx.loadTexture("assets/pic/title.png", .init(640, 480));
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

    if (window.isMouseMove()) {
        std.log.info("is mouse move: {}", .{window.isMouseMove()});
        for (0..menu.names.len) |i| {
            const offsetY: f32 = @floatFromInt(10 + i * 24);
            const size = gfx.Vector{ .x = 58, .y = 25 };
            const offset = menu.position.addY(offsetY).addX(-5);
            const area = gfx.Rectangle.init(offset, size);
            if (area.contains(window.mousePosition)) menu.current = i;
        }
    }
}

pub fn render() void {
    camera.draw(background, .zero);
    for (menu.names, 0..) |name, i| {
        const offsetY: f32 = @floatFromInt(10 + i * 24);
        const offset = menu.position.addY(offsetY);
        if (i == menu.current) {
            const size = gfx.Vector{ .x = 58, .y = 25 };
            camera.drawRectangle(.init(offset.addX(-5), size), Menu.color);
        }
        camera.drawText(name, offset);
    }
}
