const zhu = @import("zhu");

const Animation = zhu.Animation;

const Npc = struct {
    images: [15]zhu.graphics.ImageId,
    size: zhu.Vector2,
    frames: [4]Animation.Frames,
};

const Config = struct {
    player: []const Animation.Source,
    bomb: []const Animation.Source,
    npc: Npc,
};

// 实体和运行对象的创建配置。
const zon: Config = @import("zon/factory.zon");

// 所有 NPC 共用相同的素材布局。
const npcSources: [15][4]Animation.Source = blk: {
    var sources: [15][4]Animation.Source = undefined;
    for (zon.npc.images, 0..) |imageId, imageIndex| {
        for (zon.npc.frames, 0..) |frames, sourceIndex| {
            sources[imageIndex][sourceIndex] = .{
                .imageId = imageId,
                .size = zon.npc.size,
                .frames = frames,
            };
        }
    }
    break :blk sources;
};

// 创建角色动画。
pub fn playerAnimation() Animation {
    return .initSource(zon.player);
}

// 创建爆炸动画。
pub fn bombAnimation() Animation {
    return .initSource(zon.bomb);
}

// 创建指定素材的 NPC 动画。
pub fn npcAnimation(picture: u8) Animation {
    return .initSource(&npcSources[picture]);
}
