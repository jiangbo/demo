const Context = @import("context.zig").Context;
const system = @import("system.zig");
const spawner = @import("spawner.zig");
const asset = @import("asset.zig");

pub const World = struct {
    context: Context,

    pub fn init(context: Context) World {
        return World{ .context = context };
    }

    pub fn run(self: *World) void {
        system.runSetupSystems(self.context);
        defer system.runDestroySystems(self.context);

        asset.init();
        defer asset.deinit();

        spawner.spawn(&self.context);
        defer spawner.deinit(&self.context);

        while (system.shouldContinue()) {
            system.runUpdateSystems(&self.context);
            system.runRenderSystems(self.context);
        }
    }
};
