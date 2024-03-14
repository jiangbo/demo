const std = @import("std");
const ray = @import("../raylib.zig");

const maxPathLength = 30;

// pub const Image = struct {};

pub const Vector = struct {
    x: usize = 0,
    y: usize = 0,

    fn toRay(self: Vector) ray.Vector2 {
        return ray.Vector2{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
        };
    }
};

pub const Rectangle = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize = 0,
    height: usize = 0,

    fn toRay(self: Rectangle) ray.Rectangle {
        return ray.Rectangle{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
            .width = @floatFromInt(self.width),
            .height = @floatFromInt(self.height),
        };
    }
};

pub const Texture = struct {
    texture: ray.Texture2D,

    pub fn init(name: []const u8) Texture {
        var buf: [maxPathLength]u8 = undefined;
        const format = "data/image/{s}";
        const path = std.fmt.bufPrintZ(&buf, format, .{name}) catch |e| {
            std.log.err("load image error: {}", .{e});
            return Texture{ .texture = ray.Texture2D{} };
        };

        return Texture{ .texture = ray.LoadTexture(path) };
    }

    pub fn draw(self: Texture) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    pub fn drawPositin(self: Texture, x: usize, y: usize) void {
        ray.DrawTextureV(self.texture, (Vector{ .x = x, .y = y }).toRay(), ray.WHITE);
    }

    pub fn drawRectangle(self: Texture, rec: Rectangle, pos: Vector) void {
        ray.DrawTextureRec(self.texture, rec.toRay(), pos.toRay(), ray.WHITE);
    }

    pub fn deinit(self: Texture) void {
        ray.UnloadTexture(self.texture);
    }
};
