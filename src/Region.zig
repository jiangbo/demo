const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const cursor = @import("cursor.zig");

const Region = @This();

pub const pickType = gfx.Texture;

pub const RegionType = enum {
    deliver,
    cola,
    sprite,
    takeoutBoxBundle,
    meatBallBox,
    braisedChickenBox,
    redCookedPorkBox,
    microWave,
    takeoutBox,
};

type: RegionType,
area: math.Rectangle,
texture: ?gfx.Texture = null,
meal: ?cursor.Meal = null,

pub fn init(x: f32, y: f32, regionType: RegionType) Region {
    const position: math.Vector = .init(x, y);

    var self: Region = .{ .area = .{}, .type = regionType };
    switch (regionType) {
        .deliver => {
            self.texture = gfx.loadTexture("assets/eleme.png");
        },

        .cola => {
            self.texture = gfx.loadTexture("assets/cola_bundle.png");
            self.meal = .init(.cola);
        },

        .sprite => {
            self.texture = gfx.loadTexture("assets/sprite_bundle.png");
            self.meal = .init(.sprite);
        },

        .takeoutBoxBundle => {
            self.texture = gfx.loadTexture("assets/tb_bundle.png");
            self.meal = .init(.takeoutBox);
        },

        .meatBallBox => {
            self.texture = gfx.loadTexture("assets/mb_box_bundle.png");
            self.meal = .init(.meatBallBox);
        },

        .braisedChickenBox => {
            self.texture = gfx.loadTexture("assets/bc_box_bundle.png");
            self.meal = .init(.braisedChickenBox);
        },

        .redCookedPorkBox => {
            self.texture = gfx.loadTexture("assets/rcp_box_bundle.png");
            self.meal = .init(.redCookedPorkBox);
        },

        .microWave => {
            self.texture = gfx.loadTexture("assets/mo_opening.png");
        },
        .takeoutBox => {
            self.area = .init(position, .{ .x = 92, .y = 100 });
        },
    }

    if (self.texture) |texture| {
        self.area = .init(position, texture.size());
    }

    return self;
}
