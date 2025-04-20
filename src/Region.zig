const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const cursor = @import("cursor.zig");
const scene = @import("scene.zig");

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
timer: ?window.Timer = null,

wanted: [6]cursor.Meal = undefined,

const DELIVER_TIMEOUT = 40;

pub fn init(x: f32, y: f32, regionType: RegionType) Region {
    const position: math.Vector = .init(x, y);

    var self: Region = .{ .area = .{}, .type = regionType };
    switch (regionType) {
        .deliver => {
            const meituan = math.rand.boolean();
            if (meituan) {
                self.texture = gfx.loadTexture("assets/meituan.png");
            } else {
                self.texture = gfx.loadTexture("assets/eleme.png");
            }
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

pub fn pick(self: *Region) void {
    cursor.picked = self.meal;
    scene.returnPosition = cursor.position;
    scene.pickedMeal = cursor.picked;
    scene.pickedRegion = self;

    if (self.type == .takeoutBox) {
        self.meal = null;
        scene.returnPosition = self.area.min;
    }
    if (self.type == .microWave) {
        self.meal = null;
        scene.returnPosition = self.area.min.add(.{ .x = 113, .y = 65 });
    }
}

pub fn place(self: *Region) void {
    if (self.type == .takeoutBox) return self.placeInTakeoutBox();
    if (self.type == .microWave) return self.placeInMicroWave();

    if (self.meal) |meal| {
        if (meal.type == cursor.picked.?.type) {
            cursor.picked = null;
        }
    }
}

pub fn placeInTakeoutBox(self: *Region) void {
    if (self.meal == null) {
        switch (cursor.picked.?.type) {
            .cola, .sprite, .meatBallBox => {},
            .braisedChickenBox, .redCookedPorkBox => {},
            else => {
                self.meal = cursor.picked;
                cursor.picked = null;
            },
        }
        return;
    }

    if (self.meal.?.type == .takeoutBox) {
        self.meal = switch (cursor.picked.?.type) {
            .braisedChickenBox => .init(.braisedChickenCold),
            .meatBallBox => .init(.meatBallCold),
            .redCookedPorkBox => .init(.redCookedPorkCold),
            else => return,
        };
        cursor.picked = null;
    }
}

pub fn placeInMicroWave(self: *Region) void {
    if (self.meal != null) return;

    self.meal = switch (cursor.picked.?.type) {
        .braisedChickenCold => .init(.braisedChickenHot),
        .meatBallCold => .init(.meatBallHot),
        .redCookedPorkCold => .init(.redCookedPorkHot),
        else => return,
    };
    cursor.picked = null;
    audio.playSound("assets/mo_working.ogg");
    self.texture = gfx.loadTexture("assets/mo_working.png");
    self.timer = .init(9);
}

pub fn timerFinished(self: *Region) void {
    if (self.type == .microWave) {
        self.texture = gfx.loadTexture("assets/mo_opening.png");
        audio.playSound("assets/mo_complete.ogg");
    }
    self.timer = null;
}

pub fn draw(self: *Region) void {
    if (self.texture) |texture| {
        gfx.drawTexture(texture, self.area.min);
    }
}

pub fn update(self: *Region) void {
    if (self.type == .microWave) {
        if (self.meal) {}
    }
}
