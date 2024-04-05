const std = @import("std");
const ray = @import("raylib.zig");
const map = @import("map.zig");

pub fn main() !void {
    const width = map.DISPLAY_WIDTH * map.SIZE;
    const height = map.DISPLAY_HEIGHT * map.SIZE;
    ray.InitWindow(width, height, "Dungeon crawl");
    defer ray.CloseWindow();

    var mapImage = map.MapBuilder.init();
    defer mapImage.map.tilemap.deinit();

    while (!ray.WindowShouldClose()) {
        mapImage.update();

        // 画出游戏地图
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.WHITE);

        mapImage.render();
    }
}
