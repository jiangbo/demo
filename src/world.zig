const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const player = @import("player.zig");
const map = @import("map.zig");
const talk = @import("talk.zig");
const about = @import("about.zig");
const item = @import("item.zig");
const npc = @import("npc.zig");

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

    npc.init();

    // window.playMusic("assets/voc/back.ogg");
    // status = .{ .talk = 1 };
    // status = .item;
}

pub fn enter() void {
    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
}

// const parseZon = std.zon.parse.fromSlice;
// pub fn reload(allocator: std.mem.Allocator) void {
//     std.log.info("reload", .{});

//     const content = window.readAll(allocator, "src/zon/change.zon");
//     defer allocator.free(content);
//     const zon = parseZon([]ChangedMap, allocator, content, null, .{});
//     changeMaps = zon catch @panic("error parse zon");
// }

pub fn exit() void {}

pub fn update(delta: f32) void {
    if (status != .menu and (window.pressedButton(.RIGHT) or
        window.pressedAny(&.{ .ESCAPE, .E })))
    {
        status = .menu;
        return;
    }

    switch (status) {
        .normal => {
            npc.update(delta);
            player.update(delta);
        },
        .talk => |talkId| return updateTalk(talkId),
        .item => return updateItem(),
        .status => {
            return if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .SPACE }) or
                window.isButtonRelease(.RIGHT))
            {
                status = .normal;
            };
        },
        .menu => return updateMenu(),
        .about => return updateAbout(delta),
    }

    // 交互检测
    if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) {
        const object = map.openChest(player.position, player.facing());
        if (object != 0) openChest(object);
    }

    // 打开菜单
    if (window.pressedAny(&.{ .ESCAPE, .E }) or
        window.isButtonRelease(.MIDDLE))
    {
        status = .menu;
        menu.current = 0;
    }
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

fn openChest(pickIndex: u16) void {
    const object = item.pickupZon[pickIndex];

    if (object.itemIndex == 0 and object.count == 0) {
        const gold = window.random().intRangeLessThanBiased(u8, 10, 100);
        player.money += gold;
        status = .{ .talk = 3 };
        talk.talkNumber = gold;
    } else {
        player.addItem(object.itemIndex);
        const name = item.zon[object.itemIndex].name;
        talk.talkNumber = name.len;
        @memcpy(talk.talkText[0..name.len], name);
        status = .{ .talk = 4 };
    }
}

fn updateMenu() void {
    if (window.pressedAny(&.{ .ESCAPE, .E, .Q }) or
        window.pressedAnyButton(&.{ .RIGHT, .MIDDLE }))
        status = .normal;

    if (window.mouseMoved) {
        for (menu.areas, 0..) |area, i| {
            if (area.contains(window.mousePosition)) {
                menu.current = i;
            }
        }
    }

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

pub fn draw() void {
    map.draw();
    npc.draw();
    player.draw();

    camera.mode = .local;
    defer camera.mode = .world;

    switch (status) {
        .normal => {},
        .talk => |talkId| talk.draw(talkId),
        .status => player.drawStatus(),
        .item => player.drawItem(),
        .menu => drawMenu(),
        .about => about.draw(),
    }
}

fn drawMenu() void {
    camera.draw(menuTexture, .init(0, 280));

    for (menu.areas, menu.names, 0..) |area, name, i| {
        if (i == menu.current) {
            camera.drawRectangle(area, Menu.color);
        }
        camera.drawText(name, area.min.addXY(5, -2));
    }
}
