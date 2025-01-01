const std = @import("std");
const win32 = @import("win32");
const Direct3D = @import("Direct3D.zig");

pub const VSYNC_ENABLED: bool = true;
pub const SCREEN_DEPTH: f32 = 1000.0;
pub const SCREEN_NEAR: f32 = 0.1;

direct3D: Direct3D,

pub fn initialize(window: ?win32.foundation.HWND) @This() {
    var d = Direct3D{
        .width = 0,
        .height = 0,
        .vsync = true,
        .depth = SCREEN_DEPTH,
        .near = SCREEN_NEAR,
    };

    d.initialize(window);
    return .{ .direct3D = d };
}

pub fn frame(self: *@This()) bool {
    return self.render();
}

pub fn render(self: *@This()) bool {
    self.direct3D.beginScene(0.5, 0.5, 0.5, 1.0);
    self.direct3D.endScene();
    return true;
}

pub fn shutdown(self: *@This()) void {
    self.direct3D.shutdown();
}
