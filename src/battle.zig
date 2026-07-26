const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;
const audio = zhu.audio;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const player = @import("player.zig");
const menu = @import("menu.zig");
const factory = @import("factory.zig");
const component = @import("component.zig");
const storage = @import("storage.zig");
const zon = @import("zon.zig");

const Story = component.event.Story;

var enemyKey: zon.Actor.Key = undefined;
var enemy: zon.Actor = undefined;

var texture: zhu.Image = undefined;
var bombAnimation: zhu.Animation = undefined;

const attackSounds: [3][:0]const u8 = .{
    "voc/ack_00.ogg",
    "voc/ack_01.ogg",
    "voc/ack_02.ogg",
};

const hurtSounds: [3][:0]const u8 = .{
    "voc/ao_00.ogg",
    "voc/ao_01.ogg",
    "voc/ao_02.ogg",
};

const deadSounds: [3][:0]const u8 = .{
    "voc/dead_00.ogg",
    "voc/dead_01.ogg",
    "voc/dead_02.ogg",
};

const enemySounds: [15]u8 = .{ 2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 2 };

const Phase = union(enum) {
    menu: MenuPhase,
    playerAttack: PlayerAttackPhase,
    enemyHurt: EnemyHurtPhase,
    wait: WaitPhase,
    enemyAttack: EnemyAttackPhase,
    playerHurt: PlayerHurtPhase,
    playerDeath: PlayerDeathPhase,
    enemyDeath: EnemyDeathPhase,
    status: StatusPhase,
    item: ItemPhase,

    fn enter(self: Phase, world: *ecs.World) void {
        switch (self) {
            .menu, .status, .item => {},
            inline else => |case| @TypeOf(case).enter(world),
        }
    }

    fn update(self: Phase, world: *ecs.World, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(world, delta),
        }
    }

    fn draw(self: Phase, world: *ecs.World) void {
        switch (self) {
            .menu => {},
            inline else => |case| @TypeOf(case).draw(world),
        }
    }
};
var phase: Phase = .menu;

pub fn init() void {
    texture = zhu.getImage("fightbar.png").?;
    bombAnimation = factory.bombAnimation();
}

pub fn enter(world: *ecs.World) void {
    enemyKey = context.battle.actor;
    enemy = zon.Actor.get(enemyKey).*;
    map.portalKey = .battle;
    map.enter();
    menu.active = 7;
    changePhase(world, .menu);
    camera.main.position = .zero;
}

pub fn exit() void {
    map.portalKey = context.battle.portalKey;
}

fn changePhase(world: *ecs.World, newPhase: Phase) void {
    phase = newPhase;
    phase.enter(world);
}

pub fn update(world: *ecs.World, delta: f32) void {
    phase.update(world, delta);
}

pub fn draw(world: *ecs.World) void {
    map.draw();

    camera.push(.window);
    defer camera.pop();
    var buffer: [100]u8 = undefined;

    if (phase != .playerHurt and phase != .playerDeath) {
        // 战斗人物
        zhu.batch.drawImage(factory.playerBattleImage(), .xy(130, 220), .{});
    }

    if (phase != .enemyHurt and phase != .enemyDeath) {
        // 战斗 NPC
        zhu.batch.drawImage(
            factory.npcBattleImage(enemyKey),
            .xy(465, 237),
            .{},
        );
    }

    const position = zhu.Vector2.xy(96, 304);

    // 状态栏背景
    zhu.batch.drawImage(texture, position, .{});
    // 角色的头像
    zhu.batch.drawImage(factory.playerPhoto(), position.addXY(10, 10), .{});
    // 敌人的头像
    zhu.batch.drawImage(
        factory.npcPhoto(enemyKey),
        position.addXY(265, 26),
        .{},
    );

    zhu.text.msdf.begin();

    const stats = world.getGlobal(storage.Stats).?;
    const format = "生命：{:8}\n攻击：{:8}\n防御：{:8}\n等级：{:8}";
    var text = zhu.format(&buffer, format, .{
        stats.health,
        stats.attack,
        stats.defend,
        stats.level,
    });
    zhu.text.draw(text, position.addXY(50, 5), .{ .color = .black });

    text = zhu.format(&buffer, format, .{
        enemy.health,
        enemy.attack,
        enemy.defend,
        enemy.level,
    });
    zhu.text.draw(text, position.addXY(305, 5), .{ .color = .black });
    zhu.text.msdf.end();

    menu.draw();
    phase.draw(world);
}

