const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Entity = u16;
const invalid = std.math.maxInt(Entity);
pub fn hasEntity(slice: []const Entity, entity: Entity) bool {
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

        pub fn has(self: *const Self, entity: Entity) bool {
            return hasEntity(self.sparse.items, entity);
        }

        pub fn add(self: *Self, gpa: Allocator, entity: Entity, v: T) !void {
            if (self.has(entity)) {
                if (self.valueSize != 0) self.get(entity).* = v;
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

        pub fn get(self: *const Self, entity: Entity) *T {
            std.debug.assert(self.valueSize != 0);
            return &self.valuePtr[self.sparse.items[entity]];
        }

        pub fn tryGet(self: *const Self, entity: Entity) ?*T {
            return if (self.has(entity)) self.get(entity) else null;
        }

        pub fn components(self: *const Self) []T {
            std.debug.assert(self.valueSize != 0);
            return self.valuePtr[0..self.dense.items.len];
        }

        pub fn swapRemove(self: *Self, entity: Entity) Entity {
            if (!self.has(entity)) return invalid;

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

        pub fn orderedRemove(self: *Self, entity: Entity) void {
            if (!self.has(entity)) return;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = invalid;
            _ = self.dense.orderedRemove(index);
            for (self.dense.items[index..]) |e| self.sparse.items[e] -= 1;
            if (self.valueSize == 0) return;

            const sz = if (T == u8) self.valueSize else 1;
            const len = (self.dense.items.len - index) * sz;
            const src = self.valuePtr[sz * (index + 1) ..][0..len];
            @memmove(self.valuePtr[sz * index ..][0..len], src);
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
pub const Registry = struct {
    allocator: Allocator,
    entities: Entities = .{},
    componentMap: Map(TypeId, SparseMap(u8)) = .empty,

    identityMap: Map(TypeId, Entity) = .empty,
    eventMap: Map(TypeId, EventList(u8)) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.entities.deinit(self.allocator);
        self.identityMap.deinit(self.allocator);

        var events = self.eventMap.valueIterator();
        while (events.next()) |list| list.deinit(self.allocator);
        self.eventMap.deinit(self.allocator);

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |map| map.deinit(self.allocator);
        self.componentMap.deinit(self.allocator);
    }

    pub fn reset(self: *Registry) void {
        self.deinit();
        self.* = .init(self.allocator);
    }

    pub fn createEntity(self: *Registry) Entity {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn destroyEntity(self: *Registry, entity: Entity) void {
        self.removeAll(entity);
        self.entities.destroy(self.allocator, entity) catch oom();
    }

    pub fn addIdentity(self: *Registry, e: Entity, T: type) void {
        const id = hashTypeId(T);
        self.identityMap.put(self.allocator, id, e) catch oom();
    }

    pub fn createIdentityEntity(self: *Registry, T: type) Entity {
        const entity = self.createEntity();
        self.addIdentity(entity, T);
        return entity;
    }

    pub fn getIdentityEntity(self: *Registry, T: type) ?Entity {
        return self.identityMap.get(hashTypeId(T));
    }

    pub fn getIdentity(self: *Registry, T: type, V: type) ?V {
        const entity = self.getIdentityEntity(T) orelse return null;
        return self.get(entity, V);
    }

    pub fn isIdentity(self: *Registry, e: Entity, T: type) bool {
        const e1 = self.getIdentityEntity(T) orelse return false;
        return e1 == e;
    }

    pub fn removeIdentity(self: *Registry, T: type) bool {
        return self.identityMap.remove(hashTypeId(T));
    }

    fn assureEvent(self: *Registry, T: type) *std.ArrayList(T) {
        const v = self.eventMap.getOrPut(self.allocator, //
            hashTypeId(T)) catch oom();
        const list: *EventList(T) = @ptrCast(@alignCast(v.value_ptr));
        if (!v.found_existing) {
            list.* = .{};
        }
        return &list.list;
    }

    pub fn addEvent(self: *Registry, value: anytype) void {
        var list = self.assureEvent(@TypeOf(value));
        list.append(self.allocator, value) catch oom();
    }

    pub fn getEvents(self: *Registry, T: type) *std.ArrayList(T) {
        return self.assureEvent(T);
    }

    pub fn popEvent(self: *Registry, T: type) ?T {
        return self.assureEvent(T).pop();
    }

    pub fn clearEvent(self: *Registry, T: type) void {
        self.assureEvent(T).clearRetainingCapacity();
    }

    pub fn removeEvent(self: *Registry, T: type) void {
        var removed = self.eventMap.fetchRemove(hashTypeId(T));
        (removed orelse return).value.deinit(self.allocator);
    }

    pub fn assure(self: *Registry, T: type) *SparseMap(T) {
        const result = self.componentMap
            .getOrPut(self.allocator, hashTypeId(T)) catch oom();
        const map: *SparseMap(T) = @ptrCast(@alignCast(result.value_ptr));

        if (!result.found_existing) map.* = .{};

        return map;
    }

    pub fn add(self: *Registry, entity: Entity, value: anytype) void {
        var map = self.assure(@TypeOf(value));
        map.add(self.allocator, entity, value) catch oom();
    }

    pub fn alignAdd(self: *Registry, entity: Entity, comps: anytype) void {
        var indexes: [comps.len]Entity = undefined;
        inline for (comps, &indexes) |value, *i| {
            var map = self.assure(@TypeOf(value));
            map.add(self.allocator, entity, value) catch oom();
            i.* = map.sparse.items[entity];
        }
        for (indexes[1..]) |i| std.debug.assert(indexes[0] == i);
    }

    pub fn has(self: *Registry, entity: Entity, T: type) bool {
        return self.assure(T).has(entity);
    }

    pub fn get(self: *Registry, entity: Entity, T: type) T {
        return self.tryGet(entity, T).?;
    }

    pub fn tryGet(self: *Registry, entity: Entity, T: type) ?T {
        return (self.tryGetPtr(entity, T) orelse return null).*;
    }

    pub fn getPtr(self: *Registry, entity: Entity, T: type) *T {
        return self.tryGetPtr(entity, T).?;
    }

    pub fn tryGetPtr(self: *Registry, entity: Entity, T: type) ?*T {
        return self.assure(T).tryGet(entity);
    }

    pub fn raw(self: *Registry, T: type) []T {
        return self.assure(T).components();
    }

    pub fn sort(self: *Registry, T: type, lessFn: fn (T, T) bool) void {
        self.assure(T).sort(lessFn);
    }

    pub const remove = swapRemove;
    pub fn swapRemove(self: *Registry, entity: Entity, T: type) void {
        _ = self.assure(T).swapRemove(entity);
    }

    pub fn orderedRemove(self: *Registry, entity: Entity, T: type) void {
        self.assure(T).orderedRemove(entity);
    }

    pub fn alignRemove(self: *Registry, entity: Entity, types: anytype) void {
        var index: [types.len]Entity = undefined;
        inline for (types, &index) |T, *i| {
            var map = self.assure(T);
            i.* = map.swapRemove(entity);
        }
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    pub fn removeExcept(self: *Registry, entity: Entity, keep: anytype) void {
        var iterator = self.componentMap.iterator();
        while (iterator.next()) |entry| {
            var found = false;
            inline for (keep) |T| {
                if (entry.key_ptr.* == hashTypeId(T)) found = true;
            }
            if (found) continue;

            _ = entry.value_ptr.swapRemove(entity);
        }
    }

    pub fn removeAll(self: *Registry, entity: Entity) void {
        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |map| _ = map.swapRemove(entity);
    }

    pub fn clear(self: *Registry, T: type) void {
        self.assure(T).clear();
    }

    pub fn clearAll(self: *Registry, types: anytype) void {
        inline for (types) |T| self.clear(T);
    }

    pub fn query(self: *Registry, All: anytype) Query(All.len, 0) {
        return self.queryNone(All, .{});
    }

    // zig fmt: off
    pub fn queryNone(self: *Registry, All: anytype, None: anytype)
        Query(All.len, None.len) {
    // zig fmt: on
        comptime std.debug.assert(All.len > 0);

        var result: Query(All.len, None.len) = .{};
        var minCount: usize = invalid;
        inline for (All, &result.all) |T, *sparse| {
            const map = self.assure(T);
            sparse.* = map.sparse.items;
            if (map.dense.items.len < minCount) {
                minCount = map.dense.items.len;
                result.dense = map.dense.items;
            }
        }
        inline for (None, &result.none) |T, *sparse| {
            sparse.* = self.assure(T).sparse.items;
        }

        return result;
    }

    // zig fmt: off
    pub fn queryBy(self: *Registry, By: type, All: anytype,
        None: anytype) Query(All.len, None.len) {
    // zig fmt: on
        var result: Query(All.len, None.len) = .{};
        result.dense = self.assure(By).dense.items;

        inline for (All, &result.all) |T, *sparse| {
            sparse.* = self.assure(T).sparse.items;
        }
        inline for (None, &result.none) |T, *sparse| {
            sparse.* = self.assure(T).sparse.items;
        }
        return result;
    }
};

pub fn Query(comptime allLen: usize, comptime noneLen: usize) type {
    return struct {
        dense: []Entity = &.{},
        all: [allLen][]Entity = undefined,
        none: [noneLen][]Entity = undefined,
        index: Entity = 0,
        reversed: bool = false,

        pub fn reverse(self: @This()) @This() {
            var query = self;
            query.index = query.dense.len -| 1;
            query.reversed = true;
            return query;
        }

        pub fn next(self: *@This()) ?Entity {
            blk: while (self.index < self.dense.len) {
                const entity = self.dense[self.index];
                if (self.reversed) self.index -%= 1 else self.index += 1;
                for (self.all) |sparse| {
                    if (!hasEntity(sparse, entity)) continue :blk;
                }
                for (self.none) |sparse| {
                    if (hasEntity(sparse, entity)) continue :blk;
                }
                return entity;
            } else return null;
        }
    };
}

fn oom() noreturn {
    @panic("oom");
}
pub fn hashTypeId(T: type) TypeId {
    return comptime std.hash.Fnv1a_32.hash(@typeName(T));
}
