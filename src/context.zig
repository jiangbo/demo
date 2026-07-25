const factory = @import("factory.zig");

// 当前战斗及其返回世界所需的数据。
pub const Battle = struct {
    pub const Result = enum { fighting, win, escape };

    // 战斗人物和进入战斗前的地图。
    actor: factory.Key,
    mapIndex: u8,
    // 战斗场景在返回世界前写入结果。
    result: Result = .fighting,
};

pub var battle: Battle = undefined;
