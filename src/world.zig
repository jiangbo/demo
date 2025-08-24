const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

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
    item,
    about: AboutState,
    talk: TalkState,
    shop,
    sale: SaleState,

    pub fn update(self: State, delta: f32) void {
        switch (self) {
            .status => {},
            .item => _ = player.openItem(),
            .shop => shop.update(),
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    pub fn draw(self: State) void {
        switch (self) {
            .map => {},
            .status => player.drawStatus(),
            .item => player.drawOpenItem(),
            .about => about.draw(),
            .talk => talk.draw(),
            .sale => player.drawSellItem(),
            .shop => shop.draw(),
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};

var state: State = .map;
var back: enum { none, talk } = .none;
var arenaAllocator: std.heap.ArenaAllocator = undefined;
var tip: []const u8 = &.{};

pub fn init() void {
    arenaAllocator = std.heap.ArenaAllocator.init(window.allocator);
    MenuState.texture = gfx.loadTexture("assets/pic/mainmenu1.png", .init(150, 200));

    item.init();
    talk.init();
    about.init();
    map.init();
    player.init();
    npc.init();
}

pub fn deinit() void {
    arenaAllocator.deinit();
    window.stopMusic();
}

pub fn enter() void {
    switch (back) {
        .none => {
            const playerPosition = map.enter();
            player.enter(playerPosition);
            window.playMusic("assets/voc/back.ogg");
        },
        .talk => talk.activeNext(),
    }
    npc.enter();
    menu.active = 6;
}

pub fn changeMap() void {
    const playerPosition = map.enter();
    player.enter(playerPosition);
    npc.enter();
}

pub fn exit() void {}

pub fn update(delta: f32) void {
    reloadIfChanged();

    if (tip.len != 0) {
        if (window.isAnyRelease()) tip = &.{};
        return;
    }

    if (state != .menu and state != .sale and state != .shop) {
        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            state = .menu;
            return;
        }
    }

    state.update(delta);
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

pub fn draw() void {
    map.draw();
    npc.draw();
    player.draw();

    camera.mode = .local;
    defer camera.mode = .world;
    if (tip.len != 0) {
        camera.drawColorText(tip, .init(242, 442), .black);
        camera.drawColorText(tip, .init(240, 440), .yellow);
    }
    state.draw();
}

const MapState = struct {
    var warn: bool = false;

    fn update(delta: f32) void {
        npc.update(delta);
        player.update(delta);

        // 检测是否需要切换地图
        const area = math.Rect.init(player.position, player.SIZE);
        const object = map.getObject(map.positionIndex(area.center()));
        if (object > 4) return changeMapIfNeed(object) else warn = false;

        // 交互检测
        if (!window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) return;
        // 开启宝箱
        const talkObject = map.talk(player.position, player.facing);
        if (talkObject) |pickupIndex| openChest(pickupIndex);

        // 和 NPC 对话
        if (npc.talk(player.talkCollider(), player.facing)) |talkId| {
            talk.active = talkId;
            state = .talk;
        }
    }

    fn changeMapIfNeed(object: u16) void {
        // 切换场景，检查是否有进度要求

        const link = map.links[object];
        if (player.progress > link.progress) {
            std.log.info("change map link index: {d}", .{object});
            map.linkIndex = object;
            scene.changeMap();
            return;
        }

        if (!warn and player.progress == 0) {
            warn = true;
            talk.active = 17;
            state = .talk;
        }

        if (player.progress == 4) {
            player.progress += 1;
            talk.active = 18;
            state = .talk;
        }
    }

    fn openChest(pickIndex: u16) void {
        const object = item.pickupZon[pickIndex];

        if (object.itemIndex == 0 and object.count == 0) {
            const gold = math.randU8(10, 100);
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
};

const MenuState = struct {
    var texture: gfx.Texture = undefined;

    fn update(_: f32) void {
        const menuEvent = menu.update();
        if (menuEvent) |event| switch (event) {
            0 => state = .status,
            1 => state = .item,
            2...3 => state = .map,
            4 => {
                about.resetRoll();
                state = .about;
            },
            5 => window.exit(),
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
        camera.draw(texture, .init(0, 280));
        menu.draw();
    }
};

const TalkState = struct {
    fn update(_: f32) void {
        const talkEvent = talk.update();
        if (talkEvent) |event| switch (event) {
            0 => state = .map,
            4, 5 => |t| {
                state = .shop;
                shop = if (t == 4) &weaponShop else &potionShop;
            },
            6 => state = .sale,
            7 => {
                context.oldMapIndex = map.linkIndex;
                context.battleNpcIndex = talk.actor;
                back = .talk;
                scene.changeScene(.battle);
            },
            else => unreachable,
        };
    }
};

const AboutState = struct {
    fn update(delta: f32) void {
        if (about.roll) about.update(delta) //
        else if (window.isMouseRelease(.LEFT) or
            window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER }))
        {
            about.roll = true;
        }
    }
};

const SaleState = struct {
    var sell: bool = false;

    fn update(_: f32) void {
        const playerSell = player.sellItem();
        if (!sell) sell = playerSell;

        if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }) or
            window.isMouseRelease(.RIGHT))
        {
            talk.activeNext();
            if (sell) talk.activeNext();
            state = .talk;
            sell = false;
        }
    }
};

const Shop = struct {
    var bought: bool = false;
    items: [16]u8,
    current: u8 = 0,
    notBuyId: u16,
    buyId: u16,

    pub fn update(self: *Shop) void {
        self.current = item.update(self.items.len, self.current);

        if (window.isAnyKeyRelease(&.{ .LEFT_CONTROL, .F, .ENTER })) {
            const itemIndex = self.items[self.current];
            if (itemIndex != 0) {
                const playerBuy = buy(itemIndex);
                if (!bought) bought = playerBuy;
            }
        }

        if (window.isAnyKeyRelease(&.{ .Q, .E, .ESCAPE })) {
            talk.active = if (bought) self.buyId else self.notBuyId;
            state = .talk;
            bought = false;
        }
    }

    fn buy(itemIndex: u8) bool {
        const buyItem = item.zon[itemIndex];

        if (buyItem.money > player.money) {
            tip = "兄弟，你的钱不够！";
            return false;
        }

        const bagEnough = player.addItem(itemIndex);
        if (!bagEnough) {
            tip = "你已经带满了！";
            return false;
        }
        player.money -= buyItem.money;
        return true;
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
    .notBuyId = 117,
    .buyId = 119,
};
var potionShop: Shop = .{
    .items = .{
        5,  5,  6,  6,  7, 7, 4, 4, //
        17, 17, 18, 18, 0, 0, 0, 0,
    },
    .notBuyId = 130,
    .buyId = 132,
};
var shop: *Shop = undefined;
