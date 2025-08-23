const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;
const audio = zhu.audio;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const npc = @import("npc.zig");
const player = @import("player.zig");
const menu = @import("menu.zig");

var enemyIndex: u16 = 0;
var enemy: npc.Character = undefined;

var texture: gfx.Texture = undefined;

const bombArray: [10]gfx.Frame = blk: {
    var array: [10]gfx.Frame = undefined;
    const size = math.Vector2.init(54, 50);
    for (&array, 0..) |*value, i| {
        value.* = .{
            .area = .init(.init(@floatFromInt(54 * i), 0), size),
            .interval = 0.06,
        };
    }
    break :blk array;
};
var bombAnimation: gfx.FrameAnimation = undefined;

const attackSoundNames: [3][:0]const u8 = .{
    "assets/voc/ack_00.ogg",
    "assets/voc/ack_01.ogg",
    "assets/voc/ack_02.ogg",
};

const hurtSoundNames: [3][:0]const u8 = .{
    "assets/voc/ao_00.ogg",
    "assets/voc/ao_01.ogg",
    "assets/voc/ao_02.ogg",
};

const deadSoundNames: [3][:0]const u8 = .{
    "assets/voc/dead_00.ogg",
    "assets/voc/dead_01.ogg",
    "assets/voc/dead_02.ogg",
};

const hurtSounds: [15]u8 = .{ 2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 2 };

const Phase = union(enum) {
    menu: MenuPhase,
    playerAttack: PlayerAttackPhase,
    enemyHurt: EnemyHurtPhase,
    // PlayerAttackStart,
    // PlayerAttackEnd,
    // EnemyHurt,
    // EnemyTurnStart,
    // EnemyAttackStart,
    // EnemyAttackEnd,
    // PlayerHurt,
    // Finished,

    fn enter(self: Phase) void {
        switch (self) {
            .menu => {},
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
    texture = gfx.loadTexture("assets/pic/fightbar.png", .init(448, 112));
    const bombTexture = gfx.loadTexture("assets/pic/bomb.png", .init(540, 50));
    bombAnimation = .init(bombTexture, &bombArray);
    bombAnimation.loop = false;
}

pub fn deinit() void {
    npc.deinit();
}

pub fn enter() void {
    enemyIndex = context.battleNpcIndex;
    enemy = npc.zon[enemyIndex];
    map.linkIndex = 13;
    _ = map.enter();
    menu.active = 7;
}

fn changePhase(newPhase: Phase) void {
    phase = newPhase;
    phase.enter();
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.ESCAPE)) scene.changeScene(.world);

    phase.update(delta);
}

fn randomU16(min: u16, max: u16) u16 {
    return math.random().intRangeLessThanBiased(u16, min, max);
}

pub fn draw() void {
    map.draw();

    camera.mode = .local;
    defer camera.mode = .world;
    var buffer: [100]u8 = undefined;

    // 战斗人物
    camera.draw(player.battleTexture(), .init(130, 220));

    // 战斗 NPC
    camera.draw(npc.battleTexture(enemyIndex), .init(465, 237));

    const position = gfx.Vector.init(96, 304);

    // 状态栏背景
    camera.draw(texture, position);
    // 角色的头像
    camera.draw(player.photo(), position.addXY(10, 10));

    const format = "生命：{:8}\n攻击：{:8}\n防御：{:8}\n等级：{:8}";
    var text = zhu.format(&buffer, format, .{
        player.health,
        player.attack,
        player.defend,
        player.level,
    });
    camera.drawColorText(text, position.addXY(50, 5), .black);

    // 敌人的头像
    const npcTexture = npc.photo(context.battleNpcIndex);
    camera.draw(npcTexture, position.addXY(265, 26));

    text = zhu.format(&buffer, format, .{
        enemy.health,
        enemy.attack,
        enemy.defend,
        enemy.level,
    });
    camera.drawColorText(text, position.addXY(305, 5), .black);

    menu.draw();
    phase.draw();
}

const MenuPhase = struct {
    fn update(delta: f32) void {
        _ = delta;

        const optionalEvent = menu.update();
        if (optionalEvent) |event| switch (event) {
            0 => changePhase(.playerAttack),
            1 => {
                // 状态
            },
            2 => {
                // 物品
            },
            3 => {
                // 逃走
                scene.changeScene(.world);
            },
            else => unreachable,
        };
    }
};

const PlayerAttackPhase = struct {
    const sound: [:0]const u8 = attackSoundNames[0];

    fn enter() void {
        audio.playSound(sound);
        bombAnimation.reset();
    }

    fn update(delta: f32) void {
        if (bombAnimation.isFinishedAfterUpdate(delta)) {
            std.log.info("change phase enemy hurt", .{});
            changePhase(.enemyHurt);
        }
    }

    fn draw() void {
        camera.draw(bombAnimation.currentTexture(), .init(452, 230));
    }
};

const EnemyHurtPhase = struct {
    var damage: u16 = 0;
    var timer: window.Timer = .init(0.5);

    fn enter() void {
        audio.playSound(hurtSoundNames[hurtSounds[enemy.picture]]);

        damage = player.attack * 2 - enemy.defend;
        if (damage <= 10) damage = randomU16(0, 10) else {
            damage += randomU16(0, damage);
        }
        enemy.health -|= damage;

        timer.reset();
    }

    fn update(delta: f32) void {
        if (timer.isFinishedAfterUpdate(delta)) {
            changePhase(.menu);
        }
    }

    fn draw() void {
        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        camera.drawText(text, .init(465, y));
    }
};
