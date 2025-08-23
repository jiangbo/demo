const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const talk = @import("talk.zig");
const about = @import("about.zig");
const item = @import("item.zig");
const npc = @import("npc.zig");
const context = @import("context.zig");

const State = union(enum) {
    map: MapState,
    menu: MenuState,
    status,
    // talk,
    // about,
    // item,
    // shop,
    // sale,

    pub fn update(self: State, delta: f32) void {
        switch (self) {
            .status => {},
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    pub fn draw(self: State) void {
        switch (self) {
            .map => {},
            .status => player.drawStatus(),
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};
var state: State = .map;

var menuTexture: gfx.Texture = undefined;
var arenaAllocator: std.heap.ArenaAllocator = undefined;

const Shop = struct {
    items: [16]u8,
    current: u8 = 0,

    pub fn update(self: *Shop) void {
        self.current = item.update(self.items.len, self.current);

        if (window.isAnyKeyRelease(&.{ .LEFT_CONTROL, .F, .ENTER })) {
            const itemIndex = self.items[self.current];
            if (itemIndex != 0) buy(itemIndex);
        }

        if (window.isAnyKeyRelease(&.{ .Q, .E, .ESCAPE })) state = .none;
    }

    fn buy(itemIndex: u8) void {
        const buyItem = item.zon[itemIndex];

        if (buyItem.money > player.money) {
            tip = "兄弟，你的钱不够！";
            return;
        }

        const bagEnough = player.addItem(itemIndex);
        if (!bagEnough) {
            tip = "你已经带满了！";
            return;
        }
        player.money -= buyItem.money;
    }

    pub fn draw(self: *const Shop) void {
        item.draw(&self.items, self.current);
        var buffer: [20]u8 = undefined;
        // 金币，操作说明
        camera.drawText("（金=", item.position.addXY(10, 270));
        const moneyStr = zhu.format(&buffer, "{d}）", .{player.money});
        camera.drawText(moneyStr, item.position.addXY(60, 270));
        const text = "CTRL=购买　　ESC=退出";
        camera.drawText(text, item.position.addXY(118, 270));
    }
};
var weaponShop: Shop = .{
    .items = .{
        12, 12, 13, 13, 14, 14, 9, 9, //
        10, 10, 8,  8,  16, 16, 0, 0,
    },
};
var potionShop: Shop = .{
    .items = .{
        5,  5,  6,  6,  7, 7, 4, 4, //
        17, 17, 18, 18, 0, 0, 0, 0,
    },
};
var shop: *Shop = undefined;

var tip: []const u8 = &.{};

pub fn init() void {
    arenaAllocator = std.heap.ArenaAllocator.init(window.allocator);
    menuTexture = gfx.loadTexture("assets/pic/mainmenu1.png", .init(150, 200));

    item.init();
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
    if (context.oldMapIndex != 0) {
        // 从战斗中退出，不需要改变角色的位置信息
        map.linkIndex = context.oldMapIndex;
        _ = map.enter();

        return;
    }

    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
    menu.active = 6;
    // window.playMusic("assets/voc/back.ogg");

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

    if (state != .menu) {
        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            state = .menu;
            return;
        }
    }

    state.update(delta);

    // if (tip.len != 0) {
    //     if (window.isAnyRelease()) tip = &.{};
    //     return;
    // }

    // switch (state) {
    //     .none => {},
    //     .talk => return updateTalk(),
    //     .item => return updateItem(),
    //     .shop => return shop.update(),
    //     .status => {
    //         return if (window.isMouseRelease(.RIGHT) or
    //             window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .SPACE }))
    //         {
    //             state = .none;
    //         };
    //     },
    //     .menu => return updateMenu(),
    //     .about => return updateAbout(delta),
    //     .sale => return updateSale(),
    // }

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
        if (event != 0) state = .shop;

        switch (event) {
            0 => state = .none,
            4 => shop = &weaponShop,
            5 => shop = &potionShop,
            6 => state = .sale,
            7 => {
                context.oldMapIndex = map.linkIndex;
                context.battleNpcIndex = talk.actor;
                state = .none;
                scene.changeScene(.battle);
            },
            else => unreachable,
        }
    }
}

fn updateItem() void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) {
        state = .none;
        player.itemIndex = 0;
        return;
    }
    _ = player.openItem();
}

fn updateSale() void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) {
        state = .none;
        player.itemIndex = 0;
        return;
    }
    player.sellItem();
}

fn updateAbout(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q }) or
        window.isMouseRelease(.RIGHT))
    {
        state = .none;
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
        state = .talk;
    } else {
        const added = player.addItem(object.itemIndex);
        if (!added) {
            tip = "你已经带满了！";
            return;
        }
        talk.activeText(3, item.zon[object.itemIndex].name);
        state = .talk;
    }
    map.openChest(pickIndex);
}

pub fn draw() void {
    map.draw();
    npc.draw();
    player.draw();

    camera.mode = .local;
    defer camera.mode = .world;
    state.draw();

    // if (tip.len != 0) {
    //     camera.drawColorText(tip, .init(242, 442), .black);
    //     camera.drawColorText(tip, .init(240, 440), .yellow);
    // }

    // switch (state) {
    //     .none => {},
    //     .talk => talk.draw(),
    //     .item => player.drawOpenItem(),
    //     .shop => shop.draw(),
    //     .about => about.draw(),
    //     .sale => player.drawSellItem(),
    // }
}

const MapState = struct {
    fn update(delta: f32) void {
        npc.update(delta);
        player.update(delta);

        // 交互检测
        // const confirm = window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
        // if (confirm) {
        //     // 开启宝箱
        //     const object = map.talk(player.position, player.facing);
        //     if (object) |pickupIndex| openChest(pickupIndex);
        // }

        // if (confirm) {
        //     // 和 NPC 对话
        //     if (npc.talk(player.talkCollider(), player.facing)) |talkId| {
        //         talk.active = talkId;
        //         state = .talk;
        //     }
        // }

    }
};

const MenuState = struct {
    fn update(_: f32) void {
        const menuEvent = menu.update();
        if (menuEvent) |event| switch (event) {
            0 => state = .status,
            // 1 => state = .item,
            // 2...3 => state = .none,
            // 4 => {
            //     state = .about;
            //     about.resetRoll();
            // },
            // 5 => window.exit(),
            6 => state = .map,
            else => unreachable,
        };

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            state = .map;
        }
    }

    fn draw() void {
        camera.draw(menuTexture, .init(0, 280));
        menu.draw();
    }
};

const TalkState = struct {
    fn update(_: f32) void {
        updateTalk();
    }
};

const ItemState = struct {
    fn update(_: f32) void {
        updateItem();
    }
};

const SaleState = struct {
    fn update(_: f32) void {
        updateSale();
    }
};

const AboutState = struct {
    fn update(delta: f32) void {
        updateAbout(delta);
    }
};
