const std = @import("std");
const ray = @import("raylib.zig");

pub fn main() !void {
    const screenWidth: c_int = 800;
    const screenHeight: c_int = 450;

    ray.InitWindow(screenWidth, screenHeight, "raylib [shapes] example");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {

        // Update

        // Draw
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.RAYWHITE);

        // const rec = ray.Rectangle{ .x = 600, .y = 40, .width = 120, .height = 20 };
        // _ = ray.GuiSliderBar(rec, "StartAngle", null, 0, -450, 450);

        ray.DrawFPS(10, 10);
    }
}
