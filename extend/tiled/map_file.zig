const std = @import("std");
const tiled = @import("tiled.zig");
const graphics = @import("../graphics.zig");

// 地图二进制格式 .bin
// 目标：替代体积庞大的 .zon 文本，运行时经 assets 异步加载解码。
// 布局为小端字节序，魔数 "TMAP" + 版本号开头，瓦片数据走 RLE 压缩。
// 编码（转换器用）与解码（运行时用）共用本文件，杜绝读写格式漂移。

const magic = "TMAP";
const version: u16 = 1;

// 字符串统一用 u16 长度前缀，避免长字符串被静默截断。
// RLE 单段行程上限 u16，超长连续段自动拆分。

// ============================ 写入端 ============================

const Out = struct {
    list: std.ArrayList(u8) = .empty,
    alloc: std.mem.Allocator,

    fn byte(self: *Out, v: u8) !void {
        try self.list.append(self.alloc, v);
    }

    // 整数按小端写入（u16/u32/i32 通用）。
    fn int(self: *Out, comptime T: type, v: T) !void {
        const little = std.mem.nativeToLittle(T, v);
        try self.list.appendSlice(self.alloc, &std.mem.toBytes(little));
    }

    fn float(self: *Out, v: f32) !void {
        try self.int(u32, @bitCast(v));
    }

    fn str(self: *Out, s: []const u8) !void {
        try self.int(u16, @intCast(s.len));
        try self.list.appendSlice(self.alloc, s);
    }
};

/// 把一张地图编码为 .bin 字节，调用方负责释放返回的切片。
pub fn encode(
    alloc: std.mem.Allocator,
    map: tiled.Map,
) ![]u8 {
    var out: Out = .{ .list = .empty, .alloc = alloc };
    errdefer out.list.deinit(alloc);

    try out.list.appendSlice(alloc, magic);
    try out.int(u16, version);
    try out.int(u32, map.width);
    try out.int(u32, map.height);
    try out.float(map.tileSize.x);
    try out.float(map.tileSize.y);
    try writeColor(&out, map.backgroundColor);

    try out.byte(@intCast(map.tileSetRefs.len));
    for (map.tileSetRefs) |ref| try out.int(u32, ref.id);

    try out.byte(@intCast(map.layers.len));
    for (map.layers) |layer| try writeLayer(&out, layer);

    return out.list.toOwnedSlice(alloc);
}

fn writeColor(out: *Out, c: ?graphics.Color) !void {
    if (c) |v| {
        try out.byte(1);
        try out.float(v.r);
        try out.float(v.g);
        try out.float(v.b);
        try out.float(v.a);
    } else try out.byte(0);
}

fn writeLayer(out: *Out, layer: tiled.Layer) !void {
    try out.int(u32, layer.id);
    try out.byte(@intFromEnum(layer.type)); // 0image 1tile 2object
    try out.int(u32, layer.image);
    try out.str(layer.name);
    try out.float(layer.width);
    try out.float(layer.height);
    try out.float(layer.offset.x);
    try out.float(layer.offset.y);
    try out.float(layer.parallaxX);
    try out.float(layer.parallaxY);
    try out.byte(@intFromBool(layer.repeatX));
    try out.byte(@intFromBool(layer.repeatY));

    // 瓦片数据：格子数 + RLE 行程
    try out.int(u32, @intCast(layer.data.len));
    try writeRle(out, layer.data);

    // 对象列表
    try out.int(u32, @intCast(layer.objects.len));
    for (layer.objects) |obj| try writeObject(out, obj);
}

// 连续相同 gid 合并为 (run, gid) 对，单段 run 上限 65535，超出自动拆段。
fn writeRle(out: *Out, data: []const u32) !void {
    var i: usize = 0;
    while (i < data.len) {
        const gid = data[i];
        var run: usize = 1;
        while (i + run < data.len and
            data[i + run] == gid and
            run < 65535) run += 1;
        try out.int(u16, @intCast(run));
        try out.int(u32, gid);
        i += run;
    }
}

