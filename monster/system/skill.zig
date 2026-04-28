const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    updateCast(reg);
    updateCoolDown(reg, delta);
    updateDuration(reg, delta);
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
        view.remove(entity, com.skill.Active);
    }
}
