const std = @import("std");
const zhu = @import("zhu");

pub const Clock = @import("state/Clock.zig");
pub const Notice = @import("state/Notice.zig");
pub const Maps = @import("state/Maps.zig");

pub const Session = struct {
    clock: Clock = .{},
    notice: Notice = .{},
    maps: Maps = .{},
};
