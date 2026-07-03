pub const animation = @import("animation.zig");
pub const chest = @import("chest.zig");
pub const control = @import("control.zig");
pub const dialog = @import("dialog.zig");
pub const farm = @import("farm.zig");
pub const interact = @import("interact.zig");
pub const life = @import("life.zig");
pub const light = @import("light.zig");
pub const movement = @import("movement.zig");
pub const pickup = @import("pickup.zig");
pub const render = @import("render.zig");
pub const rest = @import("rest.zig");
pub const sound = @import("sound.zig");
pub const time = @import("time.zig");
pub const transition = @import("transition.zig");
pub const wander = @import("wander.zig");

pub fn init() void {
    // 有独立资源或初始状态的系统在进入首个场景前完成初始化。
    time.init();
    light.init();
}
