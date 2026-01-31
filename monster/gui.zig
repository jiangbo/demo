const std = @import("std");
const sk = @import("sokol");
const zhu = @import("zhu");

const gui = @import("cimgui");

pub fn init() void {
    sk.imgui.setup(.{ .logger = .{ .func = sk.log.func } });

    const io = gui.igGetIO();
    const font = io.*.Fonts;
    const range = gui.ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon(font);
    const chineseFont = gui.ImFontAtlas_AddFontFromFileTTF(font, //
        "assets/VonwaonBitmap-16px.ttf", 16, null, range);

    if (chineseFont == null) @panic("failed to load font");
    io.*.FontDefault = chineseFont;
}

pub fn event(ev: *const zhu.window.Event) void {
    _ = sk.imgui.handleEvent(ev.*);
}

var flag: bool = true;
pub fn update(delta: f32) void {
    sk.imgui.newFrame(.{
        .width = sk.app.width(),
        .height = sk.app.height(),
        .delta_time = delta,
        .dpi_scale = sk.app.dpiScale(),
    });

    gui.igShowDemoWindow(&flag);

    if (gui.igBegin("怪物战争", &flag, gui.ImGuiWindowFlags_None)) {
        _ = gui.igText("ImGui 版本：%s", gui.IMGUI_VERSION);
    }

    gui.igEnd();
}

pub fn draw() void {
    sk.imgui.render();
}

pub fn deinit() void {
    sk.imgui.shutdown();
}
