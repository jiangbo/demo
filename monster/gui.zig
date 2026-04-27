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
        _ = gui.igText("生命值: %d / %d", stats.health, stats.maxHealth);
        _ = gui.igText("攻击力: %d", stats.attack);
        _ = gui.igText("防御力: %d", stats.defense);

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
            _ = gui.igText("名称: %s", name.value.ptr);
        }

        if (reg.tryGet(entity, com.ClassName)) |className| {
            _ = gui.igText("职业: %s", className.value.ptr);
        }

        _ = gui.igSeparator();
        _ = gui.igText("等级: %.0f", stats.level);
        gui.igSameLine();
        _ = gui.igText("稀有度: %.0f", stats.rarity);
        _ = gui.igText("生命值: %d / %d", stats.health, stats.maxHealth);
        _ = gui.igText("攻击力: %d", stats.attack);
        _ = gui.igText("防御力: %d", stats.defense);

        if (reg.tryGet(entity, com.attack.Range)) |r| {
            _ = gui.igText("射程: %.0f", r.v);
        }

        if (reg.tryGet(entity, com.attack.CoolDown)) |c| {
            _ = gui.igText("攻击间隔: %.2f s", c.v);
        }

        if (reg.tryGet(entity, com.motion.Blocker)) |blocker| {
            _ = gui.igText("阻挡数量: %d / %d", blocker.current, blocker.max);
        }

        if (gui.igButton("取消选中")) {
            ctx.selectedEntity = null;
        }
    }
    gui.igEnd();
}

pub fn draw() void {
    sk.imgui.render();
}

pub fn deinit() void {
    sk.imgui.shutdown();
}
