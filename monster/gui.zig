const std = @import("std");
const sk = @import("sokol");
const zhu = @import("zhu");

const gui = @import("cimgui");

const com = @import("component.zig");
const ctx = @import("context.zig");
const spawn = @import("spawn.zig");
const scene = @import("scene.zig");
const Registry = zhu.ecs.Registry;

pub fn init() void {
    sk.imgui.setup(.{
        .logger = .{ .func = sk.log.func },
        .no_default_font = true,
        .ini_filename = "assets/imgui.ini",
    });

    const io = gui.igGetIO();
    const font = io.*.Fonts;
    const range = gui.ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon(font);
    const chineseFont = gui.ImFontAtlas_AddFontFromFileTTF(font, //
        "assets/VonwaonBitmap-16px.ttf", 16, null, range);

    if (chineseFont == null) @panic("failed to load font");
}

pub fn event(ev: *const zhu.window.Event) void {
    _ = sk.imgui.handleEvent(ev.*);
}

pub fn update(reg: *Registry, delta: f32) void {
    sk.imgui.newFrame(.{
        .width = sk.app.width(),
        .height = sk.app.height(),
        .delta_time = delta,
        .dpi_scale = sk.app.dpiScale(),
    });

    switch (ctx.currentScene) {
        .title => renderTitleButtons(),
        .battle => {
            if (zhu.input.key.pressed(.P)) ctx.paused = !ctx.paused;

            renderHoveredUnit(reg);
            renderSelectedUnit(reg);
        },
        .clear, .end => {},
    }

    const io = gui.igGetIO();
    ctx.uiWantCaptureMouse = io.*.WantCaptureMouse;
}

var showUnitInfo: bool = false;
var showLoadPanel: bool = false;
var showSavePanel: bool = false;

fn renderTitleButtons() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("标题按钮", null, flags)) {
        gui.igSetWindowFontScale(2.0);
        if (gui.igButton("开始游戏")) {
            ctx.pendingScene = .battle;
        }
        gui.igSameLine();
        if (gui.igButton("确认角色")) {
            showUnitInfo = !showUnitInfo;
        }
        gui.igSameLine();
        if (gui.igButton("载入游戏")) {
            showLoadPanel = !showLoadPanel;
        }
        gui.igSameLine();
        if (gui.igButton("退出游戏")) {
            zhu.window.exit();
        }
        gui.igSetWindowFontScale(1.0);
    }
    gui.igEnd();

    if (showUnitInfo) renderUnitInfo();
    if (showLoadPanel) renderLoadPanel();
}

fn renderHoveredUnit(reg: *Registry) void {
    const entity = ctx.hoveredEntity orelse return;
    const stats = reg.tryGet(entity, com.Stats) orelse return;

    if (gui.igBeginTooltip()) {
        if (reg.tryGet(entity, com.Name)) |name| {
            _ = gui.igText("%s  ", name.value.ptr);
            gui.igSameLine();
        }

        if (reg.tryGet(entity, com.ClassName)) |className| {
            _ = gui.igText("%s", className.value.ptr);
        }

        _ = gui.igText("等级: %.0f", stats.level);
        gui.igSameLine();
        _ = gui.igText("稀有度: %.0f", stats.rarity);
        _ = gui.igText("生命值: %.0f / %.0f", stats.health, stats.maxHealth);
        _ = gui.igText("攻击力: %.0f", stats.attack);
        _ = gui.igText("防御力: %.0f", stats.defense);
        _ = gui.igText("攻击范围: %d", @as(i32, @intFromFloat(stats.range)));
        _ = gui.igText("攻击间隔: %.2f", stats.interval);

        gui.igEndTooltip();
    }
}

