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
const about = @import("about.zig");
const item = @import("item.zig");
const input = @import("zon.zig").input;
const factory = @import("factory.zig");
const system = @import("system/system.zig");
const context = @import("context.zig");
const dialogUi = @import("ui/dialog.zig");

const dialog = component.dialog;
const Collider = component.Collider;
const Dialog = dialog.Dialog;
const Enemy = component.Enemy;
const Facing = component.Facing;
const Actor = component.Actor;
const Interact = component.Interact;
const Player = component.Player;
const Position = component.Position;

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
            .talk => {},
            .status => {},
            .item => _ = player.openItem(),
            .shop => shop.update(world),
            .sale => SaleState.update(world, delta),
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    pub fn draw(self: State, world: *ecs.World) void {
        switch (self) {
            .map => {},
            .status => player.drawStatus(),
            .item => player.drawOpenItem(),
            .about => about.draw(),
            .talk => dialogUi.draw(world),
            .sale => player.drawSellItem(),
            .shop => shop.draw(),
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};
var texture: zhu.Image = undefined;
var state: State = .map;
pub var back: enum { none, battle, load, menu } = .none;
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
    dialogUi.init();
    about.init();
    map.init();
    player.init();
}

pub fn deinit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn enter(world: *ecs.World) void {
    const playerPosition = map.enter();
    switch (back) {
        .none => {
            rebuildMap(world, playerPosition);
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[2].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        },
        .battle => finishBattle(world),
        .load => {
            rebuildMap(world, loadPlayerPosition.?);
            state = .map;
        },
        .menu => {
            if (loadPlayerPosition) |position| {
                rebuildMap(world, position);
            }
            state = .menu;
        },
    }
    loadPlayerPosition = null;
    player.cameraLookAt(world);
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
    world.entity = world.createEntity();
    factory.spawnPlayer(world, playerPosition);

    for (map.current.actors) |key| {
        const index = @intFromEnum(key);
        if (deadActors.isSet(index)) continue;
        if (factory.get(key).progress < player.progress) continue;
        factory.spawnActor(world, key);
    }
    player.cameraLookAt(world);
}

// 处理战斗结果并继续使用进入战斗前的地图实体。
fn finishBattle(world: *ecs.World) void {
    const actorEntity = findBattleActor(world);

    switch (context.battle.result) {
        .fighting => unreachable,
        .win => {
            if (world.getIdentity(Interact)) |entity| {
                if (entity == actorEntity) {
                    world.removeIdentity(Interact);
                }
            }
            world.destroyEntity(actorEntity);
            state = if (world.has(world.entity, Dialog)) .talk else .map;
        },
        .escape => {
            world.getPtr(actorEntity, Enemy).?.wait = 0.5;
            if (world.has(world.entity, Dialog)) {
                world.remove(world.entity, Dialog);
                world.remove(world.getIdentity(Player).?, Interact.Disabled);
            }
            world.removeIdentity(Interact);
            state = .map;
        },
    }
}

// 根据稳定人物标识查找当前地图中的战斗实体。
fn findBattleActor(world: *ecs.World) ecs.Entity {
    var query = world.query(.{Actor});
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        if (actor.key == context.battle.actor) return entity;
    }
    unreachable;
}

test "战斗胜利后保留对话并删除人物实体" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    const playerEntity = world.createIdentity(Player);
    world.add(world.entity, Dialog{
        .lines = factory.dialogues[36].lines,
    });
    world.add(playerEntity, Interact.Disabled{});
    const actorEntity = world.createEntity();
    world.add(actorEntity, Actor{ .key = .wuPi });

    context.battle = .{
        .actor = .wuPi,
        .mapIndex = 0,
        .result = .win,
    };

    finishBattle(&world);

    try std.testing.expect(state == .talk);
    try std.testing.expect(world.has(world.entity, Dialog));
    try std.testing.expect(world.has(playerEntity, Interact.Disabled));
    try std.testing.expect(!world.has(actorEntity, Actor));
}

test "战斗胜利后没有对话则返回地图" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    const actorEntity = world.createEntity();
    world.add(actorEntity, Actor{ .key = .senLin_feiJiangJun1 });

    context.battle = .{
        .actor = .senLin_feiJiangJun1,
        .mapIndex = 0,
        .result = .win,
    };

    finishBattle(&world);

    try std.testing.expect(state == .map);
    try std.testing.expect(!world.has(actorEntity, Actor));
}

