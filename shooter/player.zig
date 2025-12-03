const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const SPEED = 200; // 玩家的移动速度

var position: gfx.Vector = undefined; // 玩家的位置
var texture: gfx.Texture = undefined; // 玩家的纹理
var size: gfx.Vector = undefined; // 玩家的尺寸

pub fn init() void {
    texture = gfx.loadTexture("assets/image/SpaceShip.png", .init(241, 187));
    // 图片太大了，缩小到四分之一
    size = texture.size().scale(0.25);
    position = window.logicSize.sub(size).div(.init(2, 1));
}

pub fn update(delta: f32) void {
    // 玩家键盘控制
    const distance = SPEED * delta; // 根据时间调整移动距离
    if (window.isKeyDown(.A)) position.x -= distance;
    if (window.isKeyDown(.D)) position.x += distance;
    if (window.isKeyDown(.W)) position.y -= distance;
    if (window.isKeyDown(.S)) position.y += distance;

    // 限制玩家的移动边界
    position = position.clamp(.zero, window.logicSize.sub(size));
}

pub fn draw() void {
    // 绘制玩家
    camera.drawOption(texture, position, .{ .size = size });
}
