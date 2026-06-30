const std = @import("std");
const zhu = @import("zhu");

pub const Input = @import("state/Input.zig");

pub const Session = struct {
    input: Input = .{},
};
