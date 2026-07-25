const zon = @import("zon.zig");

// 当前战斗及其返回世界所需的数据。
pub const Battle = struct {
    pub const Result = enum { fighting, win, escape };

    // 战斗人物和进入战斗前的地图入口。
    actor: zon.Actor.Key,
    portalKey: zon.Portal.Key,
    // 战斗场景在返回世界前写入结果。
    result: Result = .fighting,
};

pub var battle: Battle = undefined;
