const zhu = @import("zhu");

const atlas: zhu.Atlas = @import("zon/atlas.zon");

pub fn init() void {
    zhu.assets.loadAtlas(atlas);
}
