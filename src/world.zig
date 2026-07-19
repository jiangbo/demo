const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;

const scene = @import("scene.zig");
const component = @import("component.zig");
const menu = @import("menu.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const talk = @import("talk.zig");
const about = @import("about.zig");
const item = @import("item.zig");
const input = @import("input.zig");
const factory = @import("factory.zig");
const system = @import("system/system.zig");
const context = @import("context.zig");

const Collider = component.Collider;
const Enemy = component.Enemy;
const Facing = component.Facing;
const Actor = component.Actor;
const Player = component.Player;
const Position = component.Position;
const Talk = component.Talk;

const State = union(enum) {
    map: MapState,
    menu: MenuState,
    status,
    item,
    load: LoadState,
    save: SaveState,
    about: AboutState,
    talk: TalkState,
    shop,
    sale: SaleState,

    pub fn update(self: State, world: *ecs.World, delta: f32) void {
        switch (self) {
            .map => MapState.update(world, delta),
            .save => SaveState.update(world, delta),
            .talk => TalkState.update(world, delta),
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
var texture: zhu.Image = undefined;
var state: State = .map;
pub var back: enum { none, talk, battle, menu } = .none;
pub var tip: []const u8 = &.{};
var header: []const u8 = &.{};
var headerIndex: usize = 0;
var headerTimer: zhu.Timer = .init(0.08);
var headerColor: zhu.Color = .white;
// 已经死亡的 NPC 在地图重建后不再生成。
var deadActors: std.StaticBitSet(64) = .initEmpty();

pub fn killActor(key: factory.Key) void {
    deadActors.set(@intFromEnum(key));
}

pub fn init(_: *ecs.World) void {
    texture = zhu.getImage("mainmenu1.png").?;

    item.init();
    talk.init();
    about.init();
    map.init();
    player.init();
}

pub fn deinit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn enter(world: *ecs.World) void {
    var playerPosition = map.enter();
    if (loadPlayerPosition) |position| {
        playerPosition = position;
    } else if (back != .none) {
        playerPosition = player.collider(world).min;
    }
    loadPlayerPosition = null;

    switch (back) {
        .none => {
            context.oldMapIndex = 0;
            talk.start(2);
            state = .talk;
        },
        .talk => talk.next(),
        .battle => state = .map,
        .menu => state = .menu,
    }
    rebuildMap(world, playerPosition);
    menu.active = 6;
    zhu.audio.playMusic("voc/back.ogg");
}

pub fn changeMap(world: *ecs.World) void {
    const playerPosition = map.enter();
    rebuildMap(world, playerPosition);
}

// 清空旧地图并创建新地图的实体。
fn rebuildMap(world: *ecs.World, playerPosition: zhu.Vector2) void {
    world.reset();
    factory.spawnPlayer(world, playerPosition);

    for (map.current.actors) |key| {
        const index = @intFromEnum(key);
        if (deadActors.isSet(index)) continue;
        if (factory.get(key).progress < player.progress) continue;
        factory.spawnActor(world, key);
    }
    player.cameraLookAt(world);
}

pub fn exit() void {}

pub fn update(world: *ecs.World, delta: f32) void {
    if (tip.len != 0) {
        if (input.released(.confirm) or input.released(.cancel)) {
            tip = &.{};
        } else return;
    }

    if (header.len != 0) {
        if (header.len == headerIndex) {
            // 已经显示结束了，等待按键
            if (input.released(.confirm)) {
                if (player.progress > 20)
                    // 如果打败了大魔王，跳转到标题界面
                    scene.changeScene(.title)
                else {
                    header = &.{};
                    state = .map;
                }
            }
        } else if (headerTimer.updateFinished(delta)) {
            // 没有显示结束，继续显示
            const len = std.unicode.utf8ByteSequenceLength(
                header[headerIndex],
            ) catch unreachable;
            headerIndex += len;
            headerTimer.restart();
        }
        return;
    }

    //  map: MapState,
    // menu: MenuState,
    // status,
    // item,
    // load: LoadState,
    // save: SaveState,
    // about: AboutState,
    // talk: TalkState,
    // shop,
    // sale: SaleState,

    if (state == .map or state == .status or state == .item or
        state == .about)
    {
        if (input.released(.menu) or input.released(.cancel) or
            input.mouseReleased(.RIGHT))
        {
            state = .menu;
            return;
        }
    }

    state.update(world, delta);
}

pub fn draw(world: *ecs.World) void {
    map.draw();
    system.render.draw(world);

    camera.push(.window);
    defer camera.pop();
    if (tip.len != 0) {
        zhu.text.msdf.begin();
        zhu.text.draw(tip, .xy(242, 442), .{ .color = .black });
        zhu.text.draw(tip, .xy(240, 440), .{ .color = .yellow });
        zhu.text.msdf.end();
    }
    state.draw();
    if (header.len != 0) {
        zhu.text.msdf.begin();
        zhu.text.draw(header[0..headerIndex], .xy(80, 100), .{
            .max = 520,
            .color = headerColor,
        });
        zhu.text.msdf.end();
    }
}

const MapState = struct {
    var warn: bool = false;

    fn update(world: *ecs.World, delta: f32) void {
        system.update(world, delta);
        player.cameraLookAt(world);

        // 检测是否需要切换地图
        const entity = world.getIdentity(Player).?;
        const position = world.get(entity, Position).?;
        const facing = world.get(entity, Facing).?;
        const collider = world.get(entity, Collider).?;
        const area = collider.move(position);
        const object = map.getObject(map.positionIndex(area.center()));
        if (object > 4) {
            if (!warn) return changeMapIfNeed(object);
        } else warn = false;

        if (world.getIdentity(Enemy)) |target| {
            world.removeIdentity(Enemy);
            const targetActor = world.get(target, Actor).?;
            const actor = factory.get(targetActor.key);
            // 是否需要对话
            if (actor.dialogues.len != 0) {
                talk.start(actor.dialogues[0]);
                state = .talk;
            } else {
                context.oldMapIndex = map.linkIndex;
                context.battleActorKey = targetActor.key;
                back = .battle;
                scene.changeScene(.battle);
            }
            return;
        }

        if (world.getIdentity(Talk)) |target| {
            const targetActor = world.get(target, Actor).?;
            const index: u8 = if (player.progress > 4) 1 else 0;
            const actor = factory.get(targetActor.key);
            talk.start(actor.dialogues[index]);
            state = .talk;
            return;
        }

        // 交互检测
        if (!input.released(.confirm)) return;
        // 开启宝箱
        const talkObject = map.talk(area.min, facing);
        if (talkObject) |pickupIndex| openChest(pickupIndex);
    }

    fn changeMapIfNeed(object: u8) void {
        const link = map.links[object];
        if (player.progress > link.progress) {
            std.log.info("change map link index: {d}", .{object});
            map.linkIndex = object;
            scene.changeMap();
            return;
        }

        if (player.progress == 1) {
            warn = true;
            talk.start(5);
            state = .talk;
        }

        if (player.progress == 4) {
            player.progress += 1;
            talk.start(32);
            state = .talk;
        }

        if (player.progress == 10) {
            warn = true;
            talk.start(37);
            state = .talk;
        }
    }

    fn openChest(pickIndex: u16) void {
        const object = item.pickupZon[pickIndex];

        if (object.itemIndex == 0 and object.count == 0) {
            const gold = zhu.random.int(u8, 10, 100);
            player.money += gold;
            talk.startNumber(0, gold);
            state = .talk;
        } else {
            const added = player.addItem(object.itemIndex);
            if (!added) {
                tip = "你已经带满了！";
                return;
            }
            talk.startText(1, item.zon[object.itemIndex].name);
            state = .talk;
        }
        map.openChest(pickIndex);
    }
};

const MenuState = struct {
    fn update(_: f32) void {
        const menuEvent = menu.update();
        if (menuEvent) |event| switch (event) {
            0 => state = .status,
            1 => state = .item,
            2 => {
                menu.active = 5;
                state = .load;
            },
            3 => {
                menu.active = 5;
                state = .save;
            },
            4 => {
                about.resetRoll();
                state = .about;
            },
            5 => window.exit(),
            6 => state = .map,
            else => unreachable,
        };

        if (input.released(.menu) or input.released(.cancel) or
            input.mouseReleased(.RIGHT))
        {
            state = .map;
        }
    }

    fn draw() void {
        zhu.batch.drawImage(texture, .xy(0, 280), .{});
        menu.draw();
    }
};

var loadPlayerPosition: ?math.Vector2 = null;
const LoadState = struct {
    pub fn update(_: f32) void {
        const loadEvent = menu.update();
        if (loadEvent) |event| switch (event) {
            3...7 => |index| {
                back = .menu;
                scene.changeScene(.world);
                load(index) catch {
                    menu.active = 6;
                    state = .menu;
                };
            },
            8 => {
                menu.active = 6;
                state = .menu;
            },
            else => unreachable,
        };

        if (input.released(.menu) or input.released(.cancel) or
            input.mouseReleased(.RIGHT))
        {
            menu.active = 6;
            state = .menu;
        }
    }

    pub fn draw() void {
        zhu.batch.drawImage(texture, .xy(0, 280), .{});
        menu.draw();
    }
};

const magic = [2]u8{ 0xB0, 0x0B };
pub fn load(index: u8) !void {
    var buffer: [100]u8 = undefined;
    var buf: [20]u8 = undefined;
    const path = zhu.formatZ(&buf, "save/{d}.save", .{index - 2});
    const slice = try window.readBuffer(path, &buffer);
    var reader = std.Io.Reader.fixed(slice);

    // 1. magic
    var magic_buf: [magic.len]u8 = undefined;
    try reader.readSliceAll(&magic_buf);
    if (!std.mem.eql(u8, &magic_buf, &magic)) return error.InvalidMagic;

    // 2. 游戏版本号
    var version: [2]u8 = undefined;
    try reader.readSliceAll(&version);

    // 3. 地图编号
    map.linkIndex = try reader.takeByte();
    // 4. 玩家进度
    player.progress = try reader.takeByte();
    // 5. 玩家坐标
    var pos: math.Vector2 = undefined;
    try reader.readSliceAll(std.mem.asBytes(&pos));
    loadPlayerPosition = pos;
    // 6. 玩家经验
    try reader.readSliceAll(std.mem.asBytes(&player.exp));
    // 7. 玩家等级
    try reader.readSliceAll(std.mem.asBytes(&player.level));
    // 8. 玩家生命
    try reader.readSliceAll(std.mem.asBytes(&player.health));
    // 9. 玩家最大生命
    try reader.readSliceAll(std.mem.asBytes(&player.maxHealth));
    // 10. 玩家攻击力
    try reader.readSliceAll(std.mem.asBytes(&player.attack));
    // 11. 玩家防御力
    try reader.readSliceAll(std.mem.asBytes(&player.defend));
    // 12. 玩家速度
    try reader.readSliceAll(std.mem.asBytes(&player.speed));
    // 13. 玩家金钱
    try reader.readSliceAll(std.mem.asBytes(&player.money));
    // 14. 玩家物品
    try reader.readSliceAll(std.mem.asBytes(&player.items));
    // 15. 宝箱状态
    try reader.readSliceAll(std.mem.asBytes(&item.picked));
    // 16. NPC 状态
    try reader.readSliceAll(std.mem.asBytes(&deadActors));
    // 17. magic 结尾
    var magic_end: [magic.len]u8 = undefined;
    try reader.readSliceAll(&magic_end);
    if (!std.mem.eql(u8, &magic_end, &magic)) return error.InvalidMagic;
}

const SaveState = struct {
    var buffer: [100]u8 = undefined;

    pub fn update(world: *ecs.World, _: f32) void {
        const saveEvent = menu.update();
        if (saveEvent) |event| switch (event) {
            3...7 => |index| {
                back = .menu;
                scene.changeScene(.world);
                save(world, index) catch @panic("save failed");
            },
            8 => {
                menu.active = 6;
                state = .menu;
            },
            else => unreachable,
        };

        if (input.released(.menu) or input.released(.cancel) or
            input.mouseReleased(.RIGHT))
        {
            menu.active = 6;
            state = .menu;
        }
    }

    fn save(world: *ecs.World, index: u8) !void {
        var writer = std.Io.Writer.fixed(&buffer);
        try writer.writeAll(&magic);
        //  游戏版本号
        try writer.writeAll(&.{ 0x00, 0x00 });
        //  地图编号
        try writer.writeByte(map.linkIndex);
        //  玩家进度
        try writer.writeByte(player.progress);
        //  玩家坐标
        const position = player.collider(world).min;
        try writer.writeAll(std.mem.asBytes(&position));
        //  玩家经验
        try writer.writeAll(std.mem.asBytes(&player.exp));
        //  玩家等级
        try writer.writeAll(std.mem.asBytes(&player.level));
        //  玩家生命
        try writer.writeAll(std.mem.asBytes(&player.health));
        // 玩家最大生命
        try writer.writeAll(std.mem.asBytes(&player.maxHealth));
        //  玩家攻击力
        try writer.writeAll(std.mem.asBytes(&player.attack));
        //  玩家防御力
        try writer.writeAll(std.mem.asBytes(&player.defend));
        //  玩家速度
        try writer.writeAll(std.mem.asBytes(&player.speed));
        //  玩家金钱
        try writer.writeAll(std.mem.asBytes(&player.money));
        //  玩家物品
        try writer.writeAll(std.mem.asBytes(&player.items));
        //  宝箱状态
        try writer.writeAll(std.mem.asBytes(&item.picked));
        //  NPC 状态
        try writer.writeAll(std.mem.asBytes(&deadActors));
        try writer.writeAll(&magic);

        var buf: [20]u8 = undefined;
        const path = zhu.formatZ(&buf, "save/{d}.save", .{index - 2});
        try window.saveAll(path, buffer[0..writer.end]);
    }

    pub fn draw() void {
        zhu.batch.drawImage(texture, .xy(0, 280), .{});
        menu.draw();
    }
};

const TalkState = struct {
    fn update(world: *ecs.World, _: f32) void {
        const talkEvent = talk.update();
        if (talkEvent) |event| switch (event) {
            .finish => {
                world.removeIdentity(Talk);
                state = .map;
            },
            .openWeaponShop, .openPotionShop => {
                state = .shop;
                shop = if (event == .openWeaponShop)
                    &weaponShop
                else
                    &potionShop;
            },
            .openSale => state = .sale,
            .startBattleThenTalk, .startBattleThenMap => {
                world.removeIdentity(Talk);
                context.oldMapIndex = map.linkIndex;
                context.battleActorKey = talk.recentActor();
                back = if (event == .startBattleThenTalk)
                    .talk
                else
                    .battle;
                scene.changeScene(.battle);
            },
            .showSwordTip => {
                world.removeIdentity(Talk);
                // 打败了巫批，对话完成
                header = "　　太好了！终于找到了失落已久的“圣剑”，就用它的威力把大魔王彻底杀死吧！　";
                headerColor = .white;
                headerTimer.restart();
            },
            .showEnding => {
                world.removeIdentity(Talk);
                // 打败了大魔王
                header =
                    \\　　祝贺你成功打爆试玩版！详细情况请看Readme.txt
                    \\敬请关注该游戏的最新动态：
                    \\　　http://goldpoint.126.com
                    \\　　　　　　　　　　　　　成都金点工作组制作
                    \\　　　　　　　　　　　　　[THE END]
                ;
                headerColor = .red;
                headerTimer.restart();
            },
        };
    }
};

const AboutState = struct {
    fn update(delta: f32) void {
        if (about.roll) about.update(delta) //
        else if (input.mouseReleased(.LEFT) or
            input.released(.confirm))
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

        if (input.released(.menu) or input.released(.cancel) or
            input.mouseReleased(.RIGHT))
        {
            talk.start(if (sell) 27 else 26);
            state = .talk;
            sell = false;
        }
    }
};

const Shop = struct {
    var bought: bool = false;
    items: [16]u8,
    current: u8 = 0,
    notBoughtDialogue: u16,
    boughtDialogue: u16,

    pub fn update(self: *Shop) void {
        self.current = item.update(self.items.len, self.current);

        if (input.released(.buyItem)) {
            const itemIndex = self.items[self.current];
            if (itemIndex != 0) {
                const playerBuy = buy(itemIndex);
                if (!bought) bought = playerBuy;
            }
        }

        if (input.released(.menu) or input.released(.cancel)) {
            const dialogue = if (bought)
                self.boughtDialogue
            else
                self.notBoughtDialogue;
            talk.start(dialogue);
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
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        var buffer: [20]u8 = undefined;
        // 金币，操作说明
        zhu.text.draw("（金=", item.position.addXY(10, 270), .{});
        const moneyStr = zhu.format(&buffer, "{d}）", .{player.money});
        zhu.text.draw(moneyStr, item.position.addXY(60, 270), .{});
        const text = "CTRL=购买　　ESC=退出";
        zhu.text.draw(text, item.position.addXY(118, 270), .{});
    }
};
var weaponShop: Shop = .{
    .items = .{
        12, 12, 13, 13, 14, 14, 9, 9, //
        10, 10, 8,  8,  16, 16, 0, 0,
    },
    .notBoughtDialogue = 18,
    .boughtDialogue = 19,
};
var potionShop: Shop = .{
    .items = .{
        5,  5,  6,  6,  7, 7, 4, 4, //
        17, 17, 18, 18, 0, 0, 0, 0,
    },
    .notBoughtDialogue = 22,
    .boughtDialogue = 23,
};
var shop: *Shop = undefined;
