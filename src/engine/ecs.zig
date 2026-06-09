const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Entity = u16;
const invalid = std.math.maxInt(Entity);
fn hasEntity(slice: []const Entity, entity: Entity) bool {
    return entity < slice.len and slice[entity] != invalid;
}
pub const Version = u16;
pub const Identity = struct { entity: Entity, version: Version };

const Entities = struct {
    versions: std.ArrayList(Version) = .empty,
    deleted: std.ArrayList(Entity) = .empty,

    pub fn deinit(self: *Entities, gpa: Allocator) void {
        self.versions.deinit(gpa);
        self.deleted.deinit(gpa);
    }

    pub fn create(self: *Entities, gpa: Allocator) !Entity {
        if (self.deleted.pop()) |entity| return entity;

        const entity: Entity = @intCast(self.versions.items.len);
        if (entity == invalid) @panic("max entity count reached");
        try self.versions.append(gpa, 0);
        return entity;
    }

    pub fn destroy(self: *Entities, gpa: Allocator, entity: Entity) !void {
        self.versions.items[entity] +%= 1;
        try self.deleted.append(gpa, entity);
    }

    pub fn isAlive(self: *const Entities, identity: Identity) bool {
        return identity.entity < self.versions.items.len and
            self.versions.items[identity.entity] == identity.version;
    }

    pub fn toIdentity(self: *const Entities, entity: Entity) ?Identity {
        if (entity < self.versions.items.len) {
            const version = self.versions.items[entity];
            return .{ .entity = entity, .version = version };
        } else return null;
    }
};

pub fn SparseMap(T: type) type {
    return struct {
        const Self = @This();

        sparse: std.ArrayList(Entity) = .empty,
        dense: std.ArrayList(Entity) = .empty,
        alignment: std.mem.Alignment = .of(T),
        valuePtr: [*]T = undefined,
        valueSize: u16 = @sizeOf(T),

        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.sparse.deinit(gpa);
            const capacity = self.dense.capacity;
            self.dense.deinit(gpa);
            if (capacity == 0 or self.valueSize == 0) return;

            const slice = self.valuePtr[0 .. capacity * self.valueSize];
            gpa.rawFree(slice, self.alignment, @returnAddress());
        }

        pub fn add(self: *Self, gpa: Allocator, entity: Entity, v: T) !void {
            if (hasEntity(self.sparse.items, entity)) {
                if (self.valueSize != 0) {
                    self.valuePtr[self.sparse.items[entity]] = v;
                }
            } else try self.doAdd(gpa, entity, v);
        }

        fn doAdd(self: *Self, gpa: Allocator, entity: Entity, v: T) !void {
            if (entity >= self.sparse.items.len) {
                const count = entity + 1 - self.sparse.items.len;
                try self.sparse.appendNTimes(gpa, invalid, count);
            }

            const index: Entity = @intCast(self.dense.items.len);
            const oldCapacity = self.dense.capacity;
            try self.dense.append(gpa, entity);
            errdefer _ = self.dense.pop();
            if (self.valueSize != 0) {
                if (oldCapacity != self.dense.capacity) {
                    const slice = self.valuePtr[0..oldCapacity];
                    const capacity = self.dense.capacity;
                    self.valuePtr = (try gpa.realloc(slice, capacity)).ptr;
                }
                self.valuePtr[index] = v;
            }
            self.sparse.items[entity] = index;
        }

        pub fn components(self: *const Self) []T {
            std.debug.assert(self.valueSize != 0);
            return self.valuePtr[0..self.dense.items.len];
        }

        pub fn remove(self: *Self, entity: Entity) Entity {
            if (!hasEntity(self.sparse.items, entity)) return invalid;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = invalid;

            const moved = self.dense.pop().?;
            if (self.dense.items.len == index) return index;
            self.sparse.items[moved] = index;
            self.dense.items[index] = moved;
            if (self.valueSize == 0) return index;

            const sz = if (T == u8) self.valueSize else 1;
            const src = self.valuePtr[sz * self.dense.items.len ..];
            @memcpy(self.valuePtr[sz * index ..][0..sz], src[0..sz]);
            return index;
        }

        pub fn sort(self: *Self, lessFn: fn (T, T) bool) void {
            if (self.dense.items.len <= 1 or self.valueSize == 0) return;

            const sparse = self.sparse.items;
            const v = self.valuePtr[0..self.dense.items.len];
            for (1..v.len) |i| {
                var j = i;
                while (j > 0 and lessFn(v[j], v[j - 1])) : (j -= 1) {
                    std.mem.swap(T, &v[j], &v[j - 1]);
                    const lhs = &self.dense.items[j];
                    const rhs = &self.dense.items[j - 1];
                    std.mem.swap(Entity, lhs, rhs);
                    std.mem.swap(Entity, &sparse[lhs.*], &sparse[rhs.*]);
                }
            }
        }

        pub fn clear(self: *Self) void {
            @memset(self.sparse.items, invalid);
            self.dense.clearRetainingCapacity();
        }
    };
}

