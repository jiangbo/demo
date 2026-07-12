const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;
const audio = zhu.audio;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const npc = @import("npc.zig");
const player = @import("player.zig");
const menu = @import("menu.zig");
const item = @import("item.zig");
const input = @import("input.zig");

var enemyIndex: u16 = 0;
var enemy: npc.Character = undefined;

var texture: zhu.Image = undefined;

const bombArray: [10]zhu.graphics.Frame = blk: {
    var array: [10]zhu.graphics.Frame = undefined;
    for (&array, 0..) |*value, i| {
        value.* = .{
            .offset = .xy(@floatFromInt(54 * i), 0),
            .duration = 0.06,
        };
    }
    break :blk array;
};
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

    fn enter(self: Phase) void {
        switch (self) {
            .menu, .status, .item => {},
            inline else => |case| @TypeOf(case).enter(),
        }
    }

    fn update(self: Phase, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    fn draw(self: Phase) void {
        switch (self) {
            .menu => {},
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};
var phase: Phase = .menu;

pub fn init() void {
    texture = zhu.getImage("fightbar.png").?;
    const bombTexture = zhu.getImage("bomb.png").?;
    bombAnimation = .init(bombTexture, .xy(54, 50), &bombArray);
    bombAnimation.loop = false;
}

pub fn enter() void {
    enemyIndex = context.battleNpcIndex;
    enemy = npc.zon[enemyIndex];
    map.linkIndex = 15;
    _ = map.enter();
    menu.active = 7;
    changePhase(.menu);
    camera.main.position = .zero;
}

pub fn exit() void {
    map.linkIndex = context.oldMapIndex;
}

fn changePhase(newPhase: Phase) void {
    phase = newPhase;
    phase.enter();
}

pub fn update(delta: f32) void {
    phase.update(delta);
}

pub fn draw() void {
    map.draw();

    camera.push(.window);
    defer camera.pop();
    var buffer: [100]u8 = undefined;

    if (phase != .playerHurt and phase != .playerDeath) {
        // 战斗人物
        zhu.batch.drawImage(player.battleTexture(), .xy(130, 220), .{});
    }

    if (phase != .enemyHurt and phase != .enemyDeath) {
        // 战斗 NPC
        zhu.batch.drawImage(npc.battleTexture(enemyIndex), .xy(465, 237), .{});
    }

    const position = zhu.Vector2.xy(96, 304);

    // 状态栏背景
    zhu.batch.drawImage(texture, position, .{});
    // 角色的头像
    zhu.batch.drawImage(player.photo(), position.addXY(10, 10), .{});
    // 敌人的头像
    const npcTexture = npc.photo(context.battleNpcIndex);
    zhu.batch.drawImage(npcTexture, position.addXY(265, 26), .{});

    zhu.text.msdf.begin();

    const format = "生命：{:8}\n攻击：{:8}\n防御：{:8}\n等级：{:8}";
    var text = zhu.format(&buffer, format, .{
        player.health,
        player.attack,
        player.defend,
        player.level,
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
    phase.draw();
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
    fn update(_: f32) void {
        const optionalEvent = menu.update();
        if (optionalEvent) |event| switch (event) {
            0 => changePhase(.playerAttack),
            1 => changePhase(.status),
            2 => changePhase(.item),
            3 => {
                if (enemy.escape > zhu.random.int(u8, 0, 100)) {
                    scene.changeScene(.world);
                } else {
                    WaitPhase.tip = "逃跑失败！";
                    WaitPhase.next = .enemyAttack;
                    changePhase(.wait);
                }
            },
            else => unreachable,
        };
    }
};

const PlayerAttackPhase = struct {
    fn enter() void {
        audio.playSound(attackSounds[0]);
        bombAnimation.reset();
    }

    fn update(delta: f32) void {
        if (bombAnimation.update(delta) == .end)
            changePhase(.enemyHurt);
    }

    fn draw() void {
        zhu.batch.drawImage(bombAnimation.subImage(), .xy(452, 230), .{});
    }
};

const EnemyHurtPhase = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    fn enter() void {
        audio.playSound(hurtSounds[enemySounds[enemy.picture]]);

        damage = computeDamage(player.attack, enemy.defend);
        enemy.health -|= damage;

        timer.restart();
    }

    fn update(delta: f32) void {
        if (timer.updateFinished(delta)) {
            if (enemy.health == 0) return changePhase(.enemyDeath);
            WaitPhase.next = .enemyAttack;
            return changePhase(.wait);
        }

        const period: u8 = @intFromFloat(@trunc(timer.elapsed / 0.08));
        offset = if (period % 2 == 0) -5 else 5;
    }

    fn draw() void {
        const pos = math.Vector2.xy(465, 237).addX(offset);
        zhu.batch.drawImage(npc.battleTexture(enemyIndex), pos, .{});

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

    fn enter() void {
        timer.restart();
    }

    fn update(delta: f32) void {
        if (timer.updateFinished(delta)) {
            tip = &.{};
            changePhase(next);
        }
    }

    fn draw() void {
        if (tip.len == 0) return;
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(tip, .xy(290, 210), .{});
    }
};

const EnemyAttackPhase = struct {
    fn enter() void {
        audio.playSound(attackSounds[enemySounds[enemy.picture]]);
        bombAnimation.reset();
    }

    fn update(delta: f32) void {
        if (bombAnimation.update(delta) == .end) changePhase(.playerHurt);
    }

    fn draw() void {
        zhu.batch.drawImage(bombAnimation.subImage(), .xy(120, 220), .{});
    }
};

const PlayerHurtPhase = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    fn enter() void {
        audio.playSound(hurtSounds[0]);

        damage = computeDamage(enemy.attack, player.defend);
        player.health -|= damage;

        timer.restart();
    }

    fn update(delta: f32) void {
        if (timer.updateFinished(delta)) {
            changePhase(if (player.health == 0) .playerDeath else .menu);
        }

        const period: u8 = @intFromFloat(@trunc(timer.elapsed / 0.08));
        offset = if (period % 2 == 0) -5 else 5;
    }

    fn draw() void {
        const pos = math.Vector2.xy(130, 220).addX(offset);
        zhu.batch.drawImage(player.battleTexture(), pos, .{});

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(text, .xy(130, y), .{});
    }
};

const PlayerDeathPhase = struct {
    fn enter() void {
        audio.playSound(deadSounds[0]);
    }

    fn update(_: f32) void {
        if (input.released(.confirm)) scene.changeScene(.title);
    }

    fn draw() void {
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw("你死了！", .xy(285, 200), .{});
    }
};

const EnemyDeathPhase = struct {
    var step: u8 = 0;

    fn enter() void {
        audio.playSound(deadSounds[enemySounds[enemy.picture]]);
        step = 0;
        npc.death(enemyIndex);
        if (enemy.progress != 0xFF) player.progress = enemy.progress + 1;
    }

    fn update(_: f32) void {
        if (step == 0 and input.released(.confirm)) {
            step += 1;
            player.exp += enemy.level * 20;
            player.money += enemy.money;
            for (enemy.goods) |index| _ = player.addItem(index);
            return;
        }

        if (step == 1 and input.released(.confirm)) {
            if (player.isLevelUp()) {
                step += 1;
                return player.levelUp();
            }
        }

        if (input.released(.confirm)) scene.changeScene(.world);
    }

    fn draw() void {
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

            for (enemy.goods) |index| {
                const name = item.zon[index].name;
                zhu.text.draw(name, .xy(310, 240), .{ .color = .yellow });
            }

            std.debug.assert(enemy.goods.len == 1);
        }
        if (step == 2) {
            text = zhu.format(&buffer, "等级升为({})^_^", .{player.level});
            zhu.text.draw(text, .xy(260, 270), .{ .color = .yellow });
        }
    }
};

const StatusPhase = struct {
    fn update(_: f32) void {
        if (input.released(.confirm) or input.released(.cancel)) {
            changePhase(.menu);
        }
    }

    fn draw() void {
        player.drawStatus();
    }
};

const ItemPhase = struct {
    fn update(_: f32) void {
        const used = player.openItem();
        if (used) changePhase(.enemyAttack);

        if (input.released(.cancel)) changePhase(.menu);
    }

    fn draw() void {
        player.drawOpenItem();
    }
};
