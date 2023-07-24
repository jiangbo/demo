// 0x00E0 => memory.clearScreen(),
// 0x00EE => self.pc = memory.pop(),
// 0x1000...0x1FFF => self.pc = ins.nnn,
// 0x2000...0x2FFF => {
//     memory.push(self.pc);
//     self.pc = ins.nnn;
// },
// 0x3000...0x3FFF => if (reg[ins.x] == ins.kk) self.next(),
// 0x4000...0x4FFF => if (reg[ins.x] != ins.kk) self.next(),
// 0x5000...0x5FFF => if (reg[ins.x] == reg[ins.y]) self.next(),
// 0x6000...0x6FFF => self.register[ins.x] = ins.kk,
// 0x7000...0x7FFF => self.register[ins.x] +%= ins.kk,
// 0xA000...0xAFFF => self.index = self.instruct.nnn,
// 0xD000...0xDFFF => self.draw(memory),
