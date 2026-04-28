const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    updateCoolDown(reg, delta);
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
