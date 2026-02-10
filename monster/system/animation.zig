const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    var view = reg.view(.{com.Animation});
    defer reg.clear(com.animation.Play);

    while (view.next()) |entity| {
        const animation = view.getPtr(entity, com.Animation);

        // 处理可能的动画播放请求
        if (view.tryGet(entity, com.animation.Play)) |play| {
            animation.play(play.index, play.loop);
        }

        if (!animation.isNextUpdate(delta)) continue; // 动画未跳到下一帧

        // 更新显示的图片
        const sprite = view.getPtr(entity, com.Sprite);
        sprite.image = animation.subImage(sprite.image.size);

        if (animation.isRunning()) {
            // 检查是否有动画事件需要触发
            const action = animation.getEnumFrameExtend(com.ActionEnum);
            switch (action) {
                .hit => view.add(entity, com.attack.Hit{}),
                .emit => view.add(entity, com.attack.Emit{}),
                .none => {},
            }
        } else {
            view.add(entity, com.animation.Finished{}); // 动画播放结束
        }
    }
}
