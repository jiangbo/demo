const std = @import("std");
const ray = @import("raylib.zig");
const game = @import("game.zig");
const ecs = @import("ecs");

pub const Velocity = struct { x: f32, y: f32 };
pub const Position = struct { x: f32, y: f32 };

pub fn main() !void {
    const width = game.DISPLAY_WIDTH * game.SIZE;
    const height = game.DISPLAY_HEIGHT * game.SIZE;
    ray.InitWindow(width, height, "Dungeon crawl");
    defer ray.CloseWindow();

    var mapBuilder = game.MapBuilder.init();
    defer mapBuilder.map.tilemap.deinit();

    while (!ray.WindowShouldClose()) {
        mapBuilder.update();

        // 画出游戏地图
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.WHITE);

        mapBuilder.render();
    }
}
