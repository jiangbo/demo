const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const player = @import("player.zig");
const enemy = @import("enemy.zig");
const shared = @import("shared.zig");

const Dialog = component.dialog.Dialog;
const Enemy = component.actor.Enemy;
const Interact = component.Interact;
const Key = component.actor.Key;
const Player = component.actor.Player;

pub const Request = enum { world, title };

// 当前阶段同时记录阶段标识和对应类型。
const Phase = union(shared.Phase) {
    menu: shared.Menu,
    playerAttack: player.Attack,
    enemyHurt: enemy.Hurt,
    wait: shared.Wait,
    enemyAttack: enemy.Attack,
    playerHurt: player.Hurt,
    playerDeath: player.Death,
    enemyDeath: enemy.Death,
    status: player.Status,
    item: player.Item,
    win: void,
    escape: void,
    title: void,

    // 只初始化实际需要进入处理的阶段。
    pub fn enter(self: Phase, world: *ecs.World) void {
        switch (self) {
            .win, .escape, .title => unreachable,
            .menu, .status => {},
            inline else => |value| @TypeOf(value).enter(world),
        }
    }

    // 更新当前阶段，并返回下一阶段标识。
    pub fn update(self: Phase, world: *ecs.World, delta: f32) ?shared.Phase {
        switch (self) {
            .win, .escape, .title => unreachable,
            inline else => |value| {
                return @TypeOf(value).update(world, delta);
            },
        }
    }

    // 只绘制实际拥有附加内容的阶段。
    pub fn draw(self: Phase, world: *ecs.World) void {
        switch (self) {
            .win, .escape, .title => unreachable,
            .menu => {},
            inline else => |value| @TypeOf(value).draw(world),
        }
    }
};

var texture: zhu.Image = undefined;
var mapImage: zhu.Image = undefined;
var mapVertexes: []zhu.batch.Vertex = undefined;
var phase: Phase = .menu;

// 初始化战斗场景长期使用的资源。
pub fn init(allocator: zhu.Allocator) void {
    texture = zhu.getImage("fightbar.png").?;
    mapImage = zhu.getImage("maps1-sheet.png").?;
    mapVertexes = factory.mapVertexes(allocator, mapImage, .battle);
    shared.bombAnimation = .initSource(zon.config.bomb);
}

// 释放战斗地图长期持有的顶点。
pub fn deinit(allocator: zhu.Allocator) void {
    allocator.free(mapVertexes);
}

// 读取选定的敌人并进入战斗场景。
pub fn enter(world: *ecs.World) void {
    const enemyEntity = world.getIdentity(Enemy).?;
    const enemyKey = world.get(enemyEntity, Key).?;
    shared.enemyKey = enemyKey;
    shared.enemy = zon.Actor.get(enemyKey).*;
    shared.menu.reset();
    shared.menu.selected = 0;
    changePhase(world, .menu);
    zhu.camera.main.position = .zero;
}

// 切换阶段并初始化新阶段。
fn changePhase(world: *ecs.World, newPhase: shared.Phase) void {
    phase = switch (newPhase) {
        .win, .escape, .title => unreachable,
        inline else => |newTag| @unionInit( //
            Phase, @tagName(newTag), .{}),
    };
    phase.enter(world);
}

// 更新当前战斗阶段并返回场景请求。
pub fn update(world: *ecs.World, delta: f32) ?Request {
    const newPhase = phase.update(world, delta) orelse return null;
    switch (newPhase) {
        .win => return finishWin(world),
        .escape => return finishEscape(world),
        .title => {
            world.removeIdentity(Enemy);
            return .title;
        },
        else => changePhase(world, newPhase),
    }
    return null;
}

// 记录死亡并删除普通地图中的敌人。
fn finishWin(world: *ecs.World) Request {
    const enemyEntity = world.getIdentity(Enemy).?;
    const dead = world.getGlobal(storage.DeadActors).?;
    dead.insert(shared.enemyKey);
    world.removeIdentity(Enemy);
    world.destroyEntity(enemyEntity);
    return .world;
}

// 设置逃跑冷却并结束战斗前未完成的对话。
fn finishEscape(world: *ecs.World) Request {
    const enemyEntity = world.getIdentity(Enemy).?;
    world.getPtr(enemyEntity, Enemy).?.wait = 0.5;
    if (world.has(world.entity, Dialog)) {
        world.remove(world.entity, Dialog);
        world.remove(world.getIdentity(Player).?, Interact.Disabled);
    }
    world.removeIdentity(Enemy);
    return .world;
}

// 绘制战斗场景、双方状态和当前阶段。
pub fn draw(world: *ecs.World) void {
    zhu.batch.drawVertices(mapVertexes, mapImage);

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
            factory.npcBattleImage(shared.enemyKey),
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
        factory.npcPhoto(shared.enemyKey),
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
        shared.enemy.health,
        shared.enemy.attack,
        shared.enemy.defend,
        shared.enemy.level,
    });
    zhu.text.draw(text, position.addXY(305, 5), .{ .color = .black });
    zhu.text.msdf.end();

    shared.menu.drawImage();
    zhu.text.msdf.begin();
    shared.menu.drawText();
    zhu.text.msdf.end();
    phase.draw(world);
}
