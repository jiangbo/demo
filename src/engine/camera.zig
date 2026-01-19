const std = @import("std");

const math = @import("math.zig");
const text = @import("text.zig");
const assets = @import("assets.zig");
const graphics = @import("graphics.zig");
const batch = @import("batch.zig");

const Color = graphics.Color;
const Vector2 = math.Vector2;
const ImageId = graphics.ImageId;
const Image = graphics.Image;
const String = text.String;

pub var modeEnum: enum { world, window } = .world;
pub var position: Vector2 = .zero;

pub fn toWorld(windowPosition: Vector2) Vector2 {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector2) Vector2 {
    return worldPosition.sub(position);
}