fn writeObject(out: *Out, o: tiled.Object) !void {
    try out.int(u32, o.id);
    try out.int(u32, o.gid);
    try out.byte(@intFromBool(o.point));
    const ext: u8 = @as(u8, @intFromBool(o.extend.flipX)) |
        (@as(u8, @intFromBool(o.extend.flipY)) << 1) |
        (@as(u8, @intFromBool(o.extend.rotation)) << 2);
    try out.byte(ext);
    try out.str(o.name);
    try out.str(o.type);
    try out.float(o.position.x);
    try out.float(o.position.y);
    try out.float(o.size.x);
    try out.float(o.size.y);
    try out.byte(@intCast(o.properties.len));
    for (o.properties) |p| try writeProperty(out, p);
}

fn writeProperty(out: *Out, p: tiled.Property) !void {
    try out.str(p.name);
    try out.byte(@intFromEnum(p.value)); // 属性类型 tag
    switch (p.value) {
        .string => |s| try out.str(s),
        .int => |v| try out.int(i32, v),
        .float => |v| try out.float(v),
        .bool => |v| try out.byte(@intFromBool(v)),
        .object => |v| try out.int(i32, v),
        .class => |c| {
            try out.str(c.type);
            try out.byte(@intCast(c.properties.len));
            for (c.properties) |cp| try writeProperty(out, cp);
        },
    }
}

// ============================ 读取端 ============================

const Cursor = struct {
    buf: []const u8,
    pos: usize = 0,

    fn byte(self: *Cursor) !u8 {
        if (self.pos + 1 > self.buf.len) return error.Truncated;
        const v = self.buf[self.pos];
        self.pos += 1;
        return v;
    }

    fn int(self: *Cursor, comptime T: type) !T {
        const n = @sizeOf(T);
        if (self.pos + n > self.buf.len) return error.Truncated;
        const v = std.mem.readInt(T, self.buf[self.pos..][0..n], .little);
        self.pos += n;
        return v;
    }

    fn float(self: *Cursor) !f32 {
        return @bitCast(try self.int(u32));
    }

    // 读取并复制字符串，使其独立于输入缓冲存活。
    fn str(self: *Cursor, alloc: std.mem.Allocator) ![]const u8 {
        const len = try self.int(u16);
        if (self.pos + len > self.buf.len) return error.Truncated;
        const s = try alloc.dupe(u8, self.buf[self.pos .. self.pos + len]);
        self.pos += len;
        return s;
    }
};

/// 从 .bin 字节解码出地图，各切片由 alloc 分配并拥有。
pub fn decode(
    alloc: std.mem.Allocator,
    bytes: []const u8,
) !tiled.Map {
    var cur: Cursor = .{ .buf = bytes };

    if (cur.buf.len < magic.len) return error.Truncated;
    if (!std.mem.eql(u8, cur.buf[0..magic.len], magic)) {
        return error.InvalidMagic;
    }
    cur.pos = magic.len;
    if (try cur.int(u16) != version) return error.WrongVersion;

    const width = try cur.int(u32);
    const height = try cur.int(u32);
    const tx = try cur.float();
    const ty = try cur.float();
    const bg = try readColor(&cur);

    const refs = try alloc.alloc(tiled.TileSetRef, try cur.byte());
    for (refs) |*r| r.* = .{ .id = try cur.int(u32) };

    const layers = try alloc.alloc(tiled.Layer, try cur.byte());
    for (layers) |*l| l.* = try readLayer(alloc, &cur);

    return .{
        .height = height,
        .width = width,
        .backgroundColor = bg,
        .tileSize = .{ .x = tx, .y = ty },
        .layers = layers,
        .tileSetRefs = refs,
    };
}

fn readColor(cur: *Cursor) !?graphics.Color {
    if (try cur.byte() == 0) return null;
    return .{
        .r = try cur.float(),
        .g = try cur.float(),
        .b = try cur.float(),
        .a = try cur.float(),
    };
}

