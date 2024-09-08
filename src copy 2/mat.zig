pub fn mul(a: [12]f32, b: [12]f32) [12]f32 {
    const a00 = a[0 * 4 + 0];
    const a01 = a[0 * 4 + 1];
    const a02 = a[0 * 4 + 2];
    const a10 = a[1 * 4 + 0];
    const a11 = a[1 * 4 + 1];
    const a12 = a[1 * 4 + 2];
    const a20 = a[2 * 4 + 0];
    const a21 = a[2 * 4 + 1];
    const a22 = a[2 * 4 + 2];
    const b00 = b[0 * 4 + 0];
    const b01 = b[0 * 4 + 1];
    const b02 = b[0 * 4 + 2];
    const b10 = b[1 * 4 + 0];
    const b11 = b[1 * 4 + 1];
    const b12 = b[1 * 4 + 2];
    const b20 = b[2 * 4 + 0];
    const b21 = b[2 * 4 + 1];
    const b22 = b[2 * 4 + 2];

    return .{
        b00 * a00 + b01 * a10 + b02 * a20,
        b00 * a01 + b01 * a11 + b02 * a21,
        b00 * a02 + b01 * a12 + b02 * a22,
        0,
        b10 * a00 + b11 * a10 + b12 * a20,
        b10 * a01 + b11 * a11 + b12 * a21,
        b10 * a02 + b11 * a12 + b12 * a22,
        0,
        b20 * a00 + b21 * a10 + b22 * a20,
        b20 * a01 + b21 * a11 + b22 * a21,
        b20 * a02 + b21 * a12 + b22 * a22,
        0,
    };
}

pub fn offset(x: f32, y: f32) [12]f32 {
    return .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        x, y, 1, 0,
    };
}

pub fn rotate(angle: f32) [12]f32 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        c,  s, 0, 0,
        -s, c, 0, 0,
        0,  0, 1, 0,
    };
}

pub fn scale(x: f32, y: f32) [12]f32 {
    return .{
        x, 0, 0, 0,
        0, y, 0, 0,
        0, 0, 1, 0,
    };
}
