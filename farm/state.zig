const std = @import("std");
const zhu = @import("zhu");

pub const Notice = @import("resource/Notice.zig");
pub const Maps = @import("resource/Maps.zig");

pub const Session = struct {
    notice: Notice = .{},
    maps: Maps = .{},
};
