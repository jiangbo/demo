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
            if (singletons.getConst(system.StateEnum) == .reset) {
                var entities = self.context.registry.entities();
                while (entities.next()) |entity| {
                    self.context.registry.removeAll(entity);
                }
                spawner.spawn(&self.context);
                singletons.get(system.StateEnum).* = .running;
            }
            system.runUpdateSystems(&self.context);
        }
    }
};
