const std = @import("std");
const ecs = @import("ecs");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const Registry = ecs.Registry;
pub const Entity = ecs.Entity;

pub const Context = struct {
    allocator: std.mem.Allocator,
    registry: *Registry,

    pub fn init(alloc: std.mem.Allocator, reg: *Registry) Context {
        return Context{ .allocator = alloc, .registry = reg };
    }

    pub fn deinit(self: *Context) void {
        self.registry.deinit();
    }
};

pub fn beginDrawing() void {
    ray.BeginDrawing();
}

pub fn endDrawing() void {
    ray.EndDrawing();
}

pub fn clearBackground() void {
    ray.ClearBackground(ray.WHITE);
}

pub fn createWindow(width: usize, height: usize, title: [:0]const u8) void {
    ray.InitWindow(@intCast(width), @intCast(height), title);
    ray.SetTargetFPS(60);
}

pub fn frameTime() usize {
    return @intFromFloat(ray.GetFrameTime() * 1000);
}

pub fn closeWindow() void {
    ray.CloseWindow();
}

pub fn shouldContinue() bool {
    return !ray.WindowShouldClose();
}

pub fn getScreenSize() Vec {
    return Vec{
        .x = @intCast(ray.GetScreenWidth()),
        .y = @intCast(ray.GetScreenHeight()),
    };
}

pub fn drawFPS(x: usize, y: usize) void {
    ray.DrawFPS(@intCast(x), @intCast(y));
}

pub fn drawText(x: usize, y: usize, text: [:0]const u8, size: usize) void {
    ray.DrawText(text, @intCast(x), @intCast(y), @intCast(size), ray.WHITE);
}

pub fn randomValue(min: usize, max: usize) usize {
    const minc: c_int = @intCast(min);
    const maxc: c_int = @intCast(max);
    return @intCast(ray.GetRandomValue(minc, maxc - 1));
}

pub fn isPressedSpace() bool {
    return ray.IsKeyPressed(ray.KEY_SPACE);
}

pub fn isPressedEnter() bool {
    return ray.IsKeyPressed(ray.KEY_ENTER);
}

pub fn move(vec: *Vec) bool {
    if (ray.IsKeyPressed(ray.KEY_SPACE)) return false;
    if (ray.IsKeyPressed(ray.KEY_A)) vec.x -|= 1;
    if (ray.IsKeyPressed(ray.KEY_S)) vec.y += 1;
    if (ray.IsKeyPressed(ray.KEY_D)) vec.x += 1;
    if (ray.IsKeyPressed(ray.KEY_W)) vec.y -|= 1;
    return true;
}

pub const Vec = struct {
    x: usize = 0,
    y: usize = 0,

    fn toRayVec(self: Vec) ray.Vector2 {
        return ray.Vector2{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
        };
    }

    pub fn scale(self: Vec, value: usize) Vec {
        return Vec{ .x = self.x * value, .y = self.y * value };
    }

    pub fn add(self: Vec, value: Vec) Vec {
        return Vec{ .x = self.x + value.x, .y = self.y + value.y };
    }

    pub fn equal(self: Vec, value: Vec) bool {
        return self.x == value.x and self.y == value.y;
    }
};

pub const Rect = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize = 0,
    height: usize = 0,

    pub fn init(x: usize, y: usize, width: usize, height: usize) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    fn toRayRect(self: Rect) ray.Rectangle {
        return ray.Rectangle{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
            .width = @floatFromInt(self.width),
            .height = @floatFromInt(self.height),
        };
    }

    pub fn intersect(self: Rect, other: Rect) bool {
        return (self.x <= other.x + other.width //
        and self.x + self.width >= other.x //
        and self.y <= other.y + other.height //
        and self.y + self.height >= other.y);
    }

    pub fn center(self: Rect) Vec {
        return Vec{
            .x = (self.x + self.x + self.width) / 2,
            .y = (self.y + self.y + self.height) / 2,
        };
    }
};

pub const Texture = struct {
    texture: ray.Texture2D,

    pub fn init(path: [:0]const u8) Texture {
        return Texture{ .texture = ray.LoadTexture(path) };
    }

    pub fn draw(self: Texture) void {
        self.drawXY(0, 0);
    }

    pub fn drawXY(self: Texture, x: usize, y: usize) void {
        ray.DrawTexture(self.texture, @intCast(x), @intCast(y), ray.WHITE);
    }

    pub fn deinit(self: *Texture) void {
        ray.UnloadTexture(self.texture);
    }
};

pub const SpriteSheet = struct {
    texture: Texture,
    width: usize,
    unit: usize,

    pub fn init(texture: Texture, unit: usize) SpriteSheet {
        const width: usize = @intCast(texture.texture.width);
        return .{ .texture = texture, .unit = unit, .width = width };
    }

    pub fn draw(self: SpriteSheet) void {
        self.texture.draw();
    }

    pub fn drawTile(self: SpriteSheet, index: usize, x: usize, y: usize) void {
        const vec = (Vec{ .x = x, .y = y }).scale(self.unit).toRayVec();
        const rect = self.getRect(index).toRayRect();
        ray.DrawTextureRec(self.texture.texture, rect, vec, ray.WHITE);
    }

    // pub fn drawXY(self: Tilemap, index: usize, x: usize, y: usize) void {
    //     self.texture.drawRec(self.getRec(index), .{ .x = x, .y = y });
    // }

    fn getRect(self: SpriteSheet, index: usize) Rect {
        const rx = index * self.unit % self.width;
        const ry = index / (self.width / self.unit) * self.unit;
        return Rect.init(rx, ry, self.unit, self.unit);
    }

    pub fn deinit(self: SpriteSheet) void {
        self.texture.deinit();
    }
};