fn readLayer(alloc: std.mem.Allocator, cur: *Cursor) !tiled.Layer {
    const id = try cur.int(u32);
    const ty: tiled.LayerEnum = @enumFromInt(try cur.byte());
    const image = try cur.int(u32);
    const name = try cur.str(alloc);
    const w = try cur.float();
    const h = try cur.float();
    const ox = try cur.float();
    const oy = try cur.float();
    const px = try cur.float();
    const py = try cur.float();
    const rx = (try cur.byte()) != 0;
    const ry = (try cur.byte()) != 0;

    const data = try readRle(alloc, cur, try cur.int(u32));

    const objects = try alloc.alloc(tiled.Object, try cur.int(u32));
    for (objects) |*o| o.* = try readObject(alloc, cur);

    return .{
        .id = id,
        .name = name,
        .image = image,
        .type = ty,
        .width = w,
        .height = h,
        .offset = .{ .x = ox, .y = oy },
        .data = data,
        .objects = objects,
        .parallaxX = px,
        .parallaxY = py,
        .repeatX = rx,
        .repeatY = ry,
    };
}

// 按 cellCount 还原瓦片数据，读到声明长度为止。
fn readRle(
    alloc: std.mem.Allocator,
    cur: *Cursor,
    cell_count: u32,
) ![]u32 {
    const data = try alloc.alloc(u32, cell_count);
    var filled: usize = 0;
    while (filled < cell_count) {
        const run: usize = try cur.int(u16);
        const gid = try cur.int(u32);
        if (run == 0 or filled + run > cell_count) return error.Truncated;
        for (data[filled..][0..run]) |*c| c.* = gid;
        filled += run;
    }
    return data;
}

fn readObject(alloc: std.mem.Allocator, cur: *Cursor) !tiled.Object {
    const id = try cur.int(u32);
    const gid = try cur.int(u32);
    const point = (try cur.byte()) != 0;
    const ext = try cur.byte();
    const name = try cur.str(alloc);
    const type_name = try cur.str(alloc);
    const px = try cur.float();
    const py = try cur.float();
    const sx = try cur.float();
    const sy = try cur.float();

    const props = try alloc.alloc(tiled.Property, try cur.byte());
    for (props) |*p| p.* = try readProperty(alloc, cur);

    return .{
        .id = id,
        .gid = gid,
        .name = name,
        .type = type_name,
        .position = .{ .x = px, .y = py },
        .size = .{ .x = sx, .y = sy },
        .point = point,
        .properties = props,
        .extend = .{
            .flipX = (ext & 1) != 0,
            .flipY = (ext & 2) != 0,
            .rotation = (ext & 4) != 0,
        },
    };
}

fn readProperty(alloc: std.mem.Allocator, cur: *Cursor) !tiled.Property {
    const name = try cur.str(alloc);
    const value: tiled.PropertyValue = switch (try cur.byte()) {
        0 => .{ .string = try cur.str(alloc) },
        1 => .{ .int = try cur.int(i32) },
        2 => .{ .float = try cur.float() },
        3 => .{ .bool = (try cur.byte()) != 0 },
        4 => .{ .object = try cur.int(i32) },
        5 => class: {
            const ctype = try cur.str(alloc);
            const props = try alloc.alloc(tiled.Property, try cur.byte());
            for (props) |*p| p.* = try readProperty(alloc, cur);
            break :class .{ .class = .{ .type = ctype, .properties = props } };
        },
        else => return error.Truncated,
    };
    return .{ .name = name, .value = value };
}

// ============================ 单元测试 ============================

const testing = std.testing;

test "RLE：全相同/全零/单元素/超长拆段" {
    const alloc = testing.allocator;

    const cases = [_]struct { in: []const u32 }{
        .{ .in = &[_]u32{} },
        .{ .in = &[_]u32{ 5, 5, 5, 5, 5 } },
        .{ .in = &[_]u32{0} ** 8 },
        .{ .in = &[_]u32{ 1, 2, 3 } },
        .{ .in = &[_]u32{7} ** 70000 }, // 超 65535 必须拆段
    };

    for (cases) |c| {
        var out: Out = .{ .list = .empty, .alloc = alloc };
        defer out.list.deinit(alloc);
        try out.int(u32, @intCast(c.in.len));
        try writeRle(&out, c.in);

        var cur: Cursor = .{ .buf = out.list.items };
        const got = try readRle(alloc, &cur, @intCast(c.in.len));
        defer alloc.free(got);
        try testing.expectEqualSlices(u32, c.in, got);
    }
}