test "逃跑后关闭对话并保留冷却中的敌人" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    const playerEntity = world.createIdentity(Player);
    world.add(world.entity, Dialog{
        .lines = factory.dialogues[36].lines,
    });
    world.add(playerEntity, Interact.Disabled{});
    const actorEntity = world.createEntity();
    world.addAll(actorEntity, .{
        Actor{ .key = .wuPi },
        Enemy{ .value = .init(.zero, .xy(48, 48)) },
        Interact{},
    });
    world.addIdentity(actorEntity, Interact);

    context.battle = .{
        .actor = .wuPi,
        .mapIndex = 0,
        .result = .escape,
    };

    finishBattle(&world);

    try std.testing.expect(state == .map);
    try std.testing.expect(!world.has(world.entity, Dialog));
    try std.testing.expect(!world.has(playerEntity, Interact.Disabled));
    try std.testing.expectEqual(null, world.getIdentity(Interact));
    try std.testing.expectEqual(
        @as(f32, 0.5),
        world.get(actorEntity, Enemy).?.wait,
    );
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

    if (dialogUi.update(world)) |event| {
        TalkState.handle(event);
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
            zhu.mouse.released(.RIGHT))
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
    state.draw(world);
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
            if (!warn) return changeMapIfNeed(world, object);
        } else warn = false;

        if (world.getIdentity(Enemy)) |target| {
            world.removeIdentity(Enemy);
            const targetActor = world.get(target, Actor).?;
            const actor = factory.get(targetActor.key);
            // 是否需要对话
            if (actor.dialogues.len != 0) {
                world.add(world.entity, Dialog{
                    .lines = factory.dialogues[actor.dialogues[0]].lines,
                });
                world.add(world.getIdentity(Player).?, Interact.Disabled{});
                state = .talk;
            } else {
                context.battle = .{
                    .actor = targetActor.key,
                    .mapIndex = map.linkIndex,
                };
                back = .battle;
                scene.changeScene(.battle);
            }
            return;
        }

        system.dialog.update(world);
        if (world.has(world.entity, Dialog)) {
            state = .talk;
            return;
        }

        // 交互检测
        if (!input.released(.confirm)) return;
        // 开启宝箱
        const talkObject = map.talk(area.min, facing);
        if (talkObject) |pickupIndex| openChest(world, pickupIndex);
    }

    fn changeMapIfNeed(world: *ecs.World, object: u8) void {
        const link = map.links[object];
        if (player.progress > link.progress) {
            std.log.info("change map link index: {d}", .{object});
            map.linkIndex = object;
            scene.changeMap();
            return;
        }

        if (player.progress == 1) {
            warn = true;
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[5].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        }

        if (player.progress == 4) {
            player.progress += 1;
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[32].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        }

        if (player.progress == 10) {
            warn = true;
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[37].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        }
    }

    fn openChest(world: *ecs.World, pickIndex: u16) void {
        const object = item.pickupZon[pickIndex];

        if (object.itemIndex == 0 and object.count == 0) {
            const gold = zhu.random.int(u8, 10, 100);
            player.money += gold;
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[0].lines,
                .value = .{ .number = gold },
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        } else {
            const added = player.addItem(object.itemIndex);
            if (!added) {
                tip = "你已经带满了！";
                return;
            }
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[1].lines,
                .value = .{
                    .text = item.zon[object.itemIndex].name,
                },
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
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
            zhu.mouse.released(.RIGHT))
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
            zhu.mouse.released(.RIGHT))
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
            zhu.mouse.released(.RIGHT))
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
    fn handle(event: dialog.Event) void {
        switch (event) {
            .finish => state = .map,
            .openWeaponShop => {
                state = .shop;
                shop = &weaponShop;
            },
            .openPotionShop => {
                state = .shop;
                shop = &potionShop;
            },
            .openSale => state = .sale,
            .battle => |actorKey| {
                context.battle = .{
                    .actor = actorKey,
                    .mapIndex = map.linkIndex,
                };
                back = .battle;
                scene.changeScene(.battle);
            },
            .showSwordTip => {
                // 打败了巫批，对话完成
                header = "　　太好了！终于找到了失落已久的“圣剑”，就用它的威力把大魔王彻底杀死吧！　";
                headerColor = .white;
                headerTimer.restart();
            },
            .showEnding => {
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
        }
    }
};

const AboutState = struct {
    fn update(delta: f32) void {
        if (about.roll) about.update(delta) //
        else if (zhu.mouse.released(.LEFT) or
            input.released(.confirm))
        {
            about.roll = true;
        }
    }
};

const SaleState = struct {
    var sell: bool = false;

    fn update(world: *ecs.World, _: f32) void {
        const playerSell = player.sellItem();
        if (!sell) sell = playerSell;

        if (input.released(.menu) or input.released(.cancel) or
            zhu.mouse.released(.RIGHT))
        {
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[
                    if (sell) 27 else 26
                ].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
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

    pub fn update(self: *Shop, world: *ecs.World) void {
        self.current = item.update(self.items.len, self.current);

        if (input.released(.buyItem)) {
            const itemIndex = self.items[self.current];
            if (itemIndex != 0) {
                const playerBuy = buy(itemIndex);
                if (!bought) bought = playerBuy;
            }
        }

        if (input.released(.menu) or input.released(.cancel)) {
            const dialogId = if (bought)
                self.boughtDialogue
            else
                self.notBoughtDialogue;
            world.add(world.entity, Dialog{
                .lines = factory.dialogues[dialogId].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
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
