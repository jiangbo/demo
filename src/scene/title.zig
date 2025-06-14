const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const scene = @import("../scene.zig");
const camera = @import("../camera.zig");

var background: gfx.Texture = undefined;

const Menu = struct {
    background: ?gfx.Texture = null,
    position: gfx.Vector,
    names: []const []const u8,
    areas: []const gfx.Rectangle = undefined,
    current: usize = 0,
    const color = gfx.color(0.73, 0.72, 0.53, 1);
};

var menu: *Menu = &mainMenu;
var displayHeader: bool = false;
var displayTimer: window.Timer = .init(0.08);
var textIndex: usize = 0;

var mainMenu: Menu = .{
    .position = .{ .x = 11, .y = 375 },
    .names = &.{ "新游戏", "读进度", "退　出" },
    .areas = &createAreas(3, .{ .x = 11, .y = 375 }),
};
var loadMenu: Menu = .{
    .position = .{ .x = 0, .y = 280 },
    .names = &.{ "进度一", "进度二", "进度三", "进度四", "进度五", "取　消" },
    .areas = &createAreas(6, .{ .x = 0 + 45, .y = 280 + 20 }),
};

fn createAreas(comptime num: u8, pos: gfx.Vector) [num]gfx.Rectangle {
    var areas: [num]gfx.Rectangle = undefined;
    for (&areas, 0..) |*area, i| {
        const offsetY: f32 = @floatFromInt(10 + i * 24);
        area.* = .init(pos.addY(offsetY), .init(58, 25));
    }
    return areas;
}

pub fn init() void {
    background = gfx.loadTexture("assets/pic/title.png", .init(640, 480));
    const path = "assets/pic/mainmenu.png";
    loadMenu.background = gfx.loadTexture(path, .init(150, 200));
}

pub fn event(ev: *const window.Event) void {
    if (ev.type != .MOUSE_MOVE) return;

    for (menu.areas, 0..) |area, i| {
        if (area.contains(window.mousePosition)) {
            menu.current = i;
        }
    }
}

pub fn enter() void {
    menu.current = 0;
    window.playMusic("assets/voc/title.ogg");
    displayHeader = false;
    textIndex = 0;
    scene.fadeIn();
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    if (displayHeader) return updateHeader(delta);

    if (window.isAnyKeyRelease(&.{ .DOWN, .S })) {
        menu.current = (menu.current + 1) % menu.names.len;
    }
    if (window.isAnyKeyRelease(&.{ .UP, .W })) {
        menu.current += menu.names.len;
        menu.current = (menu.current - 1) % menu.names.len;
    }

    var confirm = window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
    if (window.isButtonRelease(.LEFT)) {
        for (menu.areas, 0..) |area, i| {
            if (area.contains(window.mousePosition)) {
                menu.current = i;
                confirm = true;
            }
        }
    }

    if (confirm) {
        if (menu == &mainMenu) mainMenuSelected() else loadMenuSelected();
    }

    if (window.isAnyKeyRelease(&.{ .Q, .ESCAPE })) {
        menu = &mainMenu;
    }
}

fn updateHeader(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) {
        scene.changeScene(.world);
        return;
    }

    if (displayTimer.isFinishedAfterUpdate(delta)) {
        if (textIndex >= text.len) return;
        const len = std.unicode.utf8ByteSequenceLength(text[textIndex]);
        textIndex += len catch unreachable;
        displayTimer.reset();
    }
}

const text = scene.talks[0].content;

fn mainMenuSelected() void {
    switch (menu.current) {
        0 => scene.fadeOut(struct {
            fn call() void {
                displayHeader = true;
            }
        }.call),
        1 => menu = &loadMenu,
        2 => window.exit(),
        else => unreachable(),
    }
}

fn loadMenuSelected() void {
    switch (menu.current) {
        0, 1, 2, 3, 4 => scene.changeScene(.world),
        5 => menu = &mainMenu,
        else => unreachable(),
    }
}

pub fn render() void {
    if (displayHeader) return renderHeader();
    camera.draw(background, .zero);

    if (menu.background) |bg| camera.draw(bg, menu.position);

    for (menu.areas, menu.names, 0..) |area, name, i| {
        if (i == menu.current) {
            camera.drawRectangle(area, Menu.color);
        }
        camera.drawText(name, area.min.addX(5));
    }
}

pub fn renderHeader() void {
    camera.drawText(text[0..textIndex], .init(60, 100));
}
