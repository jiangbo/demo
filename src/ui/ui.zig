const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const zon = @import("../zon.zig");
const about = @import("about.zig");
const dialog = @import("dialog.zig");
const inventory = @import("inventory.zig");
const item = @import("item.zig");
const pause = @import("pause.zig");
const sale = @import("sale.zig");
const save = @import("save.zig");
const shop = @import("shop.zig");
const status = @import("status.zig");
const story = @import("story.zig");
const tip = @import("tip.zig");

const Dialog = component.dialog.Dialog;

pub const Request = union(enum) {
    block,
    battle,
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

pub fn update(world: *ecs.World, delta: f32) ?Request {
    if (story.isOpen()) {
        const request = story.update(delta) orelse return .block;
        return switch (request) {
            .close => .block,
            .title => .title,
        };
    }

    tip.update(world, delta);
    if (updateDialog(world)) |request| return request;
    if (world.has(world.entity, Dialog)) return .block;

    if (popup == null) {
        const openKey = zon.input.anyReleased(&.{ .menu, .cancel });
        if (openKey or zhu.mouse.released(.RIGHT)) {
            openPause();
            return .block;
        }
        return null;
    }

    return updatePopup(world, delta);
}

fn updateDialog(world: *ecs.World) ?Request {
    const event = dialog.update(world) orelse return null;
    switch (event) {
        .finish => {},
        .openWeaponShop => {
            shop.open(.weapon);
            popup = .shop;
        },
        .openPotionShop => {
            shop.open(.potion);
            popup = .shop;
        },
        .openSale => {
            sale.open();
            popup = .sale;
        },
        .battle => return .battle,
        .showSwordTip => story.open(.sword),
        .showEnding => story.open(.ending),
    }
    return .block;
}

fn updatePopup(world: *ecs.World, delta: f32) Request {
    switch (popup.?) {
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
    zhu.camera.push(.window);
    defer zhu.camera.pop();

    dialog.draw(world);
    if (popup) |current| switch (current) {
        .about => about.draw(),
        .pause => pause.draw(),
        .save => save.draw(),
        .status => status.draw(world),
        .inventory => inventory.draw(world),
        .sale => sale.draw(world),
        .shop => shop.draw(world),
    };
    tip.draw();
    story.draw();
}
