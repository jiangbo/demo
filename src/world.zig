const system = @import("system.zig");
const spawner = @import("spawner.zig");
const asset = @import("asset.zig");
const engine = @import("engine.zig");

pub const World = struct {
    context: engine.Context,

    pub fn init(context: engine.Context) World {
        return World{ .context = context };
    }

    pub fn run(self: *World) void {
        engine.createWindow(40 * 32, 25 * 32, "Dungeon crawl");
        defer engine.closeWindow();

        asset.init();
        defer asset.deinit();

        var singletons = self.context.registry.singletons();
        singletons.add(system.StateEnum.reset);
        while (engine.shouldContinue()) {
            const state = singletons.get(system.StateEnum);
            if (state.* == .reset) {
                var entities = self.context.registry.entities();
                while (entities.next()) |entity| {
                    self.context.registry.removeAll(entity);
                }
                spawner.spawn(&self.context);
                state.* = .running;
            }

            if (state.* == .over) {
                if (engine.isPressedSpace()) state.* = .reset;
            }

            system.runUpdateSystems(&self.context);
        }
    }
};
