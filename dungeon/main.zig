const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const window = zhu.window;
// const scene = @import("scene.zig");
const gfx = zhu.gfx;
const camera = zhu.camera;

pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

pub var texture: gfx.Texture = undefined;
pub fn init() void {
    // scene.init();
    camera.init(100);
    texture = gfx.loadTexture("assets/dungeonfont.png", .init(512, 512));
}

pub fn frame(delta: f32) void {
    _ = delta;
    // scene.update(delta);
    // scene.draw();
    camera.beginDraw();
    defer camera.endDraw();

    camera.draw(texture, .zero);
}

pub fn deinit() void {
    // scene.deinit();

}

pub fn main() void {
    var allocator: std.mem.Allocator = undefined;
    var debugAllocator: std.heap.DebugAllocator(.{}) = undefined;
    if (builtin.mode == .Debug) {
        debugAllocator = std.heap.DebugAllocator(.{}).init;
        allocator = debugAllocator.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    defer if (builtin.mode == .Debug) {
        _ = debugAllocator.deinit();
    };

    if (builtin.os.tag == .windows) {
        _ = ImmDisableIME(-1);
    }

    window.run(allocator, .{
        .title = "地宫探险",
        .logicSize = .{ .x = 512, .y = 512 },
    });
}
