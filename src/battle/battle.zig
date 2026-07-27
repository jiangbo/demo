const zhu = @import("zhu");
const ecs = @import("ecs");

const map = @import("../map.zig");
const context = @import("../context.zig");
const factory = @import("../factory.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const ui = @import("../ui/ui.zig");
const player = @import("player.zig");
const enemy = @import("enemy.zig");
const shared = @import("shared.zig");

// 当前阶段同时记录阶段标识和对应类型。
const Phase = union(shared.Phase) {
    menu: player.Menu,
    playerAttack: player.Attack,
    enemyHurt: enemy.Hurt,
    wait: shared.Wait,
    enemyAttack: enemy.Attack,
    playerHurt: player.Hurt,
    playerDeath: player.Death,
    enemyDeath: enemy.Death,
    status: player.Status,
    item: player.Item,

    // 只初始化实际需要进入处理的阶段。
    pub fn enter(self: Phase, world: *ecs.World) void {
        switch (self) {
            .menu, .status, .item => {},
            .playerHurt => player.Hurt.enter(world, &enemy.actor),
            inline else => |value| @TypeOf(value).enter(world),
        }
    }

    // 更新当前阶段，并返回下一阶段标识。
    pub fn update(self: Phase, world: *ecs.World, delta: f32) ?shared.Phase {
        switch (self) {
            .menu => return player.Menu.update(
                world,
                delta,
                &enemy.actor,
            ),
            inline else => |value| {
                return @TypeOf(value).update(world, delta);
            },
        }
    }

    // 只绘制实际拥有附加内容的阶段。
    pub fn draw(self: Phase, world: *ecs.World) void {
        switch (self) {
            .menu => {},
            inline else => |value| @TypeOf(value).draw(world),
        }
    }
};

var texture: zhu.Image = undefined;
var phase: Phase = .menu;

// 初始化战斗场景长期使用的资源。
pub fn init() void {
    texture = zhu.getImage("fightbar.png").?;
    shared.bombAnimation = .initSource(zon.config.bomb);
}

// 根据当前战斗人物进入战斗场景。
pub fn enter(world: *ecs.World) void {
    enemy.reset(context.battle.actor);
    ui.battle.reset();
    changePhase(world, .menu);
    zhu.camera.main.position = .zero;
}

// 切换阶段并初始化新阶段。
fn changePhase(world: *ecs.World, newPhase: shared.Phase) void {
    phase = switch (newPhase) {
        inline else => |newTag| @unionInit( //
            Phase, @tagName(newTag), .{}),
    };
    phase.enter(world);
}

// 更新当前战斗阶段。
pub fn update(world: *ecs.World, delta: f32) void {
    if (phase.update(world, delta)) |newPhase| {
        changePhase(world, newPhase);
    }
}

// 绘制战斗场景、双方状态和当前阶段。
pub fn draw(world: *ecs.World) void {
    map.drawBattle();

    zhu.camera.push(.window);
    defer zhu.camera.pop();
    var buffer: [100]u8 = undefined;

    if (phase != .playerHurt and phase != .playerDeath) {
        zhu.batch.drawImage(
            factory.playerBattleImage(),
            .xy(130, 220),
            .{},
        );
    }

    if (phase != .enemyHurt and phase != .enemyDeath) {
        zhu.batch.drawImage(
            factory.npcBattleImage(enemy.key),
            .xy(465, 237),
            .{},
        );
    }

    const position = zhu.Vector2.xy(96, 304);
    zhu.batch.drawImage(texture, position, .{});
    zhu.batch.drawImage(
        factory.playerPhoto(),
        position.addXY(10, 10),
        .{},
    );
    zhu.batch.drawImage(
        factory.npcPhoto(enemy.key),
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
        enemy.actor.health,
        enemy.actor.attack,
        enemy.actor.defend,
        enemy.actor.level,
    });
    zhu.text.draw(text, position.addXY(305, 5), .{ .color = .black });
    zhu.text.msdf.end();

    ui.battle.draw();
    phase.draw(world);
}
