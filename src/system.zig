const std = @import("std");
const Context = @import("context.zig").Context;
const ray = @import("raylib.zig");
const component = @import("component.zig");

fn renderSystem(context: *Context) void {
    // 画出游戏地图
    ray.BeginDrawing();
    defer ray.EndDrawing();
    ray.ClearBackground(ray.WHITE);

    var iter = context.registry.basicView(component.Image).iterator();
    while (iter.next()) |image| {
        const x: c_int = @intCast(image.x);
        const y: c_int = @intCast(image.y);
        ray.DrawTexture(image.texture, x, y, ray.WHITE);
    }
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

pub fn runUpdateSystems(context: *Context) void {
    renderSystem(context);
}

pub fn runRenderSystems(_: Context) void {
    // renderSystem(context);
}

pub fn runDestroySystems(_: Context) void {
    ray.CloseWindow();
}
