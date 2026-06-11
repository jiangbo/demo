const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Dialog = component.actor.Dialog;
const DialogAdvance = component.actor.DialogAdvance;
const DialogClose = component.actor.DialogClose;
const DialogStart = component.actor.DialogStart;
const Position = component.Position;

// 对话气泡当前显示的文本
pub var text: []const u8 = "";
var lines: []const []const u8 = &.{};
var lineIndex: usize = 0;

// 处理 talk 系统写入的对话请求 identity。
pub fn update(world: *zhu.ecs.World) void {
    // 处理开始对话事件
    if (world.takeIdentity(DialogStart)) |entity| {
        const dialog = world.get(entity, Dialog).?;
        if (dialog.lines.len != 0) {
            lines = dialog.lines;
            lineIndex = 0;
            text = lines[0]; // 显示第一句台词
            world.addIdentity(entity, Dialog); // 标记为当前对话实体
        }
    }

    // 处理推进对话事件
    if (world.takeIdentity(DialogAdvance)) |entity| {
        if (world.getIdentity(Dialog)) |active| {
            if (active == entity and lines.len != 0) {
                lineIndex += 1;
                if (lineIndex >= lines.len) {
                    doClose(world, entity);
                } else {
                    text = lines[lineIndex];
                }
            }
        }
    }

    // 处理关闭对话事件
    if (world.takeIdentity(DialogClose)) |entity| doClose(world, entity);
}

// 关闭对话并重置状态
fn doClose(world: *zhu.ecs.World, entity: zhu.ecs.Entity) void {
    if (world.getIdentity(Dialog)) |active| {
        if (active != entity) return;
    }

    resetState();
    _ = world.removeIdentity(Dialog); // 清除对话 Identity 标记
}

fn resetState() void {
    text = "";
    lines = &.{};
    lineIndex = 0;
}

// 气泡绘制参数
const padding: f32 = 4.0;
const headOffset: f32 = 30.0;
const max: f32 = 200.0;

// 绘制对话气泡（在窗口坐标系下调用）
pub fn draw(world: *zhu.ecs.World) void {
    const entity = world.getIdentity(Dialog) orelse return;
    if (text.len == 0) return;

    const pos = world.get(entity, Position) orelse return;
    const head = zhu.camera.toWindow(pos.addY(-headOffset));

    const option = zhu.text.Option{ .color = .white, .max = max };
    const textSize = zhu.text.measure(text, option);

    // 气泡背景
    const bubbleSize = textSize.add(.xy(padding * 2, padding * 2));
    const bubblePos = head.addXY(-bubbleSize.x / 2, -bubbleSize.y);
    const bubbleRect: zhu.Rect = .init(bubblePos, bubbleSize);
    zhu.batch.drawRect(bubbleRect, .{ .color = .rgba(0, 0, 0, 0.75) });

    // 气泡文字
    const textPos = bubbleRect.min.add(.xy(padding, padding));
    zhu.text.drawString(text, textPos, option);
}

test "DialogStart identity 会激活第一句台词" {
    resetState();
    defer resetState();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const npc = world.createEntity();
    world.add(npc, Dialog{ .lines = &.{
        "哞~",
        "今天天气不错呢。",
    } });
    world.addIdentity(npc, DialogStart);

    update(&world);

    try std.testing.expectEqual(npc, world.getIdentity(Dialog).?);
    try std.testing.expectEqualStrings("哞~", text);
    try std.testing.expectEqual(null, world.getIdentity(DialogStart));
}

test "DialogAdvance identity 会推进并在末尾关闭" {
    resetState();
    defer resetState();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const npc = world.createEntity();
    world.add(npc, Dialog{ .lines = &.{
        "哞~",
        "今天天气不错呢。",
        "你要给我喂草吗？",
    } });
    world.addIdentity(npc, DialogStart);
    update(&world);

    world.addIdentity(npc, DialogAdvance);
    update(&world);
    try std.testing.expectEqualStrings("今天天气不错呢。", text);

    world.addIdentity(npc, DialogAdvance);
    update(&world);
    try std.testing.expectEqualStrings("你要给我喂草吗？", text);

    world.addIdentity(npc, DialogAdvance);
    update(&world);
    try std.testing.expectEqual(null, world.getIdentity(Dialog));
    try std.testing.expectEqualStrings("", text);
}

test "DialogClose identity 只关闭当前对话实体" {
    resetState();
    defer resetState();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const active = world.createEntity();
    const other = world.createEntity();
    world.add(active, Dialog{ .lines = &.{"哞~"} });
    world.add(other, Dialog{ .lines = &.{"咩~"} });
    world.addIdentity(active, DialogStart);
    update(&world);

    world.addIdentity(other, DialogClose);
    update(&world);
    try std.testing.expectEqual(active, world.getIdentity(Dialog).?);
    try std.testing.expectEqualStrings("哞~", text);

    world.addIdentity(active, DialogClose);
    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Dialog));
}
