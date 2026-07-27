const ecs = @import("ecs");

const zhu = @import("zhu");
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;

const component = @import("component.zig");
const map = @import("map.zig");
const storage = @import("storage.zig");

const Collider = component.Collider;
const Player = component.actor.Player;
const Position = component.Position;

const maxExp = 100; // 经验最大值

pub fn cameraLookAt(world: *ecs.World) void {
    const area = collider(world);
    const half = window.size.scale(0.5);
    const max = map.current.grid.size().sub(window.size);
    camera.main.position = area.min.sub(half).clamp(.zero, max);
}

pub fn collider(world: *ecs.World) math.Rect {
    const entity = world.getIdentity(Player).?;
    const position = world.get(entity, Position).?;
    const value = world.get(entity, Collider).?;
    return value.move(position);
}

pub fn isLevelUp(stats: storage.Stats) bool {
    return stats.exp >= maxExp;
}

pub fn levelUp(stats: *storage.Stats) void {
    stats.level += stats.exp / maxExp;
    stats.maxHealth += stats.exp / maxExp * 30;
    stats.attack += stats.exp / maxExp * 1;
    stats.defend += stats.exp / maxExp * 1;
    stats.health += (stats.maxHealth - stats.health) / 2;
    stats.exp %= maxExp;
    stats.health = stats.maxHealth;
}
