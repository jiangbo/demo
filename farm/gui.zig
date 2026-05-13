const sk = @import("sokol");
const zhu = @import("zhu");

const imgui = @import("cimgui");

const context = @import("context.zig");
const events = @import("event.zig");

pub fn init() void {
    sk.imgui.setup(.{
        .logger = .{ .func = sk.log.func },
        .no_default_font = true,
        .ini_filename = "assets/imgui.ini",
    });

    const io = imgui.igGetIO();
    const font = io.*.Fonts;
    const range = imgui.ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon(font);
    const debugFont = imgui.ImFontAtlas_AddFontFromFileTTF(
        font,
        "assets/fonts/VonwaonBitmap-16px.ttf",
        16,
        null,
        range,
    );
    if (debugFont == null) @panic("failed to load debug font");

    imgui.igStyleColorsDark(null);
    const style = imgui.igGetStyle();
    style.*.Colors[imgui.ImGuiCol_WindowBg].w = 0.85;
}

pub fn event(ev: *const zhu.window.Event) void {
    _ = sk.imgui.handleEvent(ev.*);
}

pub fn update(delta: f32) void {
    sk.imgui.newFrame(.{
        .width = sk.app.width(),
        .height = sk.app.height(),
        .delta_time = delta,
    });

    if (zhu.input.key.pressed(.F5)) {
        context.showEngineDebug = !context.showEngineDebug;
    }
    if (zhu.input.key.pressed(.F6)) {
        context.showGameDebug = !context.showGameDebug;
    }

    if (context.showEngineDebug) drawEnginePanel();
    if (context.showGameDebug) drawGamePanel();

    const io = imgui.igGetIO();
    context.uiWantCaptureMouse = io.*.WantCaptureMouse;
    context.uiWantCaptureKeyboard = io.*.WantCaptureKeyboard;
}

pub fn draw() void {
    sk.imgui.render();
}

pub fn deinit() void {
    sk.imgui.shutdown();
}

fn drawEnginePanel() void {
    if (!imgui.igBegin(
        "Engine Debug",
        &context.showEngineDebug,
        imgui.ImGuiWindowFlags_AlwaysAutoResize,
    )) {
        imgui.igEnd();
        return;
    }

    const mouse = zhu.input.mousePosition;
    _ = imgui.igText("Current scene: %s", sceneName(context.currentScene).ptr);
    _ = imgui.igText("Pending scene: %s", pendingSceneName().ptr);
    _ = imgui.igText("Paused: %s", boolText(context.paused).ptr);
    _ = imgui.igText("Time scale: %.2f", context.timeScale);
    _ = imgui.igSeparator();
    _ = imgui.igText("Mouse: %.1f, %.1f", mouse.x, mouse.y);
    _ = imgui.igText(
        "Capture mouse: %s",
        boolText(context.uiWantCaptureMouse).ptr,
    );
    _ = imgui.igText(
        "Capture keyboard: %s",
        boolText(context.uiWantCaptureKeyboard).ptr,
    );
    imgui.igSeparator();
    drawEventControls();
    drawEventTrace();

    imgui.igEnd();
}

fn drawGamePanel() void {
    if (!imgui.igBegin(
        "Game Debug",
        &context.showGameDebug,
        imgui.ImGuiWindowFlags_AlwaysAutoResize,
    )) {
        imgui.igEnd();
        return;
    }

    _ = imgui.igText("Game debug enabled: %s", "true");
    _ = imgui.igText("Gameplay data is not available yet.");
    _ = imgui.igText("This panel will grow with later farm systems.");

    imgui.igEnd();
}

fn pendingSceneName() [:0]const u8 {
    if (context.pendingScene) |scene| return sceneName(scene);
    return "none";
}

fn sceneName(scene: context.Scene) [:0]const u8 {
    return switch (scene) {
        .title => "title",
        .farm => "farm",
    };
}

fn boolText(value: bool) [:0]const u8 {
    return if (value) "true" else "false";
}

fn drawEventControls() void {
    if (imgui.igButton("Queue farm scene")) {
        events.enqueue(.{ .scene_request = .farm });
    }
    imgui.igSameLine();
    if (imgui.igButton("Trigger title scene")) {
        events.trigger(.{ .scene_request = .title });
    }
    if (imgui.igButton("Queue debug note")) {
        events.enqueue(.{ .debug_note = "debug note from panel" });
    }
    imgui.igSameLine();
    if (imgui.igButton("Clear trace")) {
        events.clearTrace();
    }
}

fn drawEventTrace() void {
    const items = events.recentTrace();
    _ = imgui.igText("Recent events: %d", @as(i32, @intCast(items.len)));

    for (items) |entry| {
        _ = imgui.igText(
            "%s  %s",
            events.modeName(entry.mode).ptr,
            events.eventName(entry.event).ptr,
        );
    }
}
