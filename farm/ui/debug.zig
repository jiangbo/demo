const sk = @import("sokol");
const zhu = @import("zhu");

const imgui = @import("cimgui");

const component = @import("../component.zig");
const context = @import("../context.zig");
const map = @import("../map.zig");

const World = zhu.ecs.World;
const Actor = component.actor.Actor;
const Collider = component.motion.Collider;
const Player = component.actor.Player;
const Position = component.Position;
const Target = component.ui.Target;
const Velocity = component.motion.Velocity;

pub fn init() void {
    sk.imgui.setup(.{
        .logger = .{ .func = sk.log.func },
        .no_default_font = true,
        .ini_filename = "assets/imgui.ini",
        .disable_set_mouse_cursor = true,
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

pub fn update(world: *World, delta: f32) void {
    sk.imgui.newFrame(.{
        .width = sk.app.width(),
        .height = sk.app.height(),
        .delta_time = delta,
    });

    if (zhu.key.pressed(.F6)) {
        context.debug.showGame = !context.debug.showGame;
    }

    if (context.debug.showGame) drawGamePanel(world);

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

fn drawGamePanel(world: *World) void {
    if (!imgui.igBegin(
        "Game Debug",
        &context.debug.showGame,
        imgui.ImGuiWindowFlags_AlwaysAutoResize,
    )) {
        imgui.igEnd();
        return;
    }

    drawGameControls();
    imgui.igSeparator();
    drawPlayerPanel(world);
    imgui.igSeparator();
    drawMapPanel(world);
    imgui.igSeparator();
    drawTimePanel();
    imgui.igSeparator();
    drawEntityCounts(world);

    imgui.igEnd();
}

fn boolText(value: bool) [:0]const u8 {
    return if (value) "true" else "false";
}

fn drawGameControls() void {
    if (imgui.igButton("Reset time")) {
        context.time.reset();
    }
    imgui.igSameLine();
    if (context.time.paused) {
        if (imgui.igButton("Resume time")) context.time.paused = false;
    } else {
        if (imgui.igButton("Pause time")) context.time.paused = true;
    }
    imgui.igSameLine();
    if (imgui.igButton("Normal speed")) context.time.scale = 1;
}

fn drawPlayerPanel(world: *World) void {
    if (!imgui.igCollapsingHeader(
        "Player",
        imgui.ImGuiTreeNodeFlags_DefaultOpen,
    )) return;

    const player = world.getIdentity(Player) orelse {
        _ = imgui.igText("Player: missing");
        return;
    };

    _ = imgui.igText("Entity: %u", player);
    if (world.get(player, Position)) |position| {
        _ = imgui.igText("Position: %.1f, %.1f", position.x, position.y);
        const tile = map.data.worldToTilePosition(position);
        _ = imgui.igText("Tile: %d, %d", tile.x, tile.y);
    } else {
        _ = imgui.igText("Position: missing");
    }

    if (world.get(player, Velocity)) |velocity| {
        _ = imgui.igText(
            "Velocity: %.2f, %.2f",
            velocity.value.x,
            velocity.value.y,
        );
    }

    if (world.get(player, Actor)) |actor| {
        _ = imgui.igText(
            "Facing/action: %s / %s",
            actorFacingName(actor.facing).ptr,
            actorActionName(actor.action).ptr,
        );
    }

    if (world.get(player, Collider)) |collider| {
        _ = imgui.igText(
            "Collider: %.1fx%.1f offset %.1f, %.1f",
            collider.size.x,
            collider.size.y,
            collider.offset.x,
            collider.offset.y,
        );
    }

    if (world.get(player, Target)) |target| {
        _ = imgui.igText("Target active: %s", boolText(target.active).ptr);
        _ = imgui.igText(
            "Target pos: %.1f, %.1f",
            target.position.x,
            target.position.y,
        );
    }
}

fn drawMapPanel(world: *World) void {
    if (!imgui.igCollapsingHeader(
        "Map",
        imgui.ImGuiTreeNodeFlags_DefaultOpen,
    )) return;

    const loaded = map.land.tiles.len > 0;
    _ = imgui.igText("Current: %s", @tagName(map.current).ptr);
    _ = imgui.igText("Loaded: %s", boolText(loaded).ptr);
    _ = imgui.igText("Map size: %u x %u", map.data.width, map.data.height);
    _ = imgui.igText(
        "World size: %.0f x %.0f",
        map.data.size().x,
        map.data.size().y,
    );

    const spatialStats = countSpatialTiles();
    _ = imgui.igText("Collision tiles: %zu", spatialStats.blocked);
    _ = imgui.igText("Directional tiles: %zu", spatialStats.directional);
    _ = imgui.igText("Collision rects: %zu", map.spatial.areas.items.len);

    const landStats = countLandTiles();
    _ = imgui.igText("Tilled dry: %zu", landStats.dry);
    _ = imgui.igText("Tilled wet: %zu", landStats.wet);
    _ = imgui.igText("Crops on land: %zu", landStats.crops);

    _ = imgui.igText("Map triggers: %zu", world.raw(component.map.Trigger).len);
}

fn drawTimePanel() void {
    if (!imgui.igCollapsingHeader(
        "Time",
        imgui.ImGuiTreeNodeFlags_DefaultOpen,
    )) return;

    _ = imgui.igText("Day: %u", context.time.day);
    _ = imgui.igText(
        "Clock: %02u:%02u",
        context.time.hour,
        @as(u8, @intFromFloat(context.time.minute)),
    );
    _ = imgui.igText("Minute raw: %.2f", context.time.minute);
    _ = imgui.igText("Period: %s", periodName(context.time.period).ptr);
    _ = imgui.igText("Paused: %s", boolText(context.time.paused).ptr);
    _ = imgui.igText("Scale: %.2fx", context.time.scale);
    _ = imgui.igText("Dark: %s", boolText(context.time.isDark()).ptr);
}

fn drawEntityCounts(world: *World) void {
    if (!imgui.igCollapsingHeader(
        "Entity Counts",
        imgui.ImGuiTreeNodeFlags_DefaultOpen,
    )) return;

    _ = imgui.igText("Positions: %zu", world.count(Position));
    _ = imgui.igText("Sprites: %zu", world.count(component.render.Sprite));
    _ = imgui.igText("Render comps: %zu", world.count(component.render.Render));
    _ = imgui.igText("Animals: %zu", world.count(component.actor.Animal));
    _ = imgui.igText("NPCs: %zu", world.count(component.actor.Npc));
    _ = imgui.igText("Crops: %zu", world.count(component.farm.Crop));
    _ = imgui.igText("Pickups: %zu", world.count(component.item.Pickup));
    _ = imgui.igText("Point lights: %zu", world.count(component.light.Point));
    _ = imgui.igText("Spot lights: %zu", world.count(component.light.Spot));
}

const SpatialStats = struct {
    blocked: usize = 0,
    directional: usize = 0,
};

fn countSpatialTiles() SpatialStats {
    var result = SpatialStats{};
    for (map.spatial.tiles) |marks| {
        if (!map.spatial.hasAnyBlock(marks)) continue;
        result.blocked += 1;
        if (!map.spatial.isSolid(marks)) result.directional += 1;
    }
    return result;
}

const LandStats = struct {
    dry: usize = 0,
    wet: usize = 0,
    crops: usize = 0,
};

fn countLandTiles() LandStats {
    var result = LandStats{};
    for (map.land.tiles) |tile| {
        if (tile.ground) |ground| switch (ground) {
            .dry => result.dry += 1,
            .wet => result.wet += 1,
        };
        if (tile.crop() != null) result.crops += 1;
    }
    return result;
}

fn actorFacingName(value: component.actor.Facing) [:0]const u8 {
    return switch (value) {
        .down => "down",
        .up => "up",
        .left => "left",
        .right => "right",
    };
}

fn actorActionName(value: component.actor.Action) [:0]const u8 {
    return switch (value) {
        .idle => "idle",
        .walk => "walk",
        .hoe => "hoe",
        .watering => "watering",
        .planting => "planting",
        .sickle => "sickle",
        .axe => "axe",
        .pickaxe => "pickaxe",
    };
}

fn periodName(value: context.time.Period) [:0]const u8 {
    return switch (value) {
        .dawn => "dawn",
        .day => "day",
        .dusk => "dusk",
        .night => "night",
    };
}
