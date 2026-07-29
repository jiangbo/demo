const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");

const Collider = component.Collider;
const Dialog = component.dialog.Dialog;
const Player = component.actor.Player;
const Portal = component.Portal;
const Position = component.Position;
const Request = component.event.Request;
const Story = component.event.Story;

pub fn update(world: *ecs.World) void {
    const previous = world.getIdentityEntity(Portal);
    world.removeIdentity(Portal);

    const player = world.getIdentityEntity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const center = collider.move(position).center();

    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
        if (!portal.area.contains(center)) continue;

        if (previous) |old| {
            if (old != entity) world.remove(old, Portal.Wait);
        }
        world.addIdentity(entity, Portal);

        if (world.has(entity, Portal.Wait)) return;

        const data = zon.Portal.get(portal.key);
        const progress = world.getGlobal(storage.Progress).?.value;
        if (progress > data.progress) {
            const fmt = "change map portal: {s}";
            std.log.info(fmt, .{@tagName(portal.key)});
            world.addEvent(Request.map);
            return;
        }

        if (progress == 1) {
            world.add(entity, Portal.Wait{});
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[5].lines,
            });
        }

        if (progress == 4) {
            world.addEvent(Story{ .progress = progress });
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[32].lines,
            });
        }

        if (progress == 10) {
            world.add(entity, Portal.Wait{});
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[37].lines,
            });
        }
        return;
    }

    if (previous) |entity| {
        world.remove(entity, Portal.Wait);
    }
}

test "选择玩家当前所在的传送区域" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, storage.Progress{});
    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.zero, .square(16)),
    });

    const portal = world.createEntity();
    world.add(portal, Portal{
        .key = .homeToCity,
        .area = .init(.zero, .square(32)),
    });

    update(&world);
    try std.testing.expect(world.isIdentity(portal, Portal));

    world.add(player, Position.xy(32, 0));
    update(&world);
    try std.testing.expect(!world.hasIdentity(Portal));
}
