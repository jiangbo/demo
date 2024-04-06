const std = @import("std");
const Context = @import("context.zig").Context;
const ray = @import("raylib.zig");

const RenderSystem = struct {};

fn renderSystem() void {
    // 画出游戏地图
    ray.BeginDrawing();
    defer ray.EndDrawing();
    ray.ClearBackground(ray.WHITE);
}

fn inputSystem(context: *Context) void {
    const flag = ray.WindowShouldClose();
    context.running = !flag;
}

fn initSystem(context: Context) void {
    const width: c_int = @intCast(context.config.width);
    const height: c_int = @intCast(context.config.height);
    ray.InitWindow(width, height, context.config.title);
}

pub fn shouldContinue() bool {
    return !ray.WindowShouldClose();
}

pub fn runSetupSystems(context: Context) void {
    initSystem(context);
}

pub fn runUpdateSystems(_: *Context) void {
    renderSystem();
}

pub fn runDestroySystems(_: Context) void {
    ray.CloseWindow();
}
