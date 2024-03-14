const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

pub const MenuType = enum { quit, title, select, reset, next };
pub const PopupType = enum { loading, menu, clear, over };

pub const Popup = union(PopupType) {
    loading: Loading,
    menu: Menu,
    clear: TimePopup,
    over: TimePopup,

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

pub fn init() Popup {
    return .{ .loading = Loading.init() };
}

pub fn initWithType(popupType: PopupType) Popup {
    return switch (popupType) {
        .clear => .{ .clear = TimePopup.init("clear.png", .next) },
        .menu => .{ .menu = Menu.init() },
        .loading => .{ .loading = Loading.init() },
        .over => .{ .over = TimePopup.init("over.png", .title) },
    };
}

const TimePopup = struct {
    texture: engine.Texture,
    time: usize,
    target: MenuType,

    fn init(name: []const u8, target: MenuType) TimePopup {
        return TimePopup{
            .texture = engine.Texture.init(name),
            .time = engine.time(),
            .target = target,
        };
    }

    fn update(self: TimePopup) ?MenuType {
        return if (engine.time() - self.time > 2000) self.target else null;
    }

    fn draw(self: TimePopup) void {
        self.texture.draw();
    }

    fn deinit(self: TimePopup) void {
        self.texture.deinit();
    }
};

const Loading = struct {
    texture: engine.Texture,
    time: usize,

    fn init() Loading {
        return Loading{
            .texture = engine.Texture.init("loading.dds"),
            .time = engine.time(),
        };
    }

    fn update(self: Loading) ?MenuType {
        return if (engine.time() - self.time > 1000) return .quit else null;
    }

    fn draw(self: Loading) void {
        self.texture.draw();
    }

    fn deinit(self: Loading) void {
        self.texture.deinit();
    }
};

const Menu = struct {
    texture: engine.Texture,

    fn init() Menu {
        return Menu{ .texture = engine.Texture.init("menu.dds") };
    }

    fn update(_: Menu) ?MenuType {
        const char = engine.getPressed();
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
        self.texture.deinit();
    }
};
