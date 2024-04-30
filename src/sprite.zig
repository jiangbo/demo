const std = @import("std");
const zlm = @import("zlm");
const Texture2D = @import("texture.zig").Texture2D;
// const SpriteRenderer = @import("renderer.zig").SpriteRenderer;

pub const Sprite = struct {
    texture: Texture2D,
    position: zlm.Vec2 = zlm.Vec2.zero,
    size: zlm.Vec2 = zlm.Vec2.new(10, 10),
    rotate: f32 = 0,
    color: zlm.Vec3 = zlm.Vec3.one,
    solid: bool = true,
    destroyed: bool = false,
};
