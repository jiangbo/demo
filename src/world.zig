const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

const scene = @import("scene.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const talk = @import("talk.zig");
const about = @import("about.zig");
const item = @import("item.zig");

const Status = union(enum) {
    normal,
    talk: usize,
    menu,
    about,
    status,
    item,
};
var status: Status = .normal;

const Menu = struct {
    names: []const []const u8,
    areas: []const gfx.Rectangle = undefined,
    current: usize = 0,
    const color = gfx.Color{ .w = 1 };
};

var menu: Menu = .{
    .names = &.{
        "状　　态", "物　　品", "读取进度", "存储进度", //
        "关于游戏", "退　　出", "返回游戏",
    },
    .areas = &createAreas(7, .{ .x = 0 + 33, .y = 288 }),
};
var toChangeMapId: u16 = 2;

fn createAreas(comptime num: u8, pos: gfx.Vector) [num]gfx.Rectangle {
    var areas: [num]gfx.Rectangle = undefined;
    for (&areas, 0..) |*area, i| {
        const offsetY: f32 = @floatFromInt(10 + i * 24);
        area.* = .init(pos.addY(offsetY), .init(85, 25));
    }
    return areas;
}

var menuTexture: gfx.Texture = undefined;

pub fn init() void {
    menuTexture = gfx.loadTexture("assets/pic/mainmenu1.png", .init(150, 200));
    talk.init();
    about.init();
    map.init();
    player.init();

    // window.playMusic("assets/voc/back.ogg");
    // status = .{ .talk = 1 };
    // status = .item;
}

pub fn event(ev: *const window.Event) void {
    if (ev.type != .MOUSE_MOVE) return;

    for (menu.areas, 0..) |area, i| {
        if (area.contains(window.mousePosition)) {
            menu.current = i;
        }
    }
}

pub fn update(delta: f32) void {
    switch (status) {
        .normal => {},
        .talk => |talkId| return updateTalk(talkId),
        .item => return updateItem(),
        .status => {
            if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .SPACE }) or
                window.isButtonRelease(.LEFT))
            {
                status = .normal;
            }
            return;
        },
        .menu => return updateMenu(),
        .about => return updateAbout(delta),
    }

    playerMove(delta);

    // 交互检测
    if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) {
        const object = map.talk(player.position, player.facing());
        if (object != 0) handleObject(object);
    }

    // 打开菜单
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .E })) {
        status = .menu;
        menu.current = 0;
    }

    player.update(delta);
}

fn playerMove(delta: f32) void {
    // 角色移动和碰撞检测
    const toPosition = player.toMove(delta);
    if (toPosition) |position| {
        if (map.canWalk(position.addXY(-8, -12)) and
            map.canWalk(position.addXY(-8, 2)) and
            map.canWalk(position.addXY(8, -12)) and
            map.canWalk(position.addXY(8, 2)))
        {
            player.position = position;
            // 相机跟踪
            cameraLookAt(position);

            // 检测是否需要切换场景
            const object = map.getObject(map.positionIndex(position));
            if (object > 0x1FFF and map.tileCenterContains(position)) {
                handleObject(object);
            }
        }
    }
}

fn cameraLookAt(position: gfx.Vector) void {
    const half = window.size.scale(0.5);
    const max = map.size().sub(window.size);
    camera.position = position.sub(half).clamp(.zero, max);
}

fn updateTalk(talkId: usize) void {
    const next = talk.update(talkId);
    status = if (next == 0) .normal else .{ .talk = next };
}

fn updateItem() void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) {
        status = .normal;
        return;
    }
    player.updateItem();
}

fn updateAbout(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q }) or
        window.isButtonRelease(.RIGHT))
    {
        status = .normal;
        return;
    }

    if (about.roll) {
        about.update(delta);
    } else {
        if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER }) or
            window.isButtonRelease(.LEFT))
        {
            about.roll = true;
        }
    }
}

fn handleObject(object: u16) void {
    if (object & 0x1000 != 0) handleChest(object);
    if (object > 0x1FFF) handleChange(object);
}

fn handleChest(object: u16) void {
    if (object == 0x1000) {
        const gold = window.random().intRangeLessThanBiased(u8, 10, 100);
        player.money += gold;
        status = .{ .talk = 3 };
        talk.talkNumber = gold;
    } else {
        player.addItem(object & 0xFF);
        const name = item.items[(object & 0xFF)].name;
        talk.talkNumber = name.len;
        @memcpy(talk.talkText[0..name.len], name);
        status = .{ .talk = 4 };
    }
}

fn handleChange(object: u16) void {
    toChangeMapId = object & 0x0FFF;
    scene.changeScene(.world);
}

fn updateMenu() void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .E, .Q })) status = .normal;

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

    if (confirm) menuSelected();
}

fn menuSelected() void {
    switch (menu.current) {
        0 => status = .status,
        1 => status = .item,
        2...3 => status = .normal,
        4 => {
            status = .about;
            about.resetRoll();
        },
        5 => window.exit(),
        6 => status = .normal,
        else => {},
    }
}

pub fn enter() void {
    if (toChangeMapId == 0) {
        // 开始游戏
        map.enter(toChangeMapId + 1);
        player.enter(.init(180, 164));
        camera.position = .zero;
    }

    map.enter(toChangeMapId);
    if (toChangeMapId == 1) {
        player.enter(.init(430, 410));
        camera.position = .zero;
    } else if (toChangeMapId == 2) {
        camera.position = .init(14 * 32, 0);
        player.enter(camera.position.addXY(400, 90));
    }
}

pub fn exit() void {}

pub fn render() void {
    map.render();

    player.render();

    camera.mode = .local;
    defer camera.mode = .world;

    switch (status) {
        .normal => {},
        .talk => |talkId| talk.render(talkId),
        .status => player.renderStatus(),
        .item => player.renderItem(),
        .menu => renderMenu(),
        .about => about.render(),
    }
}

fn renderMenu() void {
    camera.draw(menuTexture, .init(0, 280));

    for (menu.areas, menu.names, 0..) |area, name, i| {
        if (i == menu.current) {
            camera.drawRectangle(area, Menu.color);
        }
        camera.drawText(name, area.min.addXY(5, -2));
    }
}
