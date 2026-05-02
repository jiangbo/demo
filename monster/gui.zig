const std = @import("std");
const sk = @import("sokol");
const zhu = @import("zhu");

const gui = @import("cimgui");

const com = @import("component.zig");
const ctx = @import("context.zig");
const spawn = @import("spawn.zig");
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

var flag: bool = true;
pub fn update(reg: *Registry, delta: f32) void {
    sk.imgui.newFrame(.{
        .width = sk.app.width(),
        .height = sk.app.height(),
        .delta_time = delta,
        .dpi_scale = sk.app.dpiScale(),
    });

    // gui.igShowDemoWindow(&flag);

    if (gui.igBegin("怪物战争", &flag, gui.ImGuiWindowFlags_None)) {
        _ = gui.igText("ImGui 版本：%s", gui.IMGUI_VERSION);
    }
    gui.igEnd();

    renderHoveredUnit(reg);
    renderSelectedUnit(reg);

    const io = gui.igGetIO();
    ctx.uiWantCaptureMouse = io.*.WantCaptureMouse;
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
    if (ready and clicked) {
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

    if (clicked and ctx.cost >= upgradeCost) {
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

    if (gui.igButton("撤退")) {
        ctx.cost += refund;
        reg.add(entity, com.Dead{});
        ctx.selectedEntity = null;
    }
    gui.igSameLine();
    _ = gui.igText("返还 %.0f COST", refund);
}

pub fn draw() void {
    renderLevelInfo();
    renderSettings();
    renderDebugTools();
    sk.imgui.render();
}

fn renderLevelInfo() void {
    gui.igSetNextWindowPos(.{ .x = 10, .y = 250 }, gui.ImGuiCond_Always);
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

fn renderSettings() void {
    gui.igSetNextWindowPos(.{ .x = 10, .y = 400 }, gui.ImGuiCond_Always);
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("设置", null, flags)) {
        if (gui.igButton("暂停/继续")) {
            ctx.paused = !ctx.paused;
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
    gui.igSetNextWindowPos(.{ .x = 10, .y = 600 }, gui.ImGuiCond_Always);
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

pub fn deinit() void {
    sk.imgui.shutdown();
}
