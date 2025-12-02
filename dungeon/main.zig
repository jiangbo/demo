const std = @import("std");
const builtin = @import("builtin");

const window = @import("zhu").window;
const scene = @import("scene.zig");

pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

const zhu = @import("zhu");
pub fn init() void {
    scene.init();
    _ = Font.load("assets/font/VonwaonBitmap-16px.ttf", 32);
}

pub const Font = struct {
    pub fn load(path: [:0]const u8, scale: f32) []u8 {
        _ = zhu.assets.File.load(path, 0, handler);
        _ = scale;
        return &.{};
    }

    fn handler(response: zhu.assets.Response) []u8 {
        const data = response.data;
        std.log.info("data len: {}", .{data.len});
        return window.allocator.dupe(u8, data) catch unreachable;
    }
};

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit() void {
    scene.deinit();
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
        .logicSize = .{ .x = 640, .y = 400 },
    });
}
