const component = @import("../component.zig");

pub const Period = component.time.Period;

paused: bool = false,
day: u32 = 1,
hour: u8 = 6,
minute: f32 = 0.0,
period: Period = .dawn,
restHours: ?u8 = null,

pub fn reset(self: *@This()) void {
    self.paused = false;
    self.day = 1;
    self.hour = 6;
    self.minute = 0.0;
    self.period = .dawn;
    self.restHours = null;
}

pub fn isDark(self: *const @This()) bool {
    return self.hour >= 18 or self.hour < 6;
}

pub fn takeRestHours(self: *@This()) ?u8 {
    const result = self.restHours;
    self.restHours = null;
    return result;
}
