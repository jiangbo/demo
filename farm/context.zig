const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

pub const map = struct {
    pub const Id = component.map.Id;
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

    pub const State = struct {
        initialized: bool = false,
        day: u32 = 1,
        tiles: []Tile = &.{},
    };

    pub var states: std.EnumArray(Id, State) = .initFill(.{});

    pub fn ensureState(id: Id, tileCount: usize, day: u32) *State {
        const result = states.getPtr(id);
        if (result.initialized) return result;

        if (result.tiles.len == 0) {
            result.tiles = zhu.assets.oomAlloc(Tile, tileCount);
        }
        @memset(result.tiles, .{});
        result.initialized = true;
        result.day = day;
        return result;
    }

    pub fn resetStates() void {
        for (std.enums.values(Id)) |id| {
            states.getPtr(id).initialized = false;
        }
    }
};

pub fn init() void {}

pub fn deinit() void {
    for (std.enums.values(map.Id)) |id| {
        zhu.assets.free(map.states.getPtr(id).tiles);
    }
}
