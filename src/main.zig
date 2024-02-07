const std = @import("std");
const ray = @import("raylib.zig");

const screenWidth = 800;
const screenHeight = 450;

const MAX_BUILDINGS = 100;

var player: ray.Rectangle = .{ .x = 400, .y = 280, .width = 40, .height = 40 };
var buildings: [MAX_BUILDINGS]ray.Rectangle = undefined;
var buildColors: [MAX_BUILDINGS]ray.Color = undefined;

pub fn main() void {
    ray.InitWindow(screenWidth, screenHeight, "raylib [core] example");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var spacing: f32 = 0;

    for (0..MAX_BUILDINGS) |index| {
        buildings[index].width = @floatFromInt(ray.GetRandomValue(50, 200));
        buildings[index].height = @floatFromInt(ray.GetRandomValue(100, 800));
        buildings[index].y = screenHeight - 130.0 - buildings[index].height;
        buildings[index].x = -6000.0 + spacing;

        spacing += buildings[index].width;

        buildColors[index] = ray.Color{
            .r = @intCast(ray.GetRandomValue(200, 240)),
            .g = @intCast(ray.GetRandomValue(200, 240)),
            .b = @intCast(ray.GetRandomValue(200, 250)),
            .a = 255,
        };
    }

    var camera: ray.Camera2D = .{
        .target = .{ .x = player.x + 20.0, .y = player.y + 20.0 },
        .offset = .{ screenWidth / 2.0, screenHeight / 2.0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };

    while (!ray.WindowShouldClose()) {
        update(&player, &camera);

        ray.BeginDrawing();
        defer ray.EndDrawing();
        draw();
    }
}

fn update(camera: *ray.Camera2D) void {
    if (ray.IsKeyDown(ray.KEY_RIGHT)) player.x += 2 else if (ray.IsKeyDown(ray.KEY_LEFT)) player.x -= 2;

    // Camera target follows player
    camera.target = .{ player.x + 20, player.y + 20 };

    // Camera rotation controls
    if (ray.IsKeyDown(ray.KEY_A)) camera.rotation -= 1 else if (ray.IsKeyDown(ray.KEY_S)) camera.rotation += 1;

    // Limit camera rotation to 80 degrees (-40 to 40)
    if (camera.rotation > 40) camera.rotation = 40 else if (camera.rotation < -40) camera.rotation = -40;

    // Camera zoom controls
    camera.zoom += (ray.GetMouseWheelMove() * 0.05);

    if (camera.zoom > 3.0) camera.zoom = 3.0 else if (camera.zoom < 0.1) camera.zoom = 0.1;

    // Camera reset (zoom and rotation)
    if (ray.IsKeyPressed(ray.KEY_R)) {
        camera.zoom = 1.0;
        camera.rotation = 0.0;
    }
}

fn draw(camera: *ray.Camera2D) void {
    ray.ClearBackground(ray.RAYWHITE);

    ray.BeginMode2D(camera);

    ray.DrawRectangle(-6000, 320, 13000, 8000, ray.DARKGRAY);

    for (0..MAX_BUILDINGS) |index|
        ray.DrawRectangleRec(buildings[index], buildColors[index]);

    ray.DrawRectangleRec(player, ray.RED);

    ray.DrawLine(camera.target.x, -screenHeight * 10, camera.target.x, screenHeight * 10, ray.GREEN);
    ray.DrawLine(-screenWidth * 10, camera.target.y, screenWidth * 10, camera.target.y, ray.GREEN);

    ray.EndMode2D();

    ray.DrawText("SCREEN AREA", 640, 10, 20, ray.RED);

    ray.DrawRectangle(0, 0, screenWidth, 5, ray.RED);
    ray.DrawRectangle(0, 5, 5, screenHeight - 10, ray.RED);
    ray.DrawRectangle(screenWidth - 5, 5, 5, screenHeight - 10, ray.RED);
    ray.DrawRectangle(0, screenHeight - 5, screenWidth, 5, ray.RED);

    ray.DrawRectangle(10, 10, 250, 113, ray.Fade(ray.SKYBLUE, 0.5));
    ray.DrawRectangleLines(10, 10, 250, 113, ray.BLUE);

    ray.DrawText("Free 2d camera controls:", 20, 20, 10, ray.BLACK);
    ray.DrawText("- Right/Left to move Offset", 40, 40, 10, ray.DARKGRAY);
    ray.DrawText("- Mouse Wheel to Zoom in-out", 40, 60, 10, ray.DARKGRAY);
    ray.DrawText("- A / S to Rotate", 40, 80, 10, ray.DARKGRAY);
    ray.DrawText("- R to reset Zoom and Rotation", 40, 100, 10, ray.DARKGRAY);
}
