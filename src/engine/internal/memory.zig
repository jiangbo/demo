const std = @import("std");
const sk = @import("sokol");

pub var counter: Counter = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var skAllocator: sk.gfx.Allocator = undefined;

pub fn init(gpa: std.mem.Allocator) void {
    counter = Counter.init(gpa);
    allocator = counter.allocator();
    skAllocator = .{ .alloc_fn = sk_alloc, .free_fn = sk_free };
}

pub const Counter = struct {
    child: std.mem.Allocator,
    used: usize,
    max: usize,
    count: usize,

    pub fn init(child: std.mem.Allocator) Counter {
        return .{ .child = child, .used = 0, .max = 0, .count = 0 };
    }

    pub fn allocator(self: *Counter) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = @This().alloc,
                .resize = resize,
                .remap = remap,
                .free = frees,
            },
        };
    }

    const A = std.mem.Alignment;
    fn alloc(ctx: *anyopaque, len: usize, a: A, r: usize) ?[*]u8 {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        const p = self.child.rawAlloc(len, a, r) orelse return null;
        self.count += 1;
        self.used += len;
        self.max = @max(self.max, self.used);
        return p;
    }

    fn resize(ctx: *anyopaque, b: []u8, a: A, len: usize, r: usize) bool {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        const stable = self.child.rawResize(b, a, len, r);
        if (stable) {
            self.count += 1;
            self.used = self.used - b.len + len;
            self.max = @max(self.max, self.used);
        }
        return stable;
    }

    fn remap(ctx: *anyopaque, m: []u8, a: A, len: usize, r: usize) ?[*]u8 {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        const n = self.child.rawRemap(m, a, len, r) orelse return null;
        self.count += 1;
        self.used = self.used - m.len + len;
        self.max = @max(self.max, self.used);
        return n;
    }

    fn frees(ctx: *anyopaque, buf: []u8, a: A, r: usize) void {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        self.used -= buf.len;
        return self.child.rawFree(buf, a, r);
    }
};

fn sk_alloc(len: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
    return alloc(len);
}

fn sk_free(ptr: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    free(ptr);
}

// C 的 free 不传长度，所以在返回指针前面存一份长度。
const cAlign = std.mem.Alignment.of(std.c.max_align_t);
const cHeaderSize = std.mem.alignForward(usize, //
    @sizeOf(usize), @alignOf(std.c.max_align_t));

fn cSlice(ptr: *anyopaque) []align(@alignOf(std.c.max_align_t)) u8 {
    const base = @as([*]u8, @ptrCast(ptr)) - cHeaderSize;
    const header: *usize = @ptrCast(@alignCast(base));
    return @alignCast(base[0 .. cHeaderSize + header.*]);
}

pub fn alloc(len: usize) ?*anyopaque {
    if (len == 0) return null;
    const base = allocator.rawAlloc(cHeaderSize + len, //
        cAlign, @returnAddress()) orelse return null;
    @as(*usize, @ptrCast(@alignCast(base))).* = len;
    return @ptrCast(base + cHeaderSize);
}

pub fn realloc(ptr: ?*anyopaque, len: usize) ?*anyopaque {
    const oldPtr = ptr orelse return alloc(len);
    if (len == 0) {
        free(oldPtr);
        return null;
    }

    const old = cSlice(oldPtr);
    const newLen = cHeaderSize + len;
    const newSlice = allocator.realloc(old, newLen) catch return null;
    @as(*usize, @ptrCast(@alignCast(newSlice.ptr))).* = len;
    return @ptrCast(newSlice.ptr + cHeaderSize);
}

pub fn free(ptr: ?*anyopaque) void {
    const p = ptr orelse return;
    allocator.rawFree(cSlice(p), cAlign, @returnAddress());
}
