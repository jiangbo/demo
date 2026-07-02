const std = @import("std");
const zhu = @import("zhu");

pub const Clock = @import("resource/Clock.zig");
pub const Notice = @import("resource/Notice.zig");
pub const Maps = @import("resource/Maps.zig");

pub const Session = struct {
    clock: Clock = .{},
    notice: Notice = .{},
    maps: Maps = .{},
};
