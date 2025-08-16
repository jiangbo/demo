const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const menu = @import("menu.zig");
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

var menuTexture: gfx.Texture = undefined;
var arenaAllocator: std.heap.ArenaAllocator = undefined;

pub fn init() void {
    arenaAllocator = std.heap.ArenaAllocator.init(window.allocator);
    menuTexture = gfx.loadTexture("assets/pic/mainmenu1.png", .init(150, 200));

    talk.init();
    about.init();
    map.init();
    player.init();

    npc.init();
    menu.active = 6;

    // window.playMusic("assets/voc/back.ogg");
    // status = .{ .talk = 1 };
    // status = .item;
}

pub fn deinit() void {
    arenaAllocator.deinit();
    window.stopMusic();
}

pub fn enter() void {
    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
}

pub fn exit() void {}

pub fn update(delta: f32) void {
    reloadIfChanged();

    if (status != .menu) {
        if (window.isMouseRelease(.RIGHT) or
            window.isAnyKeyRelease(&.{ .ESCAPE, .E }))
        {
            status = .menu;
            menu.active = 6;
            return;
        }
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
                window.isMouseRelease(.RIGHT))
            {
                status = .normal;
            };
        },
        .menu => return updateMenu(),
        .about => return updateAbout(delta),
    }

    // 交互检测
    if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) {
        const object = map.openChest(player.position, player.facing);
        if (object != 0) openChest(object);
    }
}

var modifyTime: i64 = 0;
fn reloadIfChanged() void {
    const menuTime = window.statFileTime("src/zon/menu.zon");
    const linkTime = window.statFileTime("src/zon/link.zon");
    const time = @max(menuTime, linkTime);

    if (time > modifyTime) {
        _ = arenaAllocator.reset(.retain_capacity);
        menu.reload(arenaAllocator.allocator());
        player.position = map.reload(arenaAllocator.allocator());
        modifyTime = time;
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
        window.isMouseRelease(.RIGHT))
    {
        status = .normal;
        return;
    }

    if (about.roll) {
        about.update(delta);
    } else {
        if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER }) or
            window.isMouseRelease(.LEFT))
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
    const menuEvent = menu.update();
    if (menuEvent) |event| menuSelected(event);

    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
        window.isMouseRelease(.RIGHT))
    {
        status = .normal;
    }
}

fn menuSelected(index: usize) void {
    switch (index) {
        0 => status = .status,
        1 => status = .item,
        2...3 => status = .normal,
        4 => {
            status = .about;
            about.resetRoll();
        },
        5 => window.exit(),
        6 => status = .normal,
        else => unreachable,
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
    menu.draw();
}
