const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Entity = u16;
const invalid = std.math.maxInt(u16);
fn hasEntity(slice: []const u16, entity: u16) bool {
    return entity < slice.len and slice[entity] != invalid;
}
pub const Version = u16;
pub const Handle = struct { entity: u16, version: Version };

fn Event(T: type) type {
    return struct { event: T };
}

const Entities = struct {
    versions: std.ArrayList(Version) = .empty,
    deleted: std.ArrayList(u16) = .empty,

    fn deinit(self: *Entities, gpa: Allocator) void {
        self.versions.deinit(gpa);
        self.deleted.deinit(gpa);
    }

    fn create(self: *Entities, gpa: Allocator) !u16 {
        if (self.deleted.pop()) |entity| {
            self.versions.items[entity] +%= 1;
            return entity;
        }

        const entity: u16 = @intCast(self.versions.items.len);
        if (entity == invalid) @panic("max entity count reached");
        try self.versions.append(gpa, 0);
        return entity;
    }

    fn destroy(self: *Entities, gpa: Allocator, entity: u16) !void {
        std.debug.assert(self.versions.items[entity] % 2 == 0);
        self.versions.items[entity] +%= 1;
        try self.deleted.append(gpa, entity);
    }

    pub fn isAlive(self: *const Entities, id: Handle) bool {
        return id.entity < self.versions.items.len and
            self.versions.items[id.entity] == id.version;
    }

    pub fn to(self: *const Entities, entity: u16) ?Handle {
        if (entity < self.versions.items.len) {
            const version = self.versions.items[entity];
            return .{ .entity = entity, .version = version };
        } else return null;
    }

    pub fn get(self: *const Entities, handle: ?Handle) ?u16 {
        const id = handle orelse return null;
        return if (self.isAlive(id)) id.entity else null;
    }
};

fn Store(K: type, V: type) type {
    return struct {
        const Self = @This();
        const Dense = std.ArrayList(u16);
        const Value = std.ArrayList(V);

        sparse: std.ArrayList(u16) = .empty,
        dense: []u16 = Dense.empty.items,
        values: []V = Value.empty.items,
        capacity: u16 = if (@sizeOf(V) == 0 and K != V) invalid else 0,
        identity: u16 = invalid,
        alignment: std.mem.Alignment = .of(V),
        valueSize: u16 = @sizeOf(V),

        fn deinit(self: *Self, gpa: Allocator) void {
            self.sparse.deinit(gpa);

            const hasDense = self.dense.ptr != Dense.empty.items.ptr;
            if (hasDense) gpa.free(self.dense.ptr[0..self.capacity]);
            if (self.capacity == 0 or self.valueSize == 0) return;

            const size = @as(usize, self.capacity) * self.valueSize;
            const bytes = @as([*]u8, @ptrCast(self.values.ptr))[0..size];
            gpa.rawFree(bytes, self.alignment, @returnAddress());
        }

        fn add(self: *Self, gpa: Allocator, entity: u16, v: V) !void {
            if (hasEntity(self.sparse.items, entity)) {
                self.values[self.sparse.items[entity]] = v;
                return;
            }

            if (entity >= self.sparse.items.len) {
                const count = entity + 1 - self.sparse.items.len;
                try self.sparse.appendNTimes(gpa, invalid, count);
            }

            if (self.values.len >= self.capacity) try self.grow(gpa);
            const index = self.dense.len;
            self.dense.len += 1;
            self.values.len += 1;
            self.dense[index] = entity;
            self.values[index] = v;
            self.sparse.items[entity] = @intCast(index);
        }

        fn append(self: *Self, gpa: Allocator, v: V) !void {
            if (self.values.len >= self.capacity) try self.grow(gpa);
            self.values.len += 1;
            self.values[self.values.len - 1] = v;
        }

        fn grow(self: *Self, gpa: Allocator) !void {
            const c = self.capacity;
            var values: Value = .{ .items = self.values, .capacity = c };
            if (@sizeOf(V) != 0) {
                try values.ensureUnusedCapacity(gpa, 1);
                self.values = values.items;
                self.capacity = @intCast(values.capacity);
            }
            if (K != V) return;

            var dense: Dense = .{ .items = self.dense, .capacity = c };
            if (@sizeOf(V) == 0) {
                try dense.ensureUnusedCapacity(gpa, 1);
                self.capacity = @intCast(dense.capacity);
            } else try dense.ensureTotalCapacityPrecise(gpa, self.capacity);
            self.dense = dense.items;
        }

        fn remove(self: *Self, entity: u16) u16 {
            if (!hasEntity(self.sparse.items, entity)) return invalid;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = invalid;

            self.values.len -= 1;
            self.dense.len -= 1;
            const moved = self.dense.ptr[self.values.len];
            if (self.values.len == index) return index;
            self.sparse.items[moved] = index;
            self.dense[index] = moved;
            if (self.valueSize == 0) return index;

            const sz = if (V == u8) self.valueSize else 1;
            const src = self.values.ptr[sz * self.values.len ..];
            @memcpy(self.values.ptr[sz * index ..][0..sz], src[0..sz]);
            return index;
        }

        fn sort(self: *Self, lessFn: fn (V, V) bool) void {
            if (self.values.len <= 1 or self.valueSize == 0) return;

            const sparse = self.sparse.items;
            const v = self.values;
            for (1..v.len) |i| {
                var j = i;
                while (j > 0 and lessFn(v[j], v[j - 1])) : (j -= 1) {
                    std.mem.swap(V, &v[j], &v[j - 1]);
                    const lhs = &self.dense[j];
                    const rhs = &self.dense[j - 1];
                    std.mem.swap(u16, lhs, rhs);
                    std.mem.swap(u16, &sparse[lhs.*], &sparse[rhs.*]);
                }
            }
        }

        fn clear(self: *Self) void {
            @memset(self.sparse.items, invalid);
            self.dense.len, self.values.len = .{ 0, 0 };
        }
    };
}

