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

        spawner.spawn(&self.context);

        while (engine.shouldContinue()) {
            system.runUpdateSystems(&self.context);
        }
    }
};
