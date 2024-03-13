const std = @import("std");
const map = @import("map.zig");
const file = @import("file.zig");
const ray = @import("raylib.zig");

pub const PopupType = enum { loading, menu, clear, quit, title, select, reset };

pub const Popup = union(PopupType) {
    loading: Loading,
    menu: Menu,
    clear: Clear,
    quit: void,
    title: void,
    select: void,
    reset: void,

    pub fn update(self: *Popup) ?PopupType {
        return switch (self.*) {
            .title, .reset, .select, .quit => unreachable,
            inline else => |*case| case.update(),
        };
    }

    pub fn draw(self: Popup) void {
        switch (self) {
            .title, .select, .reset, .quit => unreachable,
            inline else => |sequence| sequence.draw(),
        }
    }

    pub fn deinit(self: Popup) void {
        switch (self) {
            .loading => |sequence| sequence.deinit(),
            else => {},
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

    fn update(self: Loading) ?PopupType {
        return if ((ray.GetTime() - self.time) > 1) return .quit else null;
    }

    fn draw(self: Loading) void {
        ray.DrawTexture(self.texture.texture, 0, 0, ray.WHITE);
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

    fn update(_: Menu) ?PopupType {
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
        ray.DrawTexture(self.texture.texture, 0, 0, ray.WHITE);
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

    fn update(self: Clear) ?PopupType {
        return if ((ray.GetTime() - self.time) > 1) return .title else null;
    }

    fn draw(self: Clear) void {
        ray.DrawTexture(self.texture.texture, 0, 0, ray.WHITE);
    }

    fn deinit(self: Clear) void {
        self.texture.unload();
    }
};
