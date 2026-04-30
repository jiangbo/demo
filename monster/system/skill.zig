const zhu = @import("zhu");

const com = @import("../component.zig");
const ctx = @import("../context.zig");
const spawn = @import("../spawn.zig");

const displayPositionOffset = zhu.Vector2.xy(0, -96);

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    updateCast(reg);
    updateCoolDown(reg, delta);
    updateDuration(reg, delta);
    updateCostRecovery(reg, delta);
    updateDisplay(reg);
}

fn updateCast(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{ com.skill.Skill, com.skill.Cast });
    while (view.next()) |entity| {
        if (!view.has(entity, com.skill.Ready)) continue;
        if (view.has(entity, com.skill.Passive)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);
        if (skill.passive) continue;

        skill.durationTimer = 0;
        if (view.tryGetPtr(entity, com.Stats)) |stats| {
            skill.buff.multiplyStats(stats);
        }
        if (view.tryGetPtr(entity, com.attack.Range)) |range| {
            range.v *= skill.buff.range;
        }
        if (view.tryGetPtr(entity, com.attack.CoolDown)) |coolDown| {
            coolDown.v *= skill.buff.interval;
        }
        view.remove(entity, com.skill.Ready);
        view.add(entity, com.skill.Active{});
        if (skill.id == .shield) {
            view.add(entity, com.animation.Play{
                .index = @intFromEnum(com.StateEnum.walk),
                .loop = true,
            });
        }
    }

    reg.clear(com.skill.Cast);
}

fn updateCoolDown(reg: *zhu.ecs.Registry, delta: f32) void {
    var view = reg.view(.{com.skill.Skill});
    while (view.next()) |entity| {
        if (view.has(entity, com.skill.Ready)) continue;
        if (view.has(entity, com.skill.Passive)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);
        if (skill.passive) continue;

        skill.coolDownTimer = @min(skill.coolDown, skill.coolDownTimer + delta);
        if (skill.coolDownTimer >= skill.coolDown) {
            skill.coolDownTimer = skill.coolDown;
            view.add(entity, com.skill.Ready{});
        }
    }
}

fn updateDuration(reg: *zhu.ecs.Registry, delta: f32) void {
    var view = reg.view(.{ com.skill.Skill, com.skill.Active });
    while (view.next()) |entity| {
        if (view.has(entity, com.skill.Passive)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);
        if (skill.passive) continue;

        skill.durationTimer += delta;
        if (skill.durationTimer < skill.duration) continue;

        skill.durationTimer = 0;
        skill.coolDownTimer = 0;
        if (view.tryGetPtr(entity, com.Stats)) |stats| {
            skill.buff.divideStats(stats);
        }
        if (view.tryGetPtr(entity, com.attack.CoolDown)) |coolDown| {
            coolDown.v /= skill.buff.interval;
        }
        if (view.tryGetPtr(entity, com.attack.Range)) |range| {
            range.v /= skill.buff.range;
        }
        if (skill.id == .shield) {
            view.add(entity, com.animation.Play{
                .index = @intFromEnum(com.StateEnum.idle),
                .loop = true,
            });
        }
        view.remove(entity, com.skill.Active);
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

        if (display.state != state) {
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
        const displayEntity = spawn.skillDisplay(
            reg,
            displayEffect(state),
            displayPosition(reg, owner),
        );
        skill.displayEntity = displayEntity;
        reg.add(displayEntity, com.skill.Display{
            .owner = owner,
            .state = state,
        });
    }
}

fn displayState(
    reg: *zhu.ecs.Registry,
    entity: zhu.ecs.Entity,
) ?com.skill.DisplayState {
    if (reg.has(entity, com.skill.Active)) return .active;
    if (reg.has(entity, com.skill.Ready)) return .ready;
    return null;
}

fn displayPosition(reg: *zhu.ecs.Registry, owner: zhu.ecs.Entity) com.Position {
    const position = reg.get(owner, com.Position);
    return position.add(displayPositionOffset);
}

fn displayEffect(state: com.skill.DisplayState) com.EffectEnum {
    return switch (state) {
        .ready => .ready,
        .active => .active,
    };
}
