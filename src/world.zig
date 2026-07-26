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
const factory = @import("factory.zig");
const zon = @import("zon.zig");
const system = @import("system/system.zig");
const context = @import("context.zig");
const dialogUi = @import("ui/dialog.zig");
const storage = @import("storage.zig");

const actorComponent = component.actor;
const dialog = component.dialog;
const Actor = actorComponent.Actor;
const Dialog = dialog.Dialog;
const Enemy = actorComponent.Enemy;
const Facing = actorComponent.Facing;
const Interact = component.Interact;
const Player = actorComponent.Player;
const Portal = component.Portal;
const Talk = dialog.Talk;
const Tip = component.event.Tip;

const PlayerLocation = struct {
    position: math.Vector2,
    facing: Facing,
};

const PlayerSpawn = union(enum) {
    location: PlayerLocation,
    portal: zon.Portal.Key,
};

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
            .load => LoadState.update(world, delta),
            .save => SaveState.update(world, delta),
            .talk => {},
            .status => {},
            .item => {
                const stats = world.getGlobal(storage.Stats);
                const inventory = world.getGlobal(storage.Inventory);
                _ = player.openItem(stats, inventory);
            },
            .shop => shop.update(world),
            .sale => SaleState.update(world, delta),
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    pub fn draw(self: State, world: *ecs.World) void {
        switch (self) {
            .map => {},
            .status => player.drawStatus(
                world.getGlobal(storage.Stats),
                world.getGlobal(storage.Inventory),
            ),
            .item => player.drawOpenItem(
                world.getGlobal(storage.Stats),
                world.getGlobal(storage.Inventory),
            ),
            .about => about.draw(),
            .talk => dialogUi.draw(world),
            .sale => player.drawSellItem(
                world.getGlobal(storage.Inventory),
            ),
            .shop => shop.draw(
                world.getGlobal(storage.Inventory),
            ),
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
    map.enter();
    switch (back) {
        .none => {
            world.addAll(world.entity, .{
                storage.DeadActors.empty,
                storage.OpenedChests.initEmpty(),
                storage.Progress{},
                storage.Stats{},
                storage.Inventory{},
            });
            rebuildMap(world, .{
                .location = .{
                    .position = .xy(180, 164),
                    .facing = .down,
                },
            });
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[2].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        },
        .battle => {
            system.story.update(world);
            finishBattle(world);
        },
        .load => {
            rebuildMap(world, .{ .location = loadPlayerLocation.? });
            state = .map;
        },
        .menu => {
            if (loadPlayerLocation) |location| {
                rebuildMap(world, .{ .location = location });
            }
            state = .menu;
        },
    }
    loadPlayerLocation = null;
    player.cameraLookAt(world);
    menu.active = 6;
    zhu.audio.playMusic("voc/back.ogg");
}

pub fn changeMap(world: *ecs.World) void {
    map.enter();
    rebuildMap(world, .{ .portal = map.portalKey });
}

// 清空旧地图并创建新地图的实体。
fn rebuildMap(world: *ecs.World, spawn: PlayerSpawn) void {
    world.resetKeep(storage.keep);
    world.entity = world.createEntity();
    map.spawnPortals(world);
    factory.spawnChests(world, map.current);
    switch (spawn) {
        .location => |location| factory.spawnPlayer(
            world,
            location.position,
            location.facing,
        ),
        .portal => |key| spawnPlayerAtPortal(world, key),
    }

    const deadActors = world.getGlobal(storage.DeadActors);
    const progress = world.getGlobal(storage.Progress).value;
    for (map.current.actors) |key| {
        if (deadActors.contains(key)) continue;
        if (zon.Actor.get(key).progress < progress) continue;
        factory.spawnActor(world, key, progress);
    }
    player.cameraLookAt(world);
}

// 在目标传送区域外创建玩家。
fn spawnPlayerAtPortal(world: *ecs.World, key: zon.Portal.Key) void {
    const config = zon.Portal.get(key);
    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
        if (portal.key != key) continue;

        const center = portal.area.center();
        const max = portal.area.max();
        const position = switch (config.facing) {
            .down => math.Vector2.xy(center.x - 8, max.y + 8),
            .left => math.Vector2.xy(
                portal.area.min.x - 16 - 8,
                center.y - 8,
            ),
            .up => math.Vector2.xy(
                center.x - 8,
                portal.area.min.y - 16 - 8,
            ),
            .right => math.Vector2.xy(max.x + 8, center.y - 8),
        };
        factory.spawnPlayer(world, position, config.facing);
        return;
    }
    unreachable;
}

