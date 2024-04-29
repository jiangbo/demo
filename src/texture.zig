const gl = @import("gl");

pub const Texture2D = struct {
    id: c_uint = 0,
    width: c_int = 0,
    height: c_int = 0,
    wrapS: c_int = gl.REPEAT,
    wrapT: c_int = gl.REPEAT,
    filterMin: c_int = gl.LINEAR,
    filterMax: c_int = gl.LINEAR,

    pub fn generate(self: Texture2D, width: u32, height: u32, data: []const u8) void {
        gl.BindTexture(gl.TEXTURE_2D, self.id);

        const w: c_int = @intCast(width);
        const h: c_int = @intCast(height);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, //
            0, gl.RGBA, gl.UNSIGNED_BYTE, data.ptr);

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, self.wrapS);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, self.wrapT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, self.filterMin);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, self.filterMax);

        // unbind texture
        gl.BindTexture(gl.TEXTURE_2D, 0);
    }

    pub fn bind(self: Texture2D) void {
        gl.BindTexture(gl.TEXTURE_2D, self.id);
    }

    pub fn deinit(self: *Texture2D) void {
        gl.DeleteTextures(1, (&self.id)[0..1]);
    }
};