test "地图二进制 round-trip：三类层 + 各类属性" {
    const alloc = testing.allocator;

    // 构造一张含 tile/image/object 三类层的地图
    const original: tiled.Map = .{
        .width = 3,
        .height = 2,
        .backgroundColor = .{ .r = 0.25, .g = 0.5, .b = 0.75, .a = 1 },
        .tileSize = .{ .x = 16, .y = 16 },
        .tileSetRefs = &.{
            .{ .id = 3790407532 },
            .{ .id = 112365652 },
        },
        .layers = &.{
            // tile 层：含空段、连续段、散点
            .{
                .id = 1,
                .name = "ground",
                .image = 0,
                .type = .tile,
                .width = 3,
                .height = 2,
                .offset = .{ .x = 0, .y = 0 },
                .data = &.{ 0, 0, 0, 16777321, 16777321, 33554885 },
                .objects = &.{},
            },
            // image 层
            .{
                .id = 2,
                .name = "sky",
                .image = 42,
                .type = .image,
                .width = 480,
                .height = 240,
                .offset = .{ .x = 10, .y = -5 },
                .data = &.{},
                .objects = &.{},
                .parallaxX = 0.5,
                .parallaxY = 0.5,
                .repeatX = true,
            },
            // object 层：两个对象，覆盖多种属性类型
            .{
                .id = 3,
                .name = "main",
                .image = 0,
                .type = .object,
                .offset = .{ .x = 0, .y = 0 },
                .data = &.{},
                .objects = &.{
                    .{
                        .id = 10,
                        .gid = 83886198,
                        .name = "npc_bob",
                        .type = "actor",
                        .position = .{ .x = 32, .y = 48 },
                        .size = .{ .x = 16, .y = 24 },
                        .point = false,
                        .properties = &.{
                            .{ .name = "label", .value = .{ .string = "hi" } },
                            .{ .name = "count", .value = .{ .int = -7 } },
                            .{ .name = "speed", .value = .{ .float = 1.5 } },
                            .{ .name = "on", .value = .{ .bool = true } },
                            .{ .name = "ref", .value = .{ .object = 99 } },
                            .{
                                .name = "spot",
                                .value = .{ .class = .{
                                    .type = "Spotlight",
                                    .properties = &.{
                                        .{
                                            .name = "radius",
                                            .value = .{ .int = 4 },
                                        },
                                    },
                                } },
                            },
                        },
                        .extend = .{ .flipX = true, .rotation = true },
                    },
                    .{
                        .id = 11,
                        .gid = 0,
                        .name = "spawn",
                        .type = "trigger",
                        .position = .{ .x = 0, .y = 0 },
                        .size = .{ .x = 16, .y = 16 },
                        .point = true,
                        .properties = &.{},
                        .extend = .{},
                    },
                },
            },
        },
    };

    const bytes = try encode(alloc, original);
    defer alloc.free(bytes);
    const round = try decode(alloc, bytes);
    defer deinit(alloc, round);

    try testing.expectEqual(original.width, round.width);
    try testing.expectEqual(original.height, round.height);
    try testing.expectEqual(original.tileSize.x, round.tileSize.x);
    try testing.expectEqual(original.tileSize.y, round.tileSize.y);
    const expectDeep = testing.expectEqualDeep;
    const refs = original.tileSetRefs;
    const roundRefs = round.tileSetRefs;
    try expectDeep(original.backgroundColor, round.backgroundColor);
    try testing.expectEqual(refs.len, roundRefs.len);
    try testing.expectEqual(refs[0].id, roundRefs[0].id);
    try testing.expectEqual(refs[1].id, roundRefs[1].id);

    try testing.expectEqual(original.layers.len, round.layers.len);
    try expectLayersEqual(original.layers, round.layers);
}

