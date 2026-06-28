const std = @import("std");

pub const Font = struct {
    atlas: Atlas,
    metrics: Metrics,
    glyphs: []const Glyph,
};

pub const Atlas = struct {
    type: []const u8,
    size: f32,
    width: u32,
    height: u32,
    yOrigin: []const u8,
};

pub const Metrics = struct {
    emSize: f32,
    lineHeight: f32,
    ascender: f32,
    descender: f32,
    underlineY: f32,
    underlineThickness: f32,
};

pub const Glyph = struct {
    unicode: u32,
    advance: f32,
    planeBounds: Rect = .{},
    atlasBounds: Rect = .{},
};

pub const Rect = struct {
    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
};