fn renderSelectedUnit(reg: *Registry) void {
    const entity = ctx.selectedEntity orelse return;
    const stats = reg.tryGet(entity, com.Stats) orelse return;

    gui.igSetNextWindowPos(.{ .x = 10, .y = 10 }, gui.ImGuiCond_Always);
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("角色状态", null, flags)) {
        if (reg.tryGet(entity, com.Name)) |name| {
            _ = gui.igText("%s  ", name.value.ptr);
            gui.igSameLine();
        }

        if (reg.tryGet(entity, com.ClassName)) |className| {
            _ = gui.igText("%s", className.value.ptr);
        }

        _ = gui.igText("等级: %.0f", stats.level);
        gui.igSameLine();
        _ = gui.igText("稀有度: %.0f", stats.rarity);
        _ = gui.igText("生命值: %.0f / %.0f", stats.health, stats.maxHealth);
        _ = gui.igText("攻击力: %.0f", stats.attack);
        gui.igSameLine();
        _ = gui.igText("防御力: %.0f", stats.defense);
        _ = gui.igText("攻击范围: %.0f", stats.range);
        gui.igSameLine();
        _ = gui.igText("攻击间隔: %.2f", stats.interval);

        if (reg.tryGet(entity, com.motion.Blocker)) |blocker| {
            _ = gui.igText("阻挡数量: %d / %d", blocker.current, blocker.max);
        }

        renderSelectedSkill(reg, entity);
        renderSelectedUpgrade(reg, entity);
        renderSelectedLeave(reg, entity);
    }
    gui.igEnd();
}

fn renderSelectedSkill(reg: *Registry, entity: zhu.ecs.Entity) void {
    const value = reg.tryGet(entity, com.skill.Skill) orelse return;
    const ready = reg.has(entity, com.skill.Ready);
    const active = reg.has(entity, com.skill.Active);
    const passive = value.passive or reg.has(entity, com.skill.Passive);

    gui.igBeginDisabled(!ready);
    const clicked = gui.igButton(value.name.ptr);
    gui.igEndDisabled();
    if (ready and (clicked or zhu.input.key.pressed(.S))) {
        reg.add(entity, com.skill.Cast{});
    }
    gui.igSameLine();

    if (active) {
        if (passive) {
            _ = gui.igText("被动技能激活中");
        } else if (reg.tryGet(entity, com.skill.Timer)) |timer| {
            const remaining = @max(0, value.duration - timer.elapsed);
            _ = gui.igText("激活中，剩余时间: %.1f 秒", remaining);
        }
    } else if (passive) {
        _ = gui.igText("被动技能");
    } else {
        if (ready) {
            _ = gui.igText("技能准备就绪");
        } else if (reg.tryGet(entity, com.skill.Timer)) |timer| {
            gui.igProgressBar(timer.progress(), .{ .x = 120, .y = 0 }, null);
        }
    }

    _ = gui.igTextWrapped("%s", value.description.ptr);
}

fn renderSelectedUpgrade(reg: *Registry, entity: zhu.ecs.Entity) void {
    if (!reg.has(entity, com.Player)) return;

    const playerEnum = reg.get(entity, com.PlayerEnum);
    const upgradeCost = spawn.playerZon[@intFromEnum(playerEnum)].cost;

    gui.igBeginDisabled(ctx.cost < upgradeCost);
    const clicked = gui.igButton("升级");
    gui.igEndDisabled();
    gui.igSameLine();
    _ = gui.igText("消耗 %.0f COST", upgradeCost);

    if (ctx.cost >= upgradeCost and (clicked or zhu.input.key.pressed(.U))) {
        ctx.cost -= upgradeCost;
        spawn.upgradeUnit(reg, entity);
    }
}

fn renderSelectedLeave(reg: *Registry, entity: zhu.ecs.Entity) void {
    if (!reg.has(entity, com.Player)) return;

    const playerEnum = reg.get(entity, com.PlayerEnum);
    const stats = reg.get(entity, com.Stats);
    const cost = spawn.playerZon[@intFromEnum(playerEnum)].cost;
    const refund = spawn.statModify(cost, stats.level, stats.rarity) * 0.5;

    if (gui.igButton("撤退") or zhu.input.key.pressed(.R)) {
        ctx.cost += refund;
        reg.add(entity, com.Dead{});
        ctx.selectedEntity = null;
    }
    gui.igSameLine();
    _ = gui.igText("返还 %.0f COST", refund);
}

