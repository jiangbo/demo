const std = @import("std");
const zhu = @import("zhu");

pub const Maps = @import("global/Maps.zig");

pub const Session = struct {
    maps: Maps = .{},
};