/// 递归释放 decode 分配的全部切片。加载器清理地图缓存时调用。
pub fn deinit(alloc: std.mem.Allocator, map: tiled.Map) void {
    for (map.layers) |layer| {
        alloc.free(layer.data);
        for (layer.objects) |obj| deinitProps(alloc, obj.properties);
        alloc.free(layer.objects);
        alloc.free(layer.name);
    }
    alloc.free(map.layers);
    alloc.free(map.tileSetRefs);
}

fn deinitProps(alloc: std.mem.Allocator, props: []const tiled.Property) void {
    for (props) |p| {
        switch (p.value) {
            .string => |s| alloc.free(s),
            .class => |c| deinitProps(alloc, c.properties),
            else => {},
        }
        alloc.free(p.name);
    }
    alloc.free(props);
}

fn expectLayersEqual(e: []const tiled.Layer, a: []const tiled.Layer) !void {
    try testing.expectEqual(e.len, a.len);
    for (e, a) |el, al| {
        try testing.expectEqualStrings(el.name, al.name);
        try testing.expectEqual(el.id, al.id);
        try testing.expectEqual(el.image, al.image);
        try testing.expectEqual(@intFromEnum(el.type), @intFromEnum(al.type));
        try testing.expectEqual(el.width, al.width);
        try testing.expectEqual(el.height, al.height);
        try testing.expectEqual(el.offset.x, al.offset.x);
        try testing.expectEqual(el.offset.y, al.offset.y);
        try testing.expectEqual(el.parallaxX, al.parallaxX);
        try testing.expectEqual(el.parallaxY, al.parallaxY);
        try testing.expectEqual(el.repeatX, al.repeatX);
        try testing.expectEqual(el.repeatY, al.repeatY);
        try testing.expectEqualSlices(u32, el.data, al.data);
        try testing.expectEqual(el.objects.len, al.objects.len);
        for (el.objects, al.objects) |eo, ao| try expectObjectEqual(eo, ao);
    }
}

fn expectObjectEqual(e: tiled.Object, a: tiled.Object) !void {
    try testing.expectEqual(e.id, a.id);
    try testing.expectEqual(e.gid, a.gid);
    try testing.expectEqual(e.point, a.point);
    try testing.expectEqual(e.extend.flipX, a.extend.flipX);
    try testing.expectEqual(e.extend.flipY, a.extend.flipY);
    try testing.expectEqual(e.extend.rotation, a.extend.rotation);
    try testing.expectEqualStrings(e.name, a.name);
    try testing.expectEqualStrings(e.type, a.type);
    try testing.expectEqual(e.position.x, a.position.x);
    try testing.expectEqual(e.position.y, a.position.y);
    try testing.expectEqual(e.size.x, a.size.x);
    try testing.expectEqual(e.size.y, a.size.y);
    try expectPropsEqual(e.properties, a.properties);
}

fn expectPropsEqual(
    e: []const tiled.Property,
    a: []const tiled.Property,
) !void {
    try testing.expectEqual(e.len, a.len);
    for (e, a) |ep, ap| {
        try testing.expectEqualStrings(ep.name, ap.name);
        try testing.expectEqual(@intFromEnum(ep.value), @intFromEnum(ap.value));
        switch (ep.value) {
            .string => |s| try testing.expectEqualStrings(s, ap.value.string),
            .int => |v| try testing.expectEqual(v, ap.value.int),
            .float => |v| try testing.expectEqual(v, ap.value.float),
            .bool => |v| try testing.expectEqual(v, ap.value.bool),
            .object => |v| try testing.expectEqual(v, ap.value.object),
            .class => |c| {
                try testing.expectEqualStrings(c.type, ap.value.class.type);
                try expectPropsEqual(c.properties, ap.value.class.properties);
            },
        }
    }
}