// 处理战斗结果并继续使用进入战斗前的地图实体。
fn finishBattle(world: *ecs.World) void {
    const actorEntity = findBattleActor(world);

    switch (context.battle.result) {
        .fighting => unreachable,
        .win => {
            const dead = world.getGlobal(storage.DeadActors);
            dead.insert(context.battle.actor);
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
    world.add(world.entity, storage.DeadActors.empty);
    const playerEntity = world.createIdentity(Player);
    world.add(world.entity, Dialog{
        .lines = zon.dialogues[36].lines,
    });
    world.add(playerEntity, Interact.Disabled{});
    const actorEntity = world.createEntity();
    world.add(actorEntity, Actor{ .key = .wuPi });

    context.battle = .{
        .actor = .wuPi,
        .portalKey = .start,
        .result = .win,
    };

    finishBattle(&world);

    try std.testing.expect(state == .talk);
    try std.testing.expect(world.has(world.entity, Dialog));
    try std.testing.expect(world.has(playerEntity, Interact.Disabled));
    try std.testing.expect(!world.has(actorEntity, Actor));
    const deadActors = world.getGlobal(storage.DeadActors);
    try std.testing.expect(deadActors.contains(.wuPi));
}

test "战斗胜利后没有对话则返回地图" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, storage.DeadActors.empty);
    const actorEntity = world.createEntity();
    world.add(actorEntity, Actor{ .key = .senLin_feiJiangJun1 });

    context.battle = .{
        .actor = .senLin_feiJiangJun1,
        .portalKey = .start,
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
        .lines = zon.dialogues[36].lines,
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
        .portalKey = .start,
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
    const progress = world.getGlobal(storage.Progress).value;
    if (tip.len != 0) {
        if (zon.input.released(.confirm) or zon.input.released(.cancel)) {
            tip = &.{};
        } else return;
    }

    if (header.len != 0) {
        if (header.len == headerIndex) {
            // 已经显示结束了，等待按键
            if (zon.input.released(.confirm)) {
                if (progress > 20)
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
        if (zon.input.released(.menu) or zon.input.released(.cancel) or
            zhu.mouse.released(.RIGHT))
        {
            state = .menu;
            return;
        }
    }

    state.update(world, delta);
    for (world.getEvent(Tip)) |event| tip = event.text;
    world.clearEvent(Tip);
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
        if (world.getIdentity(Portal)) |portalEntity| {
            const portal = world.get(portalEntity, Portal).?;
            if (!warn) return changeMapIfNeed(world, portal.key);
        } else warn = false;

        if (world.getIdentity(Enemy)) |target| {
            world.removeIdentity(Enemy);
            const targetActor = world.get(target, Actor).?;
            // 是否需要对话
            if (world.get(target, Talk)) |lines| {
                world.add(world.entity, Dialog{
                    .lines = lines,
                });
                world.add(world.getIdentity(Player).?, Interact.Disabled{});
                state = .talk;
            } else {
                context.battle = .{
                    .actor = targetActor.key,
                    .portalKey = map.portalKey,
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
    }

    fn changeMapIfNeed(world: *ecs.World, key: zon.Portal.Key) void {
        const portal = zon.Portal.get(key);
        const progress = world.getGlobal(storage.Progress).value;
        if (progress > portal.progress) {
            std.log.info("change map portal: {s}", .{@tagName(key)});
            map.portalKey = portal.target;
            scene.changeMap();
            return;
        }

        if (progress == 1) {
            warn = true;
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[5].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        }

        if (progress == 4) {
            world.addEvent(component.event.Story{
                .progress = progress,
            });
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[32].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        }

        if (progress == 10) {
            warn = true;
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[37].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
        }
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

        if (zon.input.released(.menu) or zon.input.released(.cancel) or
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

var loadPlayerLocation: ?PlayerLocation = null;
const LoadState = struct {
    pub fn update(world: *ecs.World, _: f32) void {
        const loadEvent = menu.update();
        if (loadEvent) |event| switch (event) {
            3...7 => |index| {
                back = .menu;
                scene.changeScene(.world);
                load(world, index) catch {
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

        if (zon.input.released(.menu) or zon.input.released(.cancel) or
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

pub fn load(world: *ecs.World, index: u8) !void {
    var loaded = try storage.read(index);
    defer loaded.deinit();

    const record = loaded.value;
    map.portalKey = record.portal;
    world.addAll(world.entity, .{
        record.progress,
        record.stats,
        record.inventory,
    });
    loadPlayerLocation = .{
        .position = record.position,
        .facing = record.facing,
    };

    const opened = world.getGlobal(storage.OpenedChests);
    opened.* = .initEmpty();
    for (record.openedChests) |chestId| {
        opened.set(chestId);
    }

    const deadActors = world.getGlobal(storage.DeadActors);
    deadActors.* = .empty;
    for (record.deadActors) |key| {
        deadActors.insert(key);
    }
}

const SaveState = struct {
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

        if (zon.input.released(.menu) or zon.input.released(.cancel) or
            zhu.mouse.released(.RIGHT))
        {
            menu.active = 6;
            state = .menu;
        }
    }

    fn save(world: *ecs.World, index: u8) !void {
        var openedChestBuffer: [zon.Chest.list.len]u16 = undefined;
        var openedChestCount: usize = 0;
        const opened = world.getGlobal(storage.OpenedChests);
        var chestIterator = opened.iterator(.{});
        while (chestIterator.next()) |chestId| {
            openedChestBuffer[openedChestCount] = @intCast(chestId);
            openedChestCount += 1;
        }

        var deadKeys: [storage.DeadActors.len]zon.Actor.Key = undefined;
        var deadActorCount: usize = 0;
        const deadActors = world.getGlobal(storage.DeadActors);
        var actorIterator = deadActors.iterator();
        while (actorIterator.next()) |key| {
            deadKeys[deadActorCount] = key;
            deadActorCount += 1;
        }

        try storage.write(index, .{
            .portal = map.portalKey,
            .position = player.collider(world).min,
            .facing = world.get(world.getIdentity(Player).?, Facing).?,
            .progress = world.getGlobal(storage.Progress).*,
            .stats = world.getGlobal(storage.Stats).*,
            .inventory = world.getGlobal(storage.Inventory).*,
            .openedChests = openedChestBuffer[0..openedChestCount],
            .deadActors = deadKeys[0..deadActorCount],
        });
    }

    pub fn draw() void {
        zhu.batch.drawImage(texture, .xy(0, 280), .{});
        menu.draw();
    }
};

const TalkState = struct {
    fn handle(event: zon.dialog.Event) void {
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
                    .portalKey = map.portalKey,
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
            zon.input.released(.confirm))
        {
            about.roll = true;
        }
    }
};

const SaleState = struct {
    var sell: bool = false;

    fn update(world: *ecs.World, _: f32) void {
        const inventory = world.getGlobal(storage.Inventory);
        const playerSell = player.sellItem(inventory);
        if (!sell) sell = playerSell;

        if (zon.input.released(.menu) or zon.input.released(.cancel) or
            zhu.mouse.released(.RIGHT))
        {
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[
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
    items: [16]?zon.Item.Key,
    current: u8 = 0,
    notBoughtDialogue: u16,
    boughtDialogue: u16,

    pub fn update(self: *Shop, world: *ecs.World) void {
        const inventory = world.getGlobal(storage.Inventory);
        self.current = item.update(self.items.len, self.current);

        if (zon.input.released(.buyItem)) {
            if (self.items[self.current]) |key| {
                const playerBuy = buy(inventory, key);
                if (!bought) bought = playerBuy;
            }
        }

        if (zon.input.released(.menu) or zon.input.released(.cancel)) {
            const dialogId = if (bought)
                self.boughtDialogue
            else
                self.notBoughtDialogue;
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[dialogId].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
            state = .talk;
            bought = false;
        }
    }

    fn buy(inventory: *storage.Inventory, key: zon.Item.Key) bool {
        const buyItem = zon.Item.get(key);

        if (buyItem.money > inventory.money) {
            tip = "兄弟，你的钱不够！";
            return false;
        }

        const bagEnough = inventory.add(key);
        if (!bagEnough) {
            tip = "你已经带满了！";
            return false;
        }
        inventory.money -= buyItem.money;
        return true;
    }

    pub fn draw(
        self: *const Shop,
        inventory: *const storage.Inventory,
    ) void {
        item.draw(&self.items, self.current);
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        var buffer: [20]u8 = undefined;
        // 金币，操作说明
        zhu.text.draw("（金=", item.position.addXY(10, 270), .{});
        const moneyStr = zhu.format(&buffer, "{d}）", .{inventory.money});
        zhu.text.draw(moneyStr, item.position.addXY(60, 270), .{});
        const text = "CTRL=购买　　ESC=退出";
        zhu.text.draw(text, item.position.addXY(118, 270), .{});
    }
};
var weaponShop: Shop = .{
    .items = .{
        .biShou,          .biShou,
        .ningShuangJian,  .ningShuangJian,
        .guWenMingKuiJia, .guWenMingKuiJia,
        .changQuanQuanPu, .changQuanQuanPu,
        .zhongJian,       .zhongJian,
        .fenKuLou,        .fenKuLou,
        .piJia,           .piJia,
        null,             null,
    },
    .notBoughtDialogue = 18,
    .boughtDialogue = 19,
};
var potionShop: Shop = .{
    .items = .{
        .huaMoGu,       .huaMoGu,
        .zhiXueCao,     .zhiXueCao,
        .huanHunCao,    .huanHunCao,
        .hongMeiGui,    .hongMeiGui,
        .hongSeYaoPing, .hongSeYaoPing,
        .yaoPing,       .yaoPing,
        null,           null,
        null,           null,
    },
    .notBoughtDialogue = 22,
    .boughtDialogue = 23,
};
var shop: *Shop = undefined;
