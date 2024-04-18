const system = @import("system.zig");
const spawner = @import("spawner.zig");
const asset = @import("asset.zig");
const engine = @import("engine.zig");

pub fn run(ctx: *engine.Context) void {
    engine.createWindow(40 * 32, 25 * 32, "Dungeon crawl");
    defer engine.closeWindow();

    asset.init();
    defer asset.deinit();

    var singletons = ctx.registry.singletons();
    singletons.add(system.StateEnum.reset);
    while (engine.shouldContinue()) {
        const state = singletons.get(system.StateEnum);
        if (state.* == .reset) {
            var entities = ctx.registry.entities();
            while (entities.next()) |entity| {
                ctx.registry.removeAll(entity);
            }
            spawner.spawn(ctx);
            state.* = .running;
        }

        if (state.* == .over and engine.isPressedSpace()) state.* = .reset;
        system.runUpdateSystems(ctx);
    }
}
