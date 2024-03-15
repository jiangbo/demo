pub const Vector = struct {
    x: usize = 0,
    y: usize = 0,
};

pub const Rectangle = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize = 0,
    height: usize = 0,

    pub fn init(x: usize, y: usize, width: usize, height: usize) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }
};
