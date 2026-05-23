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
        context.debug.showEngine = !context.debug.showEngine;
    }
    if (zhu.input.key.pressed(.F6)) {
        context.debug.showGame = !context.debug.showGame;
    }

    if (context.debug.showEngine) drawEnginePanel();
    if (context.debug.showGame) drawGamePanel();

    const io = imgui.igGetIO();
    context.ui.wantCaptureMouse = io.*.WantCaptureMouse;
    context.ui.wantCaptureKeyboard = io.*.WantCaptureKeyboard;
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
        &context.debug.showEngine,
        imgui.ImGuiWindowFlags_AlwaysAutoResize,
    )) {
        imgui.igEnd();
        return;
    }

    const mouse = zhu.input.mousePosition;
    _ = imgui.igText("Current scene: %s", sceneName(context.scene.current).ptr);
    _ = imgui.igText("Pending scene: %s", pendingSceneName().ptr);
    _ = imgui.igText("Paused: %s", boolText(context.time.paused).ptr);
    _ = imgui.igText("Time scale: %.2f", context.time.scale);
    _ = imgui.igSeparator();
    _ = imgui.igText("Mouse: %.1f, %.1f", mouse.x, mouse.y);
    _ = imgui.igText(
        "Capture mouse: %s",
        boolText(context.ui.wantCaptureMouse).ptr,
    );
    _ = imgui.igText(
        "Capture keyboard: %s",
        boolText(context.ui.wantCaptureKeyboard).ptr,
    );
    _ = imgui.igText(
        "Camera: %.1f, %.1f  scale: %.2f",
        zhu.camera.position.x,
        zhu.camera.position.y,
        zhu.camera.scale.x,
    );
    imgui.igSeparator();
    drawBatchStats();
    imgui.igSeparator();
    drawEventControls();
    drawEventTrace();

    imgui.igEnd();
}

fn drawGamePanel() void {
    if (!imgui.igBegin(
        "Game Debug",
        &context.debug.showGame,
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
    if (context.scene.pending) |next| return sceneName(next);
    return "none";
}

fn sceneName(value: context.scene.Scene) [:0]const u8 {
    return switch (value) {
        .title => "title",
        .farm => "farm",
    };
}

fn boolText(value: bool) [:0]const u8 {
    return if (value) "true" else "false";
}

fn drawBatchStats() void {
    const gpuStats = zhu.graphics.queryFrameStats();
    const batchStats = zhu.batch.lastStats;
    const ratio = if (batchStats.commands == 0)
        0
    else
        batchStats.sprites / batchStats.commands;

    _ = imgui.igText("Batch Stats");
    // _ = imgui.igCheckbox("Pixel Snap", &zhu.batch.pixelSnap);
    _ = imgui.igText("GPU draw calls: %d", @as(i32, @intCast(gpuStats.num_draw)));
    _ = imgui.igText("Batch sprites: %d", @as(i32, @intCast(batchStats.sprites)));
    _ = imgui.igText("Batch commands: %d", @as(i32, @intCast(batchStats.commands)));
    _ = imgui.igText("Sprites / command: %d", @as(i32, @intCast(ratio)));
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
