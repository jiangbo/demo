const std = @import("std");
const map = @import("map.zig");
const file = @import("file.zig");
const ray = @import("raylib.zig");

pub const MenuType = enum { quit, title, select, reset, next };
pub const PopupType = enum { loading, menu, clear };

pub const Popup = union(PopupType) {
    loading: Loading,
    menu: Menu,
    clear: Clear,

    pub fn update(self: *Popup) ?MenuType {
        return switch (self.*) {
            inline else => |*case| case.update(),
        };
    }

    pub fn draw(self: Popup) void {
        switch (self) {
            inline else => |sequence| sequence.draw(),
        }
    }

    pub fn deinit(self: Popup) void {
        switch (self) {
            inline else => |sequence| sequence.deinit(),
        }
    }
};

pub const Loading = struct {
    texture: file.Texture,
    time: f64,

    pub fn init() Loading {
        return Loading{
            .texture = file.loadTexture("loading.dds"),
            .time = ray.GetTime(),
        };
    }

    fn update(self: Loading) ?MenuType {
        return if ((ray.GetTime() - self.time) > 1) return .quit else null;
    }

    fn draw(self: Loading) void {
        self.texture.draw();
    }

    fn deinit(self: Loading) void {
        self.texture.unload();
    }
};

pub const Menu = struct {
    texture: file.Texture,

    pub fn init() Menu {
        return Menu{ .texture = file.loadTexture("menu.dds") };
    }

    fn update(_: Menu) ?MenuType {
        const char = ray.GetCharPressed();
        return switch (char) {
            '1' => .reset,
            '2' => .select,
            '3' => .title,
            '4' => .quit,
            else => null,
        };
    }

    fn draw(self: Menu) void {
        self.texture.draw();
    }

    fn deinit(self: Menu) void {
        self.texture.unload();
    }
};

pub const Clear = struct {
    texture: file.Texture,
    time: f64,

    pub fn init() Clear {
        return Clear{
            .texture = file.loadTexture("clear.dds"),
            .time = ray.GetTime(),
        };
    }

    fn update(self: Clear) ?MenuType {
        return if ((ray.GetTime() - self.time) > 1) return .next else null;
    }

    fn draw(self: Clear) void {
        self.texture.draw();
    }

    fn deinit(self: Clear) void {
        self.texture.unload();
    }
};
