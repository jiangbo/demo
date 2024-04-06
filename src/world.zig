const Context = @import("context.zig").Context;
const system = @import("system.zig");

pub const World = struct {
    context: Context,

    pub fn init(context: Context) World {
        return World{ .context = context };
    }

    pub fn run(self: *World) void {
        system.runSetupSystems(self.context);
        while (self.context.running) {
            system.runUpdateSystems(self.context);
        }
    }
};