fn renderUnitInfo() void {
    if (!gui.igBegin("角色信息", &showUnitInfo, gui.ImGuiWindowFlags_None)) {
        gui.igEnd();
        return;
    }
    const col = 7;
    if (gui.igBeginTable("角色表格", col, gui.ImGuiTableFlags_None)) {
        gui.igTableSetupColumn("姓名", 0);
        gui.igTableSetupColumn("职业", 0);
        gui.igTableSetupColumn("等级", 0);
        gui.igTableSetupColumn("稀有度", 0);
        gui.igTableSetupColumn("生命", 0);
        gui.igTableSetupColumn("攻击", 0);
        gui.igTableSetupColumn("升级", 0);
        gui.igTableHeadersRow();

        for (ctx.units.items) |*unit| {
            const template = &spawn.playerZon[@intFromEnum(unit.class)];
            const hp = spawn.statModify(template.stats.maxHealth, unit.level, unit.rarity);
            const atk = spawn.statModify(template.stats.attack, unit.level, unit.rarity);
            const upgradeCost: u32 = @intFromFloat(@round(spawn.statModify(template.cost, 1, unit.rarity)));

            gui.igTableNextRow();
            _ = gui.igTableNextColumn();
            _ = gui.igText("%s", unit.name.ptr);
            _ = gui.igTableNextColumn();
            _ = gui.igText("%s", template.name.ptr);
            _ = gui.igTableNextColumn();
            _ = gui.igText("%.0f", unit.level);
            _ = gui.igTableNextColumn();
            _ = gui.igText("%.0f", unit.rarity);
            _ = gui.igTableNextColumn();
            _ = gui.igText("%.0f", hp);
            _ = gui.igTableNextColumn();
            _ = gui.igText("%.0f", atk);
            _ = gui.igTableNextColumn();

            gui.igPushID(unit.name);
            const canUpgrade = ctx.point >= upgradeCost;
            gui.igBeginDisabled(!canUpgrade);
            var btnText: [32]u8 = undefined;
            const btnLabel = std.fmt.bufPrintZ(&btnText, "- {}", .{upgradeCost}) catch unreachable;
            const clicked = gui.igButton(btnLabel);
            gui.igEndDisabled();
            if (canUpgrade and clicked) {
                ctx.point -= upgradeCost;
                unit.level += 1;
                unit.cost = @round(spawn.statModify(template.cost, unit.level, unit.rarity));
            }
            gui.igPopID();
        }
        gui.igEndTable();
    }
    _ = gui.igText("剩余积分: %d", ctx.point);
    gui.igEnd();
}

const slots = [_][:0]const u8{
    "assets/save/SLOT_1.json",
    "assets/save/SLOT_2.json",
    "assets/save/SLOT_3.json",
};

fn renderLoadPanel() void {
    if (!gui.igBegin("读档", &showLoadPanel, gui.ImGuiWindowFlags_None)) {
        gui.igEnd();
        return;
    }
    for (slots, 0..) |slot, i| {
        var lbl: [16]u8 = undefined;
        const text = std.fmt.bufPrintZ(&lbl, "SLOT {}", .{i + 1}) catch unreachable;
        if (gui.igButton(text)) {
            ctx.loadGame(slot) catch continue;
        }
        gui.igSameLine();
    }
    if (ctx.levelClear) {
        _ = gui.igText("下一关: %d", ctx.levelIndex + 1);
    } else {
        _ = gui.igText("当前关卡: %d", ctx.levelIndex);
    }
    gui.igEnd();
}

fn renderSavePanel() void {
    if (!gui.igBegin("存档", &showSavePanel, gui.ImGuiWindowFlags_None)) {
        gui.igEnd();
        return;
    }
    for (slots, 0..) |slot, i| {
        var lbl: [16]u8 = undefined;
        const text = std.fmt.bufPrintZ(&lbl, "SLOT {}", .{i + 1}) catch unreachable;
        if (gui.igButton(text)) {
            ctx.saveGame(slot) catch continue;
        }
        gui.igSameLine();
    }
    if (ctx.levelClear) {
        _ = gui.igText("下一关: %d", ctx.levelIndex + 1);
    } else {
        _ = gui.igText("当前关卡: %d", ctx.levelIndex);
    }
    gui.igEnd();
}

pub fn draw(reg: *Registry) void {
    switch (ctx.currentScene) {
        .title => renderTitleUI(),
        .battle => renderBattleUI(reg),
        .clear => renderLevelClear(),
        .end => renderEndScene(),
    }
    sk.imgui.render();
}

