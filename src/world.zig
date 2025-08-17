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

const Status = union(enum) { talk, menu, about, status, item };
var status: ?Status = null;

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

    // status = .item;
}

pub fn deinit() void {
    npc.deinit();
    arenaAllocator.deinit();
    window.stopMusic();
}

pub fn enter() void {
    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
    menu.active = 6;
    window.playMusic("assets/voc/back.ogg");

    // talk.active = 4;
    // status = .talk;
}

pub fn changeMap() void {
    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
}

pub fn exit() void {}

pub fn update(delta: f32) void {
    reloadIfChanged();

    if (status == null or status.? != .menu) {
        if (window.isMouseRelease(.RIGHT) or
            window.isAnyKeyRelease(&.{ .ESCAPE, .E }))
        {
            status = .menu;
            menu.active = 6;
            return;
        }
    }

    if (status) |pop| {
        switch (pop) {
            .talk => return updateTalk(),
            .item => return updateItem(),
            .status => {
                return if (window.isMouseRelease(.RIGHT) or
                    window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .SPACE }))
                {
                    status = null;
                };
            },
            .menu => return updateMenu(),
            .about => return updateAbout(delta),
        }
    }

    npc.update(delta);
    player.update(delta);

    // 交互检测
    const confirm = window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
    if (confirm) {
        // 开启宝箱
        const object = map.openChest(player.position, player.facing);
        if (object != 0) openChest(object);
    }

    if (confirm) {
        // 和 NPC 对话
        if (npc.talk(player.talkCollider(), player.facing)) |talkId| {
            talk.active = talkId;
            status = .talk;
        }
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

fn updateTalk() void {
    const talkEvent = talk.update();
    if (talkEvent) |event| {
        switch (event) {
            0 => status = null,
            else => unreachable,
        }
    }
}

fn updateItem() void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) {
        status = null;
        return;
    }
    player.updateItem();
}

fn updateAbout(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q }) or
        window.isMouseRelease(.RIGHT))
    {
        status = null;
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
        talk.activeNumber(2, gold);
        status = .talk;
    } else {
        player.addItem(object.itemIndex);
        talk.activeText(3, item.zon[object.itemIndex].name);
        status = .talk;
    }
}

fn updateMenu() void {
    const menuEvent = menu.update();
    if (menuEvent) |event| menuSelected(event);

    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
        window.isMouseRelease(.RIGHT))
    {
        status = null;
    }
}

fn menuSelected(index: usize) void {
    switch (index) {
        0 => status = .status,
        1 => status = .item,
        2...3 => status = null,
        4 => {
            status = .about;
            about.resetRoll();
        },
        5 => window.exit(),
        6 => status = null,
        else => unreachable,
    }
}

pub fn draw() void {
    map.draw();
    npc.draw();
    player.draw();

    if (status == null) return;

    camera.mode = .local;
    defer camera.mode = .world;
    switch (status.?) {
        .talk => talk.draw(),
        .status => player.drawStatus(),
        .item => player.drawItem(),
        .menu => {
            camera.draw(menuTexture, .init(0, 280));
            menu.draw();
        },
        .about => about.draw(),
    }
}
