pub const Instruct = struct {
    opcode: u16,
    code: u4 = undefined,
    nnn: u16 = undefined,
    kk: u8 = undefined,
    x: u8 = undefined,
    y: u8 = undefined,
    n: u8 = undefined,

    pub fn decode(self: *Instruct) void {
        self.code = @truncate((self.opcode & 0xF000) >> 12);
        self.nnn = self.opcode & 0x0FFF;
        self.kk = @truncate(self.opcode & 0x00FF);
        self.x = @truncate((self.opcode & 0x0F00) >> 8);
        self.y = @truncate((self.opcode & 0x00F0) >> 4);
        self.n = @truncate(self.opcode & 0x000F);
    }
};
