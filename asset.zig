const std = @import("std");
const image = @import("image.zig");

const assetType = enum { image };
const Asset = union(assetType) {
    image: Image,
};

pub const Image = image.Image;

var allocator: std.mem.Allocator = undefined;
var assetMap: std.StringHashMap(Asset) = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    assetMap = std.StringHashMap(Asset).init(alloc);
}
