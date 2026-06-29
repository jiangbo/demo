const std = @import("std");
const zhu = @import("zhu");

// 把标准 .zon 地图转成运行时 .bin。
//
// 说明：这是独立的产出逻辑，未接入任何构建（按需自行编译运行，例如临时把
//       extend/build.zig 的 root_source_file 指向本文件、并接好 zhu 模块）。
// 输入：一张 .zon（项目的地图标准，游戏编译期原本就 @import 它）。
// 输出：同目录下的 .bin（运行时经 map_loader 读取）。
//
// 为什么从 .zon 而不是 .tmj：.tmj 已偏离标准（命名错误、缺传送点等），
// .zon 才是完整正确的数据来源。

const engine = zhu.extend.tiled;
const map_file = zhu.extend.map_file;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var argIt = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
    defer argIt.deinit();
    _ = argIt.next(); // 跳过程序名
    const name = argIt.next() orelse return error.invalidArgs;
    std.log.info("file name: {s}", .{name});

    const dir = std.Io.Dir.cwd();
    const raw = try dir.readFileAlloc(init.io, name, alloc, .unlimited);
    // std.zon.parse 要求 sentinel 结尾的源串
    const source = try alloc.dupeZ(u8, raw);

    const map = try std.zon.parse.fromSliceAlloc(
        engine.Map,
        alloc,
        source,
        null,
        .{},
    );
    const bytes = try map_file.encode(alloc, map);

    // 自检：立即解码刚产出的字节，确保读写格式闭环
    const check = try map_file.decode(alloc, bytes);
    std.debug.assert(check.width == map.width and check.height == map.height);
    std.debug.assert(check.layers.len == map.layers.len);

    const outputName = try std.mem.replaceOwned(u8, alloc, name, ".zon", ".bin");
    try dir.writeFile(init.io, .{ .sub_path = outputName, .data = bytes });
    std.log.info("wrote {d} bytes -> {s}", .{ bytes.len, outputName });
}
