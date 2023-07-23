const std = @import("std");

pub const CPU = struct {
    // opcode: u16 = undefined,
    index: u16 = 0,
    pc: u16 = 0x200,
    delay: u8 = 0,
    sound: u8 = 0,

    pub fn cycle(self: *CPU) void {
        _ = self;
        std.log.info("cpu cycle", .{});
    }
};
