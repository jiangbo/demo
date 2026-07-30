const std = @import("std");
const zhu = @import("zhu");

const Animation = zhu.Animation;
const tiled = zhu.extend.tiled;

const NpcAnimation = struct {
    images: [15]zhu.graphics.ImageId,
    size: zhu.Vector2,
    frames: [4]Animation.Frames,
};

const Config = struct {
    player: []const Animation.Source,
    bomb: []const Animation.Source,
    npc: NpcAnimation,
    input: []const zhu.input.Bind,
};

pub const Facing = enum { down, left, up, right };

// 可持有、使用或交易的物品配置。
pub const Item = struct {
    key: []const u8,
    name: []const u8,
    icon: u8, // goods.png 中的图片格子
    about: []const u8 = &.{},
    money: u32 = 0,
    exp: i32 = 0,
    health: i32 = 0,
    attack: i32 = 0,
    defend: i32 = 0,

    pub const list: []const Item = @import("zon/item.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    // 根据稳定标识取得物品配置。
    pub fn get(key: Key) *const Item {
        return &list[@intFromEnum(key)];
    }
};

pub const Chest = struct {
    id: u16,
    item: ?Item.Key = null,

    pub const Place = struct {
        id: u16,
        tileIndex: u16,
    };

    pub const list: []const ?Chest = @import("zon/chest.zon");

    // 根据稳定 ID 取得宝箱配置。
    pub fn get(id: u16) *const Chest {
        return &list[id].?;
    }
};

pub const Actor = struct {
    const Animations = std.EnumArray(Key, []const Animation.Source);

    // 所有 NPC 共用相同的素材布局。
    const npcSources: [15][4]Animation.Source = blk: {
        var sources: [15][4]Animation.Source = undefined;
        for (config.npc.images, 0..) |imageId, imageIndex| {
            for (config.npc.frames, 0..) |frames, sourceIndex| {
                sources[imageIndex][sourceIndex] = .{
                    .imageId = imageId,
                    .size = config.npc.size,
                    .frames = frames,
                };
            }
        }
        break :blk sources;
    };

    // 编译期生成每个角色对应的动画配置。
    const animations: Animations = blk: {
        var result = Animations.initUndefined();
        result.set(.player, config.player);
        for (list[1..], 1..) |actor, index| {
            const key: Key = @enumFromInt(index);
            result.set(key, &npcSources[actor.picture]);
        }
        break :blk result;
    };

    key: []const u8,
    enemy: bool = false,
    dialogues: ?[2]u16 = null,
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: Facing = .down,
    level: u16 = 1,
    health: u16 = 0,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    panicSpeed: ?f32 = null, // 慌乱时的移动速度
    goods: []const Item.Key = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50,

    pub const list: []const Actor = @import("zon/actor.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    pub fn get(key: Key) *const Actor {
        return &list[@intFromEnum(key)];
    }

    // 根据角色标识创建对应的地图动画。
    pub fn animation(key: Key) Animation {
        return .initSource(animations.get(key));
    }

    // 取得角色指定方向的第一帧图片。
    pub fn image(key: Key, facing: Facing) zhu.Image {
        const source = animations.get(key)[@intFromEnum(facing)];
        const atlas = zhu.assets.getImage(source.imageId).?;
        return atlas.sub(.init(source.frames[0].offset, source.size));
    }

    // 根据剧情进度取得角色当前使用的对话。
    pub fn talk(self: Actor, progress: u8) []const dialog.Line {
        const ids = self.dialogues.?;
        const index: usize = if (progress > 4) 1 else 0;
        return dialogues[ids[index]].lines;
    }

    // 根据剧情进度取得角色当前的移动速度。
    pub fn moveSpeed(self: Actor, progress: u8) f32 {
        if (progress > 4) return self.panicSpeed orelse self.speed;
        return self.speed;
    }
};

pub const dialog = struct {
    pub const Event = union(enum) {
        finish,
        openWeaponShop,
        openPotionShop,
        openSale,
        battle: Actor.Key,
        unlock: u8,
        showSwordTip,
        showEnding,
    };

    pub const Line = struct {
        actor: ?Actor.Key,
        content: []const u8 = &.{},
        event: ?Event = null,
    };

    // 一段完整的对话脚本。
    pub const Script = struct {
        id: u16,
        lines: []const Line,
    };
};

pub const dialogues: []const dialog.Script = @import("zon/talk.zon");
pub const config: Config = @import("zon/config.zon");
pub const input = zhu.input.bind(config.input);

pub const Map = struct {
    key: []const u8,
    grid: tiled.Grid,
    back: []const u16,
    ground: []const u16,
    object: []const u8,
    chests: []const Chest.Place = &.{},
    actors: []const Actor.Key = &.{},

    pub const list: []const Map = @import("zon/map.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    // 根据稳定标识取得地图配置。
    pub fn get(key: Key) *const Map {
        return &list[@intFromEnum(key)];
    }

    // 根据地图图层分配并构建绘制顶点。
    pub fn buildVertices(
        self: Map,
        allocator: zhu.Allocator,
        image: zhu.Image,
    ) []zhu.batch.Vertex {
        var count: usize = 0;
        for ([_][]const u16{ self.back, self.ground }) |tiles| {
            for (tiles) |tile| {
                if (tile != 0) count += 1;
            }
        }
        const result = allocator.alloc(zhu.batch.Vertex, count);
        const atlasGrid = tiled.Grid{
            .width = @intFromFloat(@divExact(image.size.x, 34)),
            .height = @intFromFloat(@divExact(image.size.y, 34)),
            .cell = 34,
        };
        const tileSize = self.grid.cellSize();
        var next: usize = 0;

        for ([_][]const u16{ self.back, self.ground }) |tiles| {
            for (tiles, 0..) |tile, index| {
                if (tile == 0) continue;

                const pos = atlasGrid.indexToWorld(tile).add(.one);
                const tileImage = image.sub(.init(pos, tileSize));
                result[next] = .{
                    .position = self.grid.indexToWorld(index),
                    .layer = tileImage.layer,
                    .size = tileSize,
                    .uvRect = tileImage.uvRect(),
                };
                next += 1;
            }
        }
        return result;
    }
};

pub const Portal = struct {
    pub const Gate = struct {
        // 当前进度必须大于该值才能通过。
        progress: u8,
        // 尚未达到开放条件时显示的对话。
        blockedDialogue: u16,
        // 正好达到条件时触发的剧情对话。
        reachedDialogue: ?u16 = null,
    };

    key: Key,
    target: Key,
    map: Map.Key,
    facing: Facing,
    gate: ?Gate = null,

    const source = @import("zon/portal.zon");
    pub const Key = zhu.enums.fromField(source, "key");
    pub const list: []const Portal = @import("zon/portal.zon");

    pub fn get(value: Key) *const Portal {
        return &list[@intFromEnum(value)];
    }
};

comptime {
    for (dialogues, 0..) |dialogue, id| {
        std.debug.assert(dialogue.id == id);
    }
    for (Chest.list, 0..) |chest, id| {
        if (chest) |value| std.debug.assert(value.id == id);
    }
    for (Portal.list) |portal| {
        if (portal.gate) |gate| {
            std.debug.assert(gate.blockedDialogue < dialogues.len);
            if (gate.reachedDialogue) |id| {
                std.debug.assert(id < dialogues.len);
            }
        }
    }
}

test "通过 key 查找角色配置" {
    try std.testing.expectEqualStrings("小飞刀", Actor.get(.player).name);
    try std.testing.expectEqualStrings(
        "小春春",
        Actor.get(.xiaoChunChun).name,
    );
    try std.testing.expectEqualStrings("公  主", Actor.get(.gongZhu).name);
}
