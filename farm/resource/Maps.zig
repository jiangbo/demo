const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Id = component.map.Id;

pub const ProductState = struct {
    product: component.item.Product,
    health: component.item.Health,
};

pub const Thing = union(enum) {
    gone,
    crop: component.farm.Crop,
    chest: component.item.Chest,
    product: ProductState,
};

pub const Tile = struct {
    ground: ?component.farm.Ground = null,
    thing: ?Thing = null,
};

pub const Entry = struct {
    day: u32 = 1,
    tiles: []Tile = &.{},
};

items: std.EnumArray(Id, Entry) = .initFill(.{}),

pub fn ensure(self: *@This(), id: Id, tileCount: usize, day: u32) *Entry {
    const entry = self.items.getPtr(id);
    if (entry.tiles.len != 0) return entry;

    entry.tiles = zhu.assets.oomAlloc(Tile, tileCount);
    @memset(entry.tiles, .{});
    entry.day = day;
    return entry;
}

pub fn reset(self: *@This()) void {
    for (std.enums.values(Id)) |id| {
        const entry = self.items.getPtr(id);
        if (entry.tiles.len != 0) @memset(entry.tiles, .{});
        entry.day = 1;
    }
}

pub fn deinit(self: *@This()) void {
    for (std.enums.values(Id)) |id| {
        zhu.assets.free(self.items.getPtr(id).tiles);
    }
}
