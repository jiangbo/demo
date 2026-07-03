const std = @import("std");
const zhu = @import("zhu");

pub const Notice = @import("global/Notice.zig");
pub const Maps = @import("global/Maps.zig");

pub const Session = struct {
    notice: Notice = .{},
    maps: Maps = .{},
};
