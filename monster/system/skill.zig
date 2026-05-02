const zhu = @import("zhu");

const com = @import("../component.zig");
const ctx = @import("../context.zig");
const spawn = @import("../spawn.zig");

const displayPositionOffset = zhu.Vector2.xy(0, -96);

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    updateCast(reg);
    updateTimer(reg, delta);
    updateCostRecovery(reg, delta);
    updateDisplay(reg);
}

/// 处理技能施放请求：备份原始属性，应用 buff 倍率，进入激活状态。
fn updateCast(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{ com.skill.Cast, com.skill.Ready });
    while (view.next()) |entity| {
        if (view.has(entity, com.skill.Passive)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);

        // 备份当前属性，buff 结束后恢复
        if (view.tryGetPtr(entity, com.Stats)) |stats| {
            view.add(entity, com.skill.Backup{ .stats = stats.* });
            const buff = skill.buff;
            inline for (@typeInfo(com.Stats).@"struct".fields) |field| {
                @field(stats, field.name) *= @field(buff, field.name);
            }
        }
        view.remove(entity, com.skill.Ready);
        view.add(entity, com.skill.Active{});
        view.add(entity, com.skill.Timer.init(skill.duration));
        // 盾御技能激活时切换防御姿态动画
        if (skill.id == .shield) {
            view.add(entity, com.animation.Play{
                .index = @intFromEnum(com.StateEnum.walk),
                .loop = true,
            });
        }
    }

    reg.clear(com.skill.Cast);
}

/// 迭代有 Timer 的技能实体，计时结束根据 Active 判断：
/// 有 Active → 持续结束，恢复属性，切回冷却；无 Active → 冷却结束，标记 Ready。
fn updateTimer(reg: *zhu.ecs.Registry, delta: f32) void {
    var view = reg.view(.{com.skill.Timer});
    while (view.next()) |entity| {
        const timer = view.getPtr(entity, com.skill.Timer);
        if (!timer.isFinishedOnceUpdate(delta)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);
        if (view.has(entity, com.skill.Active)) {
            // 持续结束：恢复属性，切回冷却计时
            if (view.tryGetPtr(entity, com.skill.Backup)) |backup| {
                const health = view.get(entity, com.Stats).health;
                view.getPtr(entity, com.Stats).* = backup.stats;
                view.getPtr(entity, com.Stats).health = health;
                view.remove(entity, com.skill.Backup);
            }
            if (skill.id == .shield) {
                view.add(entity, com.animation.Play{
                    .index = @intFromEnum(com.StateEnum.idle),
                    .loop = true,
                });
            }
            view.remove(entity, com.skill.Active);
            timer.* = .init(skill.coolDown);
        } else {
            // 冷却结束：标记 Ready，移除 Timer
            view.add(entity, com.skill.Ready{});
            view.remove(entity, com.skill.Timer);
        }
    }
}

fn updateCostRecovery(reg: *zhu.ecs.Registry, delta: f32) void {
    var view = reg.view(.{ com.skill.CostRecovery, com.skill.Active });
    while (view.next()) |entity| {
        const recovery = view.get(entity, com.skill.CostRecovery);
        ctx.cost += recovery.rate * delta;
    }
}

fn updateDisplay(reg: *zhu.ecs.Registry) void {
    updateExistingDisplay(reg);
    createMissingDisplay(reg);
}

fn updateExistingDisplay(reg: *zhu.ecs.Registry) void {
    var view = reg.reverseView(.{ com.skill.Display, com.Position, com.Sprite });
    while (view.next()) |entity| {
        const display = view.getPtr(entity, com.skill.Display);
        const displayEntity = view.toEntity(entity);

        if (!reg.validEntity(display.owner)) {
            reg.destroyEntity(displayEntity);
            continue;
        }

        const skill = reg.tryGetPtr(display.owner, com.skill.Skill) orelse {
            reg.destroyEntity(displayEntity);
            continue;
        };

        const state = displayState(reg, display.owner) orelse {
            skill.displayEntity = null;
            reg.destroyEntity(displayEntity);
            continue;
        };

        if (display.effect != state) {
            skill.displayEntity = null;
            reg.destroyEntity(displayEntity);
            continue;
        }

        skill.displayEntity = displayEntity;
        view.getPtr(entity, com.Position).* = displayPosition(reg, display.owner);
    }
}

fn createMissingDisplay(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{ com.skill.Skill, com.Position });
    while (view.next()) |entity| {
        const state = displayState(reg, view.toEntity(entity)) orelse continue;
        const skill = view.getPtr(entity, com.skill.Skill);
        if (reg.validEntity(skill.displayEntity)) continue;

        const owner = view.toEntity(entity);
        const displayEntity = spawn.effect(reg, state);
        reg.add(displayEntity, displayPosition(reg, owner));
        reg.getPtr(displayEntity, com.Animation).loop = true;
        skill.displayEntity = displayEntity;
        reg.add(displayEntity, com.skill.Display{
            .owner = owner,
            .effect = state,
        });
    }
}

fn displayState(
    reg: *zhu.ecs.Registry,
    entity: zhu.ecs.Entity,
) ?com.EffectEnum {
    if (reg.has(entity, com.skill.Active)) return .active;
    if (reg.has(entity, com.skill.Ready)) return .ready;
    return null;
}

fn displayPosition(reg: *zhu.ecs.Registry, owner: zhu.ecs.Entity) com.Position {
    const position = reg.get(owner, com.Position);
    return position.add(displayPositionOffset);
}
