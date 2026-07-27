const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const zon = @import("../zon.zig");
const about = @import("about.zig");
const dialog = @import("dialog.zig");
const item = @import("item.zig");
const pause = @import("pause.zig");
const sale = @import("sale.zig");
const save = @import("save.zig");
const shop = @import("shop.zig");
const tip = @import("tip.zig");

const Dialog = component.dialog.Dialog;

pub const battle = @import("battle.zig");
pub const inventory = @import("inventory.zig");
pub const story = @import("story.zig");
pub const status = @import("status.zig");

pub const Request = union(enum) {
    block,
    dialog: zon.dialog.Event,
    load: u8,
    save: u8,
    title,
};

const Popup = enum {
    about,
    inventory,
    pause,
    sale,
    save,
    shop,
    status,
};

var popup: ?Popup = null;

pub fn init() void {
    about.init();
    dialog.init();
    item.init();
    status.init();
}

pub fn reset() void {
    popup = null;
    story.reset();
    tip.reset();
}

pub fn openPause() void {
    popup = .pause;
}

pub fn openWeaponShop() void {
    shop.open(.weapon);
    popup = .shop;
}

pub fn openPotionShop() void {
    shop.open(.potion);
    popup = .shop;
}

pub fn openSale() void {
    sale.open();
    popup = .sale;
}

pub fn update(world: *ecs.World, delta: f32) ?Request {
    if (story.isOpen()) {
        const request = story.update(delta) orelse return .block;
        return switch (request) {
            .close => .block,
            .title => .title,
        };
    }

    tip.update(world, delta);
    if (world.has(world.entity, Dialog)) tip.reset();
    if (dialog.update(world)) |event| {
        return .{ .dialog = event };
    }
    if (world.has(world.entity, Dialog)) return .block;

    const current = popup orelse return null;
    switch (current) {
        .pause => {
            const req = pause.update() orelse return .block;
            switch (req) {
                .status => popup = .status,
                .item => {
                    inventory.open();
                    popup = .inventory;
                },
                .load => {
                    save.open(.load);
                    popup = .save;
                },
                .save => {
                    save.open(.save);
                    popup = .save;
                },
                .about => popup = .about,
                .exit => zhu.window.exit(),
                .close => popup = null,
            }
        },
        .about => if (about.update(delta)) {
            popup = .pause;
        },
        .save => {
            const req = save.update() orelse return .block;
            switch (req) {
                .close => popup = .pause,
                .load => |index| {
                    popup = .pause;
                    return .{ .load = index };
                },
                .save => |index| {
                    popup = .pause;
                    return .{ .save = index };
                },
            }
        },
        .status => if (status.update()) {
            popup = .pause;
        },
        .inventory => if (inventory.update(world)) |req| {
            switch (req) {
                .close => popup = .pause,
                .used => {},
            }
        },
        .sale => if (sale.update(world)) {
            popup = null;
        },
        .shop => if (shop.update(world)) {
            popup = null;
        },
    }
    return .block;
}

pub fn draw(world: *ecs.World) void {
    dialog.draw(world);
    if (!world.has(world.entity, Dialog)) tip.draw();
    if (popup) |current| switch (current) {
        .about => about.draw(),
        .pause => pause.draw(),
        .save => save.draw(),
        .status => status.draw(world),
        .inventory => inventory.draw(world),
        .sale => sale.draw(world),
        .shop => shop.draw(world),
    };
    story.draw();
}