fn EventList(T: type) type {
    return struct {
        list: std.ArrayList(T) = .empty,
        alignment: std.mem.Alignment = .of(T),
        valueSize: u32 = @sizeOf(T),

        fn deinit(self: *@This(), gpa: Allocator) void {
            if (self.list.capacity == 0) return;
            const byteCount = self.list.capacity * self.valueSize;
            const slice = self.list.items.ptr[0..byteCount];
            gpa.rawFree(slice, self.alignment, @returnAddress());
        }
    };
}

pub const TypeId = u32;
const Map = std.AutoHashMapUnmanaged;
pub const World = struct {
    allocator: Allocator,
    entities: Entities = .{},
    componentMap: Map(TypeId, SparseMap(u8)) = .empty,

    identityMap: Map(TypeId, Identity) = .empty,
    eventMap: Map(TypeId, EventList(u8)) = .empty,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit(self.allocator);
        self.identityMap.deinit(self.allocator);

        var events = self.eventMap.valueIterator();
        while (events.next()) |list| list.deinit(self.allocator);
        self.eventMap.deinit(self.allocator);

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |map| map.deinit(self.allocator);
        self.componentMap.deinit(self.allocator);
    }

    pub fn reset(self: *World) void {
        self.deinit();
        self.* = .init(self.allocator);
    }

    pub fn createEntity(self: *World) Entity {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn destroyEntity(self: *World, entity: Entity) void {
        self.removeAll(entity);
        self.entities.destroy(self.allocator, entity) catch oom();
    }

    pub fn destroyEntities(self: *World, T: type) void {
        var toDestroy = self.query(.{T}).reverse();
        while (toDestroy.next()) |entity| self.destroyEntity(entity);
    }

    pub fn toEntity(self: *const World, identity: ?Identity) ?Entity {
        const id = identity orelse return null;
        return if (self.entities.isAlive(id)) id.entity else null;
    }

    pub fn addIdentity(self: *World, entity: Entity, T: type) void {
        self.identityMap.put(self.allocator, hashTypeId(T), //
            self.entities.toIdentity(entity).?) catch oom();
    }

    pub fn createIdentity(self: *World, T: type) Entity {
        const entity = self.createEntity();
        self.addIdentity(entity, T);
        return entity;
    }

    pub fn getIdentity(self: *World, T: type) ?Entity {
        return self.toEntity(self.identityMap.get(hashTypeId(T)));
    }

    pub fn isIdentity(self: *World, entity: Entity, T: type) bool {
        return self.getIdentity(T) orelse return false == entity;
    }

    pub fn removeIdentity(self: *World, T: type) bool {
        return self.identityMap.remove(hashTypeId(T));
    }

    pub fn addEvent(self: *World, value: anytype) void {
        var list = self.getEvent(@TypeOf(value));
        list.append(self.allocator, value) catch oom();
    }

    pub fn getEvent(self: *World, T: type) *std.ArrayList(T) {
        const v = self.eventMap.getOrPut(self.allocator, //
            hashTypeId(T)) catch oom();
        const list: *EventList(T) = @ptrCast(@alignCast(v.value_ptr));
        if (!v.found_existing) list.* = .{};
        return &list.list;
    }

    pub fn clearEvent(self: *World, T: type) void {
        self.getEvent(T).clearRetainingCapacity();
    }

    pub fn removeEvent(self: *World, T: type) void {
        const removed = self.eventMap.fetchRemove(hashTypeId(T));
        if (removed) |r| r.value.deinit(self.allocator);
    }

    pub fn assure(self: *World, T: type) *SparseMap(T) {
        const result = self.componentMap.getOrPut(self.allocator, //
            hashTypeId(T)) catch oom();
        const map: *SparseMap(T) = @ptrCast(@alignCast(result.value_ptr));
        if (!result.found_existing) map.* = .{};
        return map;
    }

    pub fn has(self: *World, entity: Entity, T: type) bool {
        return hasEntity(self.assure(T).sparse.items, entity);
    }

    pub fn get(self: *World, entity: Entity, T: type) ?T {
        return if (self.getPtr(entity, T)) |ptr| ptr.* else null;
    }

    pub fn getPtr(self: *World, entity: Entity, T: type) ?*T {
        const map = self.assure(T);
        if (hasEntity(map.sparse.items, entity)) {
            return &map.valuePtr[map.sparse.items[entity]];
        } else return null;
    }

    pub fn add(self: *World, entity: Entity, value: anytype) void {
        var map = self.assure(@TypeOf(value));
        map.add(self.allocator, entity, value) catch oom();
    }

    pub fn raw(self: *World, T: type) []T {
        return self.assure(T).components();
    }

    pub fn count(self: *World, T: type) usize {
        return self.assure(T).dense.items.len;
    }

    pub fn sort(self: *World, T: type, lessFn: fn (T, T) bool) void {
        self.assure(T).sort(lessFn);
    }

    pub fn remove(self: *World, entity: Entity, T: type) void {
        _ = self.assure(T).remove(entity);
    }

    pub fn alignAdd(self: *World, entity: Entity, comps: anytype) void {
        var indexes: [comps.len]Entity = undefined;
        inline for (comps, &indexes) |value, *i| {
            var map = self.assure(@TypeOf(value));
            map.add(self.allocator, entity, value) catch oom();
            i.* = map.sparse.items[entity];
        }
        for (indexes[1..]) |i| std.debug.assert(indexes[0] == i);
    }

    pub fn alignRemove(self: *World, entity: Entity, types: anytype) void {
        var index: [types.len]Entity = undefined;
        inline for (types, &index) |T, *i| {
            var map = self.assure(T);
            i.* = map.remove(entity);
        }
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    pub fn removeAll(self: *World, entity: Entity) void {
        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |map| _ = map.remove(entity);
    }

    pub fn clear(self: *World, T: type) void {
        self.assure(T).clear();
    }

    pub fn clearAll(self: *World, types: anytype) void {
        inline for (types) |T| self.clear(T);
    }

    pub fn query(self: *World, All: anytype) Query(All, .{}) {
        return self.queryNone(All, .{});
    }

    // zig fmt: off
    pub fn queryNone(self: *World, All: anytype, None: anytype)
        Query(All, None) {
    // zig fmt: on
        comptime std.debug.assert(All.len > 0);

        var result: Query(All, None) = .{};
        var minCount: usize = invalid;
        inline for (All, &result.sparse, &result.values) |T, *s, *v| {
            const map = self.assure(T);
            s.*, v.* = .{ map.sparse.items, map.valuePtr };
            if (map.dense.items.len < minCount) {
                minCount = map.dense.items.len;
                result.dense = map.dense.items;
            }
        }
        inline for (None, &result.none) |T, *none| {
            none.* = self.assure(T).sparse.items;
        }

        return result;
    }

    // zig fmt: off
    pub fn queryBy(self: *World, By: type, All: anytype,
        None: anytype) Query(.{By} ++ All, None) {
    // zig fmt: on
        var rs: Query(.{By} ++ All, None) = .{};
        rs.dense = self.assure(By).dense.items;

        inline for (.{By} ++ All, &rs.sparse, &rs.values) |T, *s, *v| {
            const map = self.assure(T);
            s.*, v.* = .{ map.sparse.items, map.valuePtr };
        }
        inline for (None, &rs.none) |T, *none| {
            none.* = self.assure(T).sparse.items;
        }
        return rs;
    }
};

pub fn Query(comptime All: anytype, comptime None: anytype) type {
    return struct {
        dense: []Entity = &.{},
        sparse: [All.len][]Entity = undefined,
        values: [All.len]*anyopaque = undefined,
        none: [None.len][]Entity = undefined,
        index: Entity = 0,
        reversed: bool = false,

        pub fn reverse(self: @This()) @This() {
            var query = self;
            query.index = @intCast(query.dense.len -| 1);
            query.reversed = true;
            return query;
        }

        pub fn next(self: *@This()) ?Entity {
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

        pub fn get(self: *@This(), entity: Entity, T: type) T {
            return self.getPtr(entity, T).*;
        }

        pub fn getPtr(self: *@This(), entity: Entity, T: type) *T {
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
pub fn hashTypeId(T: type) TypeId {
    return comptime std.hash.Fnv1a_32.hash(@typeName(T));
}
