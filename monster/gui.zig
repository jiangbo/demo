const std = @import("std");
const sk = @import("sokol");
const zhu = @import("zhu");

const gui = @import("cimgui");

const com = @import("component.zig");
const ctx = @import("context.zig");

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
pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
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

fn renderHoveredUnit(reg: *zhu.ecs.Registry) void {
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

        if (reg.tryGet(entity, com.attack.Range)) |range| {
            _ = gui.igText("攻击范围: %d", @as(i32, @intFromFloat(range.v)));
        }

        if (reg.tryGet(entity, com.attack.CoolDown)) |c| {
            _ = gui.igText("攻击间隔: %.2f", c.v);
        }

        gui.igEndTooltip();
    }
}

fn renderSelectedUnit(reg: *zhu.ecs.Registry) void {
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

        if (reg.tryGet(entity, com.attack.Range)) |r| {
            _ = gui.igText("攻击范围: %.0f", r.v);
            gui.igSameLine();
        }

        if (reg.tryGet(entity, com.attack.CoolDown)) |c| {
            _ = gui.igText("攻击间隔: %.2f", c.v);
        }

        if (reg.tryGet(entity, com.motion.Blocker)) |blocker| {
            _ = gui.igText("阻挡数量: %d / %d", blocker.current, blocker.max);
        }

        renderSelectedSkill(reg, entity);
    }
    gui.igEnd();
}

fn renderSelectedSkill(reg: *zhu.ecs.Registry, entity: zhu.ecs.Entity) void {
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
        } else {
            const remaining = @max(0, value.duration - value.durationTimer);
            _ = gui.igText("激活中，剩余时间: %.1f 秒", remaining);
        }
    } else if (passive) {
        _ = gui.igText("被动技能");
    } else {
        _ = gui.igText("快捷键 S: ");
        gui.igSameLine();
        if (ready) {
            _ = gui.igText("技能准备就绪");
        } else {
            const progress = if (value.coolDown > 0)
                value.coolDownTimer / value.coolDown
            else
                0;
            gui.igProgressBar(progress, .{ .x = 120, .y = 0 }, null);
        }
    }

    _ = gui.igTextWrapped("%s", value.description.ptr);
}

pub fn draw() void {
    sk.imgui.render();
}

pub fn deinit() void {
    sk.imgui.shutdown();
}
