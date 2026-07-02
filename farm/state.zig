const std = @import("std");
const zhu = @import("zhu");

pub const Input = @import("state/Input.zig");
pub const Clock = @import("state/Clock.zig");
pub const Notice = @import("state/Notice.zig");

pub var input: Input = .{};

pub const Session = struct {
    clock: Clock = .{},
    notice: Notice = .{},
};