fn computeDamage(attack: u16, defend: u16) u16 {
    var damage = attack * 2 -| defend;

    if (damage <= 10)
        damage = zhu.random.intBiased(u16, 0, 10)
    else {
        damage += zhu.random.intBiased(u16, 0, damage);
    }
    return damage;
}

const MenuPhase = struct {
    fn update(world: *ecs.World, _: f32) void {
        const optionalEvent = menu.update();
        if (optionalEvent) |event| switch (event) {
            0 => changePhase(world, .playerAttack),
            1 => changePhase(world, .status),
            2 => changePhase(world, .item),
            3 => {
                if (enemy.escape > zhu.random.int(u8, 0, 100)) {
                    context.battle.result = .escape;
                    scene.changeScene(.world);
                } else {
                    WaitPhase.tip = "逃跑失败！";
                    WaitPhase.next = .enemyAttack;
                    changePhase(world, .wait);
                }
            },
            else => unreachable,
        };
    }
};

const PlayerAttackPhase = struct {
    fn enter(_: *ecs.World) void {
        audio.playSound(attackSounds[0]);
        bombAnimation.reset();
    }

    fn update(world: *ecs.World, delta: f32) void {
        if (bombAnimation.update(delta) == .end)
            changePhase(world, .enemyHurt);
    }

    fn draw(_: *ecs.World) void {
        zhu.batch.drawImage(bombAnimation.subImage(), .xy(452, 230), .{});
    }
};

const EnemyHurtPhase = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    fn enter(world: *ecs.World) void {
        audio.playSound(hurtSounds[enemySounds[enemy.picture]]);

        const stats = world.getGlobal(storage.Stats).?;
        damage = computeDamage(stats.attack, enemy.defend);
        enemy.health -|= damage;

        timer.restart();
    }

    fn update(world: *ecs.World, delta: f32) void {
        if (timer.updateFinished(delta)) {
            if (enemy.health == 0) {
                return changePhase(world, .enemyDeath);
            }
            WaitPhase.next = .enemyAttack;
            return changePhase(world, .wait);
        }

        const period: u8 = @intFromFloat(@trunc(timer.elapsed / 0.08));
        offset = if (period % 2 == 0) -5 else 5;
    }

    fn draw(_: *ecs.World) void {
        const pos = math.Vector2.xy(465, 237).addX(offset);
        zhu.batch.drawImage(factory.npcBattleImage(enemyKey), pos, .{});

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(text, .xy(465, y), .{});
    }
};

const WaitPhase = struct {
    var timer: zhu.Timer = .init(0.5);
    var next: Phase = .menu;
    var tip: []const u8 = &.{};

    fn enter(_: *ecs.World) void {
        timer.restart();
    }

    fn update(world: *ecs.World, delta: f32) void {
        if (timer.updateFinished(delta)) {
            tip = &.{};
            changePhase(world, next);
        }
    }

    fn draw(_: *ecs.World) void {
        if (tip.len == 0) return;
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(tip, .xy(290, 210), .{});
    }
};

const EnemyAttackPhase = struct {
    fn enter(_: *ecs.World) void {
        audio.playSound(attackSounds[enemySounds[enemy.picture]]);
        bombAnimation.reset();
    }

    fn update(world: *ecs.World, delta: f32) void {
        if (bombAnimation.update(delta) == .end) {
            changePhase(world, .playerHurt);
        }
    }

    fn draw(_: *ecs.World) void {
        zhu.batch.drawImage(bombAnimation.subImage(), .xy(120, 220), .{});
    }
};

