const ray = @cImport({
    @cInclude("raylib.h");
});
const std = @import("std");
const basic = @import("basic.zig");
const Rectangle = basic.Rectangle;
const Vector = basic.Vector;

var screenWidth: usize = 0;

pub fn init(width: usize, height: usize, title: [:0]const u8) void {
    ray.InitWindow(@intCast(width), @intCast(height), title);
    ray.SetTargetFPS(60);
    ray.SetExitKey(ray.KEY_NULL);
    screenWidth = width;
    return;
}

pub fn deinit() void {
    ray.CloseWindow();
}

pub fn shoudContinue() bool {
    return !ray.WindowShouldClose();
}

pub fn beginDraw() void {
    ray.BeginDrawing();
    ray.ClearBackground(ray.WHITE);
}

pub fn endDraw() void {
    ray.DrawFPS(@intCast(screenWidth - 100), 10);
    ray.EndDrawing();
}

pub fn time() usize {
    return @intFromFloat(ray.GetTime() * 1000);
}

pub fn getPressed() usize {
    return @intCast(ray.GetKeyPressed());
}

pub fn isPressed(key: usize) bool {
    return ray.IsKeyPressed(@intCast(key));
}

pub fn random(min: u16, max: u16) usize {
    return @intCast(ray.GetRandomValue(min, max));
}

pub const Texture = struct {
    width: usize,
    texture: ray.Texture2D,

    pub fn init(path: [:0]const u8) Texture {
        const texture = ray.LoadTexture(path);
        return .{ .texture = texture, .width = @intCast(texture.width) };
    }

    pub fn empty() Texture {
        return Texture{ .texture = ray.Texture2D{}, .width = 0 };
    }

    pub fn draw(self: Texture) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    pub fn drawXY(self: Texture, x: usize, y: usize) void {
        const vec = .{ .x = usizeToF32(x), .y = usizeToF32(y) };
        ray.DrawTextureV(self.texture, vec, ray.WHITE);
    }

    pub fn drawRec(self: Texture, rec: Rectangle, pos: Vector) void {
        const rectangle = ray.Rectangle{
            .x = usizeToF32(rec.x),
            .y = usizeToF32(rec.y),
            .width = usizeToF32(rec.width),
            .height = usizeToF32(rec.height),
        };
        const vec = .{ .x = usizeToF32(pos.x), .y = usizeToF32(pos.y) };
        ray.DrawTextureRec(self.texture, rectangle, vec, ray.WHITE);
    }

    pub fn deinit(self: Texture) void {
        ray.UnloadTexture(self.texture);
    }

    fn usizeToF32(value: usize) f32 {
        return @floatFromInt(value);
    }
};