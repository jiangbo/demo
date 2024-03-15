const std = @import("std");
const basic = @import("basic.zig");
const Texture = @import("backend.zig").Texture;

pub const Image = struct {
    texture: Texture,

    pub fn init(name: []const u8) Image {
        return Image{ .texture = loadTexture(name) };
    }

    pub fn draw(self: Image) void {
        self.texture.draw();
    }

    pub fn drawXY(self: Image, x: usize, y: usize) void {
        self.texture.drawXY(x, y);
    }

    pub fn deinit(self: Image) void {
        self.texture.deinit();
    }
};

pub const TileMap = struct {
    texture: Texture,
    unit: usize,

    pub fn init(name: []const u8, unit: usize) TileMap {
        return .{ .texture = loadTexture(name), .unit = unit };
    }

    pub fn draw(self: TileMap) void {
        self.texture.draw();
    }

    pub fn drawI(self: TileMap, index: usize, x: usize, y: usize) void {
        const rx = index * self.unit % self.texture.width;
        const ry = index / (self.texture.width / self.unit) * self.unit;
        const rec = basic.Rectangle.init(rx, ry, self.unit, self.unit);

        const vec = .{ .x = x * self.unit, .y = y * self.unit };
        self.texture.drawRec(rec, vec);
    }

    pub fn deinit(self: TileMap) void {
        self.texture.deinit();
    }
};

const maxPathLength = 100;

fn loadTexture(name: []const u8) Texture {
    var buf: [maxPathLength]u8 = undefined;
    const format = "data/image/{s}";
    const path = std.fmt.bufPrintZ(&buf, format, .{name}) catch |e| {
        std.log.err("load texture error: {}", .{e});
        return Texture.empty();
    };
    return Texture.init(path);
}