fn renderTitleUI() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_NoResize |
        gui.ImGuiWindowFlags_NoBackground;
    gui.igSetNextWindowSize(.{ .x = 400, .y = 100 }, gui.ImGuiCond_FirstUseEver);
    if (gui.igBegin("标题", null, flags)) {
        gui.igSetWindowFontScale(2.0);
        gui.igSetCursorPos(.{ .x = 110, .y = 30 });
        _ = gui.igText("怪物战争");
    }
    gui.igEnd();
}

fn renderBattleUI(reg: *Registry) void {
    renderLevelInfo();
    renderSettings(reg);
    renderDebugTools();
    if (showSavePanel) renderSavePanel();
}

fn renderLevelInfo() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("关卡信息", null, flags)) {
        _ = gui.igText("基地血量: %d", ctx.homeHealth);
        _ = gui.igText("COST: %.0f", ctx.cost);
        _ = gui.igText("击杀: %d / %d", ctx.enemyKilledCount, ctx.enemyCount);
        _ = gui.igText("关卡: %d", ctx.levelIndex + 1);
        if (ctx.paused) {
            _ = gui.igText("已暂停");
        }
    }
    gui.igEnd();
}

fn renderSettings(reg: *Registry) void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("设置", null, flags)) {
        if (gui.igButton("暂停/继续")) {
            ctx.paused = !ctx.paused;
        }
        gui.igSameLine();
        if (gui.igButton("返回标题")) {
            ctx.pendingScene = .title;
        }
        gui.igSameLine();
        if (gui.igButton("重新开始")) {
            scene.restart(reg);
        }
        gui.igSameLine();
        if (gui.igButton("保存")) {
            showSavePanel = !showSavePanel;
        }

        gui.igSameLine();
        _ = gui.igText("倍速:");
        gui.igSameLine();
        if (gui.igButton("0.5x")) ctx.timeScale = 0.5;
        gui.igSameLine();
        if (gui.igButton("1x")) ctx.timeScale = 1;
        gui.igSameLine();
        if (gui.igButton("2x")) ctx.timeScale = 2;

        var music: f32 = zhu.audio.musicVolume.load(.acquire);
        if (gui.igSliderFloat("音乐", &music, 0, 1)) {
            zhu.audio.musicVolume.store(music, .release);
        }
        var sound: f32 = zhu.audio.soundVolume.load(.acquire);
        if (gui.igSliderFloat("音效", &sound, 0, 1)) {
            zhu.audio.soundVolume.store(sound, .release);
        }
    }
    gui.igEnd();
}

fn renderDebugTools() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("调试", null, flags)) {
        if (gui.igButton("COST +10")) ctx.cost += 10;
        gui.igSameLine();
        if (gui.igButton("COST +100")) ctx.cost += 100;
        gui.igSameLine();
        if (gui.igButton("通关")) {
            ctx.enemyKilledCount = ctx.enemyCount;
        }
    }
    gui.igEnd();
}

fn renderLevelClear() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("Level Clear", null, flags)) {
        gui.igSetWindowFontScale(2.0);
        _ = gui.igText("通关");
        gui.igSetWindowFontScale(1.0);

        _ = gui.igText("关卡: %d", ctx.levelIndex + 1);
        _ = gui.igText("击杀: %d", ctx.enemyKilledCount);
        _ = gui.igText("基地血量: %d", ctx.homeHealth);
        _ = gui.igText("奖励积分: %d", ctx.reward());
        _ = gui.igText("总积分: %d", ctx.point);

        if (gui.igButton("下一关")) {
            ctx.levelIndex += 1;
            ctx.pendingScene = .battle;
        }
        gui.igSameLine();
        if (gui.igButton("保存")) {
            showSavePanel = !showSavePanel;
        }
        gui.igSameLine();
        if (gui.igButton("返回标题")) {
            ctx.pendingScene = .title;
        }
    }
    gui.igEnd();

    if (showSavePanel) renderSavePanel();
}

fn renderEndScene() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("Game End", null, flags)) {
        gui.igSetWindowFontScale(2.0);
        if (ctx.win) {
            _ = gui.igText("胜利");
        } else {
            _ = gui.igText("失败");
        }
        gui.igSetWindowFontScale(1.0);

        if (gui.igButton("返回标题")) {
            ctx.pendingScene = .title;
        }
        gui.igSameLine();
        if (gui.igButton("退出")) {
            zhu.window.exit();
        }
    }
    gui.igEnd();
}

pub fn deinit() void {
    sk.imgui.shutdown();
}
