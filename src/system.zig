const std = @import("std");
const Context = @import("context.zig").Context;
const ray = @import("raylib.zig");

const RenderSystem = struct {};

fn renderSystem() void {}

fn printHelloSystem() void {
    std.debug.print("hello world\n", .{});
}

pub fn createWindow(context: Context) void {
    const width: c_int = @intCast(context.config.width);
    const height: c_int = @intCast(context.config.height);
    ray.InitWindow(width, height, context.config.title);
}

pub fn closeWindow() void {
    ray.CloseWindow();
}

pub fn runSetupSystems(_: Context) void {}

pub fn runUpdateSystems(_: Context) void {
    printHelloSystem();
}
