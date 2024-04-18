const system = @import("system.zig");
const spawner = @import("spawner.zig");
const asset = @import("asset.zig");
const engine = @import("engine.zig");

pub fn run(ctx: *engine.Context) void {
    engine.createWindow(40 * 32, 25 * 32, "Dungeon crawl");
    defer engine.closeWindow();

    asset.init();
    defer asset.deinit();

    ctx.registry.singletons().add(system.StateEnum.reset);
    while (engine.shouldContinue()) {
        const state = ctx.registry.singletons().get(system.StateEnum);
        if (state.* == .reset) {
            var entities = ctx.registry.entities();
            while (entities.next()) |e| ctx.registry.removeAll(e);
            spawner.spawn(ctx);
            state.* = .running;
        }

        if (state.* == .over and engine.isPressedSpace())
            state.* = .reset;

        system.runUpdateSystems(ctx);
    }
}
