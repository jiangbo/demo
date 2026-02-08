const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    var view = reg.view(.{com.Animation});
    defer reg.clear(com.AnimationPlay);

    while (view.next()) |ent| {
        const animation = view.getPtr(ent, com.Animation);

        // 处理可能的动画播放请求
        if (view.tryGet(ent, com.AnimationPlay)) |play| {
            animation.play(play.index, play.loop);
        }

        if (!animation.isNextUpdate(delta)) continue; // 动画未跳到下一帧

        // 更新显示的图片
        const sprite = view.getPtr(ent, com.Sprite);
        sprite.image = animation.subImage(sprite.image.size);

        if (animation.isRunning()) {
            // 检查是否有动画事件需要触发
            const action = animation.getEnumFrameExtend(com.ActionEnum);
            if (action != .none) view.add(ent, action);
        } else {
            view.add(ent, com.AnimationFinished{}); // 动画播放结束
        }
    }
}