pub const TypeId = u32;
const Map = std.AutoHashMapUnmanaged;
pub const World = struct {
    allocator: Allocator,
    entities: Entities = .{},
    map: Map(TypeId, Store(u8, u8)) = .empty,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit(self.allocator);
        var iterator = self.map.valueIterator();
        while (iterator.next()) |map| map.deinit(self.allocator);
        self.map.deinit(self.allocator);
    }

    pub fn reset(self: *World) void {
        self.deinit();
        self.* = .init(self.allocator);
    }

    pub fn createEntity(self: *World) u16 {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn destroyEntity(self: *World, entity: u16) void {
        self.removeAll(entity);
        self.entities.destroy(self.allocator, entity) catch oom();
    }

    pub fn destroyEntities(self: *World, T: type) void {
        var toDestroy = self.query(.{T}).reverse();
        while (toDestroy.next()) |entity| self.destroyEntity(entity);
    }

    pub fn addIdentity(self: *World, entity: u16, T: type) void {
        self.assure(T, T).identity = entity;
    }

    pub fn createIdentity(self: *World, T: type) u16 {
        const entity = self.createEntity();
        self.addIdentity(entity, T);
        return entity;
    }

    pub fn getIdentity(self: *World, T: type) ?u16 {
        const entity = self.assure(T, T).identity;
        return if (entity == invalid) null else entity;
    }

    pub fn takeIdentity(self: *World, T: type) ?u16 {
        const entity = self.getIdentity(T);
        self.removeIdentity(T);
        return entity;
    }

    pub fn isIdentity(self: *World, entity: u16, T: type) bool {
        return self.getIdentity(T) orelse return false == entity;
    }

    pub fn removeIdentity(self: *World, T: type) void {
        self.assure(T, T).identity = invalid;
    }

    pub fn addEvent(self: *World, value: anytype) void {
        var map = self.assure(Event(@TypeOf(value)), @TypeOf(value));
        map.append(self.allocator, value) catch oom();
    }

    pub fn getEvent(self: *World, T: type) []T {
        return self.assure(Event(T), T).values;
    }

    pub fn clearEvent(self: *World, T: type) void {
        self.assure(Event(T), T).clear();
    }

    pub fn removeEvent(self: *World, T: type) void {
        const removed = self.map.fetchRemove(typeId(Event(T)));
        if (removed) |r| r.value.deinit(self.allocator);
    }

    fn assure(self: *World, K: type, V: type) *Store(K, V) {
        const result = self.map.getOrPut(self.allocator, //
            typeId(K)) catch oom();
        const map: *Store(K, V) = @ptrCast(@alignCast(result.value_ptr));
        if (!result.found_existing) map.* = .{};
        return map;
    }

    pub fn has(self: *World, entity: u16, T: type) bool {
        return hasEntity(self.assure(T, T).sparse.items, entity);
    }

    pub fn get(self: *World, entity: u16, T: type) ?T {
        return if (self.getPtr(entity, T)) |ptr| ptr.* else null;
    }

    pub fn getPtr(self: *World, entity: u16, T: type) ?*T {
        const map = self.assure(T, T);
        if (hasEntity(map.sparse.items, entity)) {
            return &map.values[map.sparse.items[entity]];
        } else return null;
    }

    pub fn add(self: *World, entity: u16, value: anytype) void {
        var map = self.assure(@TypeOf(value), @TypeOf(value));
        map.add(self.allocator, entity, value) catch oom();
    }

    pub fn values(self: *World, T: type) []T {
        return self.assure(T, T).values;
    }

    pub fn sort(self: *World, T: type, lessFn: fn (T, T) bool) void {
        self.assure(T, T).sort(lessFn);
    }

    pub fn remove(self: *World, entity: u16, T: type) void {
        _ = self.assure(T, T).remove(entity);
    }

    pub fn alignAdd(self: *World, entity: u16, comps: anytype) void {
        var indexes: [comps.len]u16 = undefined;
        inline for (comps, &indexes) |value, *i| {
            var map = self.assure(@TypeOf(value), @TypeOf(value));
            map.add(self.allocator, entity, value) catch oom();
            i.* = map.sparse.items[entity];
        }
        for (indexes[1..]) |i| std.debug.assert(indexes[0] == i);
    }

    pub fn alignRemove(self: *World, entity: u16, types: anytype) void {
        var index: [types.len]u16 = undefined;
        inline for (types, &index) |T, *i| {
            var map = self.assure(T, T);
            i.* = map.remove(entity);
        }
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    pub fn removeAll(self: *World, entity: u16) void {
        var iterator = self.map.valueIterator();
        while (iterator.next()) |map| {
            _ = map.remove(entity);
            if (map.identity == entity) map.identity = invalid;
        }
    }

    pub fn clear(self: *World, T: type) void {
        self.assure(T, T).clear();
    }

    pub fn clearAll(self: *World, types: anytype) void {
        inline for (types) |T| self.clear(T);
    }

    pub fn query(self: *World, All: anytype) Query(All, .{}) {
        return self.queryWithout(All, .{});
    }

    // zig fmt: off
    pub fn queryWithout(self: *World, All: anytype, None: anytype)
        Query(All, None) {
    // zig fmt: on
        comptime std.debug.assert(All.len > 0);

        var result: Query(All, None) = .{};
        var minCount: usize = invalid;
        inline for (All, &result.sparse, &result.values) |T, *s, *v| {
            const map = self.assure(T, T);
            s.*, v.* = .{ map.sparse.items, map.values.ptr };
            if (map.values.len < minCount) {
                minCount = map.values.len;
                result.dense = map.dense;
            }
        }
        inline for (None, &result.none) |T, *none| {
            none.* = self.assure(T, T).sparse.items;
        }

        return result;
    }

    // zig fmt: off
    pub fn queryBy(self: *World, By: type, All: anytype,
        None: anytype) Query(.{By} ++ All, None) {
    // zig fmt: on
        var rs: Query(.{By} ++ All, None) = .{};
        rs.dense = self.assure(By, By).dense;

        inline for (.{By} ++ All, &rs.sparse, &rs.values) |T, *s, *v| {
            const map = self.assure(T, T);
            s.*, v.* = .{ map.sparse.items, map.values.ptr };
        }
        inline for (None, &rs.none) |T, *none| {
            none.* = self.assure(T, T).sparse.items;
        }
        return rs;
    }
};

pub fn Query(comptime All: anytype, comptime None: anytype) type {
    return struct {
        dense: []u16 = &.{},
        sparse: [All.len][]u16 = undefined,
        values: [All.len]*anyopaque = undefined,
        none: [None.len][]u16 = undefined,
        index: u16 = 0,
        reversed: bool = false,

        pub fn reverse(self: @This()) @This() {
            var query = self;
            query.index = @intCast(query.dense.len -| 1);
            query.reversed = true;
            return query;
        }

        pub fn next(self: *@This()) ?u16 {
            blk: while (self.index < self.dense.len) {
                const entity = self.dense[self.index];
                if (self.reversed) self.index -%= 1 else self.index += 1;
                for (self.sparse) |sparse| {
                    if (!hasEntity(sparse, entity)) continue :blk;
                }
                for (self.none) |sparse| {
                    if (hasEntity(sparse, entity)) continue :blk;
                }
                return entity;
            } else return null;
        }

        pub fn get(self: *@This(), entity: u16, T: type) T {
            return self.getPtr(entity, T).*;
        }

        pub fn getPtr(self: *@This(), entity: u16, T: type) *T {
            const i = blk: inline for (All, 0..) |Comp, i| {
                if (Comp == T) break :blk i;
            } else @compileError(T ++ " is not in query type");
            const values: [*]T = @ptrCast(@alignCast(self.values[i]));
            return &values[self.sparse[i][entity]];
        }
    };
}

fn oom() noreturn {
    @panic("oom");
}
pub fn typeId(T: type) TypeId {
    return comptime std.hash.Fnv1a_32.hash(@typeName(T));
}
