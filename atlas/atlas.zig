const std = @import("std");

pub const Atlas = struct {
    frames: []AtlasFrame,
    meta: Meta,
};

pub const AtlasFrame = struct {
    filename: []const u8 = &.{},
    frame: Rect,
    rotated: bool,
    trimmed: bool,
    spriteSourceSize: Rect,
    sourceSize: struct { w: i32, h: i32 },
};

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

pub const Meta = struct {
    app: []const u8,
    version: []const u8,
    image: []const u8,
    format: []const u8,
    size: struct { w: i32, h: i32 },
    scale: f32,
    related_multi_packs: []const u8 = &.{},
};
