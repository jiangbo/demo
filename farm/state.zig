const std = @import("std");
const zhu = @import("zhu");

pub const Input = @import("state/Input.zig");
pub const Clock = @import("state/Clock.zig");
pub const Notice = @import("state/Notice.zig");
pub const Maps = @import("state/Maps.zig");

// 底层的input是全局的，有抽象泄漏，所以模块变量
pub var input: Input = .{};

pub const Session = struct {
    clock: Clock = .{},
    notice: Notice = .{},
    maps: Maps = .{},
};