const PlayerHurtPhase = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    fn enter(world: *ecs.World) void {
        audio.playSound(hurtSounds[0]);

        const stats = world.getGlobal(storage.Stats).?;
        damage = computeDamage(enemy.attack, stats.defend);
        stats.health -|= damage;

        timer.restart();
    }

    fn update(world: *ecs.World, delta: f32) void {
        if (timer.updateFinished(delta)) {
            const stats = world.getGlobal(storage.Stats).?;
            const next: Phase = if (stats.health == 0)
                .playerDeath
            else
                .menu;
            changePhase(world, next);
        }

        const period: u8 = @intFromFloat(@trunc(timer.elapsed / 0.08));
        offset = if (period % 2 == 0) -5 else 5;
    }

    fn draw(_: *ecs.World) void {
        const pos = math.Vector2.xy(130, 220).addX(offset);
        zhu.batch.drawImage(factory.playerBattleImage(), pos, .{});

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(text, .xy(130, y), .{});
    }
};

const PlayerDeathPhase = struct {
    fn enter(_: *ecs.World) void {
        audio.playSound(deadSounds[0]);
    }

    fn update(_: *ecs.World, _: f32) void {
        if (zon.input.released(.confirm)) scene.changeScene(.title);
    }

    fn draw(_: *ecs.World) void {
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw("你死了！", .xy(285, 200), .{});
    }
};

const EnemyDeathPhase = struct {
    var step: u8 = 0;

    fn enter(world: *ecs.World) void {
        audio.playSound(deadSounds[enemySounds[enemy.picture]]);
        step = 0;
        if (enemy.progress != 0xFF) {
            world.addEvent(Story{ .progress = enemy.progress });
        }
    }

    fn update(world: *ecs.World, _: f32) void {
        const stats = world.getGlobal(storage.Stats).?;
        const inventory = world.getGlobal(storage.Inventory).?;
        if (step == 0 and zon.input.released(.confirm)) {
            step += 1;
            stats.exp += enemy.level * 20;
            inventory.money += enemy.money;
            for (enemy.goods) |key| {
                _ = inventory.add(key);
            }
            return;
        }

        if (step == 1 and zon.input.released(.confirm)) {
            if (player.isLevelUp(stats.*)) {
                step += 1;
                return player.levelUp(stats);
            }
        }

        if (zon.input.released(.confirm)) {
            context.battle.result = .win;
            scene.changeScene(.world);
        }
    }

    fn draw(world: *ecs.World) void {
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();

        zhu.text.draw("胜利了！", .xy(285, 175), .{});
        if (step < 1) return;

        var buffer: [100]u8 = undefined;
        var text = zhu.format(&buffer, "获得：经验=[{}] 金钱=[{}]", .{
            enemy.level * 20,
            enemy.money,
        });
        zhu.text.draw(text, .xy(220, 210), .{});

        if (enemy.goods.len != 0) {
            zhu.text.draw("缴获物品：", .xy(220, 240), .{});

            for (enemy.goods) |key| {
                const name = zon.Item.get(key).name;
                zhu.text.draw(name, .xy(310, 240), .{ .color = .yellow });
            }

            std.debug.assert(enemy.goods.len == 1);
        }
        if (step == 2) {
            const level = world.getGlobal(storage.Stats).?.level;
            text = zhu.format(&buffer, "等级升为({})^_^", .{level});
            zhu.text.draw(text, .xy(260, 270), .{ .color = .yellow });
        }
    }
};

const StatusPhase = struct {
    fn update(world: *ecs.World, _: f32) void {
        if (zon.input.released(.confirm) or zon.input.released(.cancel)) {
            changePhase(world, .menu);
        }
    }

    fn draw(world: *ecs.World) void {
        player.drawStatus(
            world.getGlobal(storage.Stats).?,
            world.getGlobal(storage.Inventory).?,
        );
    }
};

const ItemPhase = struct {
    fn update(world: *ecs.World, _: f32) void {
        const stats = world.getGlobal(storage.Stats).?;
        const inventory = world.getGlobal(storage.Inventory).?;
        const used = player.openItem(stats, inventory);
        if (used) changePhase(world, .enemyAttack);

        if (zon.input.released(.cancel)) changePhase(world, .menu);
    }

    fn draw(world: *ecs.World) void {
        player.drawOpenItem(
            world.getGlobal(storage.Stats).?,
            world.getGlobal(storage.Inventory).?,
        );
    }
};
