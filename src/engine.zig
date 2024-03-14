const std = @import("std");
const ray = @import("raylib.zig");

var screenWidth: usize = 0;

var alloc: std.mem.Allocator = undefined;

pub fn init(width: usize, height: usize, title: [:0]const u8) void {
    ray.InitWindow(@intCast(width), @intCast(height), title);
    ray.SetTargetFPS(60);
    ray.SetExitKey(ray.KEY_NULL);
    screenWidth = width;
    return;
}

pub fn withAllocator(allocator: std.mem.Allocator) void {
    alloc = allocator;
}

pub fn shoudContinue() bool {
    return !ray.WindowShouldClose();
}

pub fn beginDraw() void {
    ray.BeginDrawing();
    ray.ClearBackground(ray.WHITE);
}

pub fn drawText(x: usize, y: usize, text: [:0]const u8) void {
    ray.DrawText(text, @intCast(x), @intCast(y), 32, ray.RED);
}

pub fn clear(color: u32) void {
    ray.ClearBackground(ray.GetColor(color));
}

pub fn endDraw() void {
    ray.DrawFPS(@intCast(screenWidth - 100), 10);
    ray.EndDrawing();
}

pub fn getPressed() usize {
    return @intCast(ray.GetKeyPressed());
}

pub fn isPressed(key: usize) bool {
    return ray.IsKeyPressed(@intCast(key));
}

pub fn time() usize {
    return @intFromFloat(ray.GetTime() * 1000);
}

pub fn deinit() void {
    ray.CloseWindow();
}

const maxPathLength = 30;

pub fn readStageText(allocator: std.mem.Allocator, level: usize) ![]const u8 {
    var buf: [maxPathLength]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "data/stage/{}.txt", .{level});

    std.log.info("load stage: {s}", .{path});
    return try readAll(allocator, path);
}

fn readAll(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

const image = @import("engine/image.zig");
pub const Vecotr = image.Vector;
pub const Rectangle = image.Rectangle;
pub const Texture = image.Texture;

pub const Key = @import("engine/key.zig").Key;
