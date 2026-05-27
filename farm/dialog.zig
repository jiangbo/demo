const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

const Dialog = component.actor.Dialog;

// 对话脚本数据：scriptId → 台词数组
const scripts = [_]struct {
    id: []const u8,
    lines: []const []const u8,
}{
    .{
        .id = "cow",
        .lines = &.{
            "哞~",
            "今天天气不错呢。",
            "你要给我喂草吗？",
        },
    },
    .{
        .id = "sheep",
        .lines = &.{
            "咩~",
            "我的毛又长长了。",
            "离我远点，我在吃草。",
        },
    },
};

// 对话气泡当前显示的文本
pub var text: []const u8 = "";
var lines: []const []const u8 = &.{};
var lineIndex: usize = 0;

// 根据 scriptId 查找对话脚本
fn findScript(id: []const u8) ?[]const []const u8 {
    for (&scripts) |entry| {
        if (std.mem.eql(u8, entry.id, id)) return entry.lines;
    }
    return null;
}

// 处理 ECS 事件队列中的对话事件
pub fn update(world: *zhu.ecs.World) void {
    // 处理开始对话事件
    const starts = world.getEvent(component.event.DialogStart);
    for (starts.items) |event| {
        const found = findScript(event.scriptId) orelse continue;
        if (found.len == 0) continue;
        lines = found;
        lineIndex = 0;
        text = lines[0]; // 显示第一句台词
        world.addIdentity(event.entity, Dialog); // 标记为当前对话实体
    }
    world.clearEvent(component.event.DialogStart);

    // 处理推进对话事件
    const advances = world.getEvent(component.event.DialogAdvance);
    for (advances.items) |event| {
        const active = world.getIdentity(Dialog) orelse continue;
        if (active != event.entity or lines.len == 0) continue;

        lineIndex += 1;
        if (lineIndex >= lines.len) {
            doClose(world, event.entity);
        } else {
            text = lines[lineIndex];
        }
    }
    world.clearEvent(component.event.DialogAdvance);

    // 处理关闭对话事件
    const closes = world.getEvent(component.event.DialogClose);
    for (closes.items) |event| {
        doClose(world, event.entity);
    }
    world.clearEvent(component.event.DialogClose);
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
const maxWidth: f32 = 200.0;
const lineHeight: f32 = 8.0;

// 绘制对话气泡（在窗口坐标系下调用）
pub fn draw(world: *zhu.ecs.World) void {
    const entity = world.getIdentity(Dialog) orelse return;
    if (text.len == 0) return;

    const pos = world.get(entity, component.Position) //
        orelse return;

    // NPC 头顶位置转屏幕坐标
    const headWorld = pos.addY(-headOffset);
    const screen = zhu.camera.toWindow(headWorld);

    // 计算文本宽度来确定气泡大小
    const textWidth = zhu.text.computeTextWidth(text, .{});
    const actualWidth = @min(textWidth, maxWidth);
    const linesCount: u32 = @intFromFloat(@max(
        @ceil(textWidth / maxWidth),
        1,
    ));
    const bubbleHeight = padding * 2 + //
        @as(f32, @floatFromInt(linesCount)) * lineHeight;

    // 气泡背景
    const bubbleRect = zhu.Rect.init(
        .xy(screen.x - actualWidth / 2 - padding, screen.y - bubbleHeight),
        .xy(actualWidth + padding * 2, bubbleHeight),
    );
    zhu.batch.drawRect(bubbleRect, .{
        .color = .rgba(0, 0, 0, 0.75),
    });

    // 气泡文字
    const textPos = bubbleRect.min.add(.xy(padding, padding));
    zhu.text.drawString(text, textPos, .{
        .color = .white,
        .maxWidth = textPos.x + actualWidth,
    });
}

test "DialogStart 事件会激活第一句台词" {
    resetState();
    defer resetState();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const npc = world.createEntity();
    world.add(npc, Dialog{ .scriptId = "cow" });
    world.addEvent(component.event.DialogStart{
        .entity = npc,
        .scriptId = "cow",
    });

    update(&world);

    try std.testing.expectEqual(npc, world.getIdentity(Dialog).?);
    try std.testing.expectEqualStrings("哞~", text);
    try std.testing.expectEqual(
        0,
        world.getEvent(component.event.DialogStart).items.len,
    );
}

test "DialogAdvance 事件会推进并在末尾关闭" {
    resetState();
    defer resetState();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const npc = world.createEntity();
    world.add(npc, Dialog{ .scriptId = "cow" });
    world.addEvent(component.event.DialogStart{
        .entity = npc,
        .scriptId = "cow",
    });
    update(&world);

    world.addEvent(component.event.DialogAdvance{ .entity = npc });
    update(&world);
    try std.testing.expectEqualStrings("今天天气不错呢。", text);

    world.addEvent(component.event.DialogAdvance{ .entity = npc });
    update(&world);
    try std.testing.expectEqualStrings("你要给我喂草吗？", text);

    world.addEvent(component.event.DialogAdvance{ .entity = npc });
    update(&world);
    try std.testing.expectEqual(null, world.getIdentity(Dialog));
    try std.testing.expectEqualStrings("", text);
}

test "DialogClose 事件只关闭当前对话实体" {
    resetState();
    defer resetState();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const active = world.createEntity();
    const other = world.createEntity();
    world.add(active, Dialog{ .scriptId = "cow" });
    world.add(other, Dialog{ .scriptId = "sheep" });
    world.addEvent(component.event.DialogStart{
        .entity = active,
        .scriptId = "cow",
    });
    update(&world);

    world.addEvent(component.event.DialogClose{ .entity = other });
    update(&world);
    try std.testing.expectEqual(active, world.getIdentity(Dialog).?);
    try std.testing.expectEqualStrings("哞~", text);

    world.addEvent(component.event.DialogClose{ .entity = active });
    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Dialog));
}
