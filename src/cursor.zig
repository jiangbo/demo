const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub const MealType = enum {
    cola,
    sprite,
    braisedChickenHot,
    braisedChickenCold,
    meatBallHot,
    meatBallCold,
    redCookedPorkHot,
    redCookedPorkCold,
    braisedChickenBox,
    meatBallBox,
    redCookedPorkBox,
    takeoutBox,
};

pub const Meal = struct {
    type: MealType,
    picked: gfx.Texture,

    pub fn init(mealType: MealType) Meal {
        const path = switch (mealType) {
            .cola => "assets/cola.png",
            .sprite => "assets/sprite.png",
            .braisedChickenHot => "assets/bc_hot_picked.png",
            .braisedChickenCold => "assets/bc_cold_picked.png",
            .meatBallHot => "assets/mb_hot_picked.png",
            .meatBallCold => "assets/mb_cold_picked.png",
            .redCookedPorkHot => "assets/rcp_hot_picked.png",
            .redCookedPorkCold => "assets/rcp_cold_picked.png",
            .braisedChickenBox => "assets/bc_box.png",
            .meatBallBox => "assets/mb_box.png",
            .redCookedPorkBox => "assets/rcp_box.png",
            .takeoutBox => "assets/tb_picked.png",
        };

        return Meal{ .type = mealType, .picked = gfx.loadTexture(path) };
    }
};

pub var position: math.Vector = .zero;
pub var leftKeyDown: bool = false;
pub var picked: ?Meal = null;

pub fn event(ev: *const window.Event) void {
    if (ev.type == .MOUSE_MOVE) {
        position = .init(ev.mouse_x, ev.mouse_y);
    }

    if (ev.mouse_button == .LEFT) {
        if (ev.type == .MOUSE_DOWN) {
            leftKeyDown = true;
            switch (math.randU8(1, 3)) {
                1 => audio.playSound("assets/click_1.ogg"),
                2 => audio.playSound("assets/click_2.ogg"),
                3 => audio.playSound("assets/click_3.ogg"),
                else => unreachable,
            }
        }
        if (ev.type == .MOUSE_UP) leftKeyDown = false;
    }
}

pub fn render() void {
    if (picked) |meal| {
        gfx.draw(meal.picked, position.sub(meal.picked.size().scale(0.3)));
    }

    if (leftKeyDown) {
        gfx.draw(gfx.loadTexture("assets/cursor_down.png"), position);
    } else {
        gfx.draw(gfx.loadTexture("assets/cursor_idle.png"), position);
    }
}
