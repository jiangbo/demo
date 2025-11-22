const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Entity = struct {
    const Index = u16;
    const Version = u16;
    const invalid = std.math.maxInt(Index);

    index: Index,
    version: Version,
};

const Entities = struct {
    versions: std.ArrayList(Entity.Version) = .empty,
    deleted: std.ArrayList(Entity.Index) = .empty,

    pub fn deinit(self: *Entities, gpa: Allocator) void {
        self.versions.deinit(gpa);
        self.deleted.deinit(gpa);
    }

    pub fn create(self: *Entities, gpa: Allocator) !Entity {
        if (self.deleted.pop()) |index| {
            const version = self.versions.items[index];
            return .{ .index = index, .version = version };
        } else {
            const index = self.versions.items.len;
            if (index == Entity.invalid) @panic("max entity index");
            try self.versions.append(gpa, 0);
            return .{ .index = @intCast(index), .version = 0 };
        }
    }

    pub fn destroy(self: *Entities, gpa: Allocator, entity: Entity) !void {
        self.versions.items[entity.index] +%= 1;
        try self.deleted.append(gpa, entity.index);
    }

    pub fn isAlive(self: *const Entities, entity: Entity) bool {
        return entity.index < self.versions.items.len and
            self.versions.items[entity.index] == entity.version;
    }

    pub fn toEntity(self: *const Entities, index: Entity.Index) ?Entity {
        if (index < self.versions.items.len) {
            const version = self.versions.items[index];
            return .{ .index = index, .version = version };
        } else return null;
    }
};

pub fn SparseMap(Component: type) type {
    return struct {
        const isEmpty = @sizeOf(Component) == 0;
        const T = if (isEmpty) struct { _: u8 } else Component;

        const Self = @This();
        const Index = Entity.Index;
        const initCapacity = @max(1, std.atomic.cache_line / @sizeOf(T));

        sparse: std.ArrayList(u16) = .empty,
        dense: std.ArrayList(Index),
        valuePtr: [*]T,
        alignment: std.mem.Alignment = .of(T),
        valueSize: u32 = @sizeOf(T),

        pub fn init(gpa: Allocator) !Self {
            return Self{
                .dense = try .initCapacity(gpa, initCapacity),
                .valuePtr = (try gpa.alloc(T, initCapacity)).ptr,
            };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            const size = self.dense.capacity * self.valueSize;
            const slice = self.valuePtr[0..size];
            gpa.rawFree(slice, self.alignment, @returnAddress());
            self.dense.deinit(gpa);
            self.sparse.deinit(gpa);
        }

        pub fn add(self: *Self, gpa: Allocator, e: Index, v: T) !void {
            if (e >= self.sparse.items.len) {
                const count = e + 1 - self.sparse.items.len;
                try self.sparse.appendNTimes(gpa, Entity.invalid, count);
            }

            const index: u16 = @intCast(self.dense.items.len);
            const oldCapacity = self.dense.capacity;
            try self.dense.append(gpa, e);
            errdefer _ = self.dense.pop();

            if (oldCapacity != self.dense.capacity) {
                const slice = self.valuePtr[0..oldCapacity];
                const capacity = self.dense.capacity;
                self.valuePtr = (try gpa.realloc(slice, capacity)).ptr;
            }
            self.valuePtr[index] = v;
            self.sparse.items[e] = index;
        }

        pub fn tryGet(self: *const Self, entity: Index) ?*T {
            return if (self.has(entity)) self.get(entity) else null;
        }

        pub fn get(self: *const Self, entity: Index) *T {
            return &self.valuePtr[self.sparse.items[entity]];
        }

        pub fn has(self: *const Self, entity: Index) bool {
            return entity < self.sparse.items.len and
                self.sparse.items[entity] != Entity.invalid;
        }

        pub fn components(self: *const Self) []T {
            return self.valuePtr[0..self.dense.items.len];
        }

        pub fn remove(self: *Self, entity: Index) u16 {
            if (!self.has(entity)) return Entity.invalid;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = Entity.invalid;

            const moved = self.dense.pop().?;
            if (self.dense.items.len == index) return index;
            self.sparse.items[moved] = index;
            self.dense.items[index] = moved;

            const sz = self.valueSize;
            const src = self.valuePtr[sz * self.dense.items.len ..];
            @memcpy(self.valuePtr[sz * index ..][0..sz], src[0..sz]);
            return index;
        }

        pub fn sort(self: *Self, lessFn: fn (T, T) bool) void {
            if (self.dense.items.len <= 1 or isEmpty) return;

            const sparse = self.sparse.items;
            const v = self.valuePtr[0..self.dense.items.len];
            for (0..v.len) |i| {
                var j = i;
                while (j > 0 and lessFn(v[j], v[j - 1])) : (j -= 1) {
                    std.mem.swap(T, &v[j], &v[j - 1]);
                    const lhs = &self.dense.items[j];
                    const rhs = &self.dense.items[j - 1];
                    std.mem.swap(Index, lhs, rhs);
                    std.mem.swap(u16, &sparse[lhs.*], &sparse[rhs.*]);
                }
            }
        }

        pub fn clear(self: *Self) void {
            @memset(self.sparse.items, Entity.invalid);
            self.dense.clearRetainingCapacity();
        }
    };
}

fn DeinitList(T: type) type {
    return struct {
        list: std.ArrayList(T) = .empty,
        alignment: std.mem.Alignment = .of(T),
        valueSize: u32 = @sizeOf(T),

        fn deinit(self: *@This(), gpa: Allocator) void {
            if (self.list.capacity == 0) return;
            const size = self.list.capacity * self.valueSize;
            const slice = self.list.items.ptr[0..size];
            gpa.rawFree(slice, self.alignment, @returnAddress());
        }
    };
}

const TypeId = u64;
const Map = std.AutoHashMapUnmanaged;
pub const Registry = struct {
    allocator: Allocator,
    entities: Entities = .{},
    componentMap: Map(TypeId, [@sizeOf(SparseMap(u8))]u8) = .empty,

    identityMap: Map(TypeId, Entity) = .empty,
    contextMap: Map(TypeId, []u8) = .empty,
    eventMap: Map(TypeId, [@sizeOf(DeinitList(u8))]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.entities.deinit(self.allocator);
        self.identityMap.deinit(self.allocator);

        var it = self.contextMap.valueIterator();
        while (it.next()) |value| self.allocator.free(value.*);
        self.contextMap.deinit(self.allocator);

        var events = self.eventMap.valueIterator();
        while (events.next()) |value| {
            var list: *DeinitList(u8) = @ptrCast(@alignCast(value));
            list.deinit(self.allocator);
        }
        self.eventMap.deinit(self.allocator);

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var map: *SparseMap(u8) = @ptrCast(@alignCast(value));
            map.deinit(self.allocator);
        }
        self.componentMap.deinit(self.allocator);
    }

    pub fn createEntity(self: *Registry) Entity {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn toEntity(self: *const Registry, index: Entity.Index) ?Entity {
        return self.entities.toEntity(index);
    }

    pub fn validEntity(self: *const Registry, entity: Entity) bool {
        return self.entities.isAlive(entity);
    }

    pub fn destroyEntity(self: *Registry, entity: Entity) void {
        if (!self.validEntity(entity)) return;
        self.removeAll(entity);
        self.entities.destroy(self.allocator, entity) catch oom();
    }

    pub fn addContext(self: *Registry, value: anytype) void {
        const id = hashTypeId(@TypeOf(value));
        const v = self.contextMap.getOrPut(self.allocator, id) catch oom();
        if (!v.found_existing) {
            const size = @sizeOf(@TypeOf(value));
            v.value_ptr.* = self.allocator.alloc(u8, size) catch oom();
        }
        @memcpy(v.value_ptr.*, std.mem.asBytes(&value));
    }

    pub fn getContext(self: *Registry, T: type) ?T {
        return (self.getContextPtr(T) orelse return null).*;
    }

    pub fn getContextPtr(self: *Registry, T: type) ?*T {
        const ptr = self.contextMap.get(hashTypeId(T));
        return @ptrCast(ptr orelse return null);
    }

    pub fn removeContext(self: *Registry, T: type) void {
        const removed = self.contextMap.fetchRemove(hashTypeId(T));
        if (removed) |entry| self.allocator.free(entry.value);
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
        return e1.index == e.index and e1.version == e.version;
    }

    pub fn removeIdentity(self: *Registry, T: type) bool {
        return self.identityMap.remove(hashTypeId(T));
    }

    fn assureEvent(self: *Registry, T: type) *std.ArrayList(T) {
        const v = self.eventMap.getOrPut(self.allocator, //
            hashTypeId(T)) catch oom();
        if (!v.found_existing) {
            v.value_ptr.* = std.mem.toBytes(DeinitList(T){});
        }
        var list: *DeinitList(T) = @ptrCast(@alignCast(v.value_ptr));
        return &list.list;
    }

    pub fn addEvent(self: *Registry, value: anytype) void {
        var list = self.assureEvent(@TypeOf(value));
        list.append(self.allocator, value) catch oom();
    }

    pub fn getEvents(self: *Registry, T: type) []T {
        return self.assureEvent(T).items;
    }

    pub fn popEvent(self: *Registry, T: type) ?T {
        return self.assureEvent(T).pop();
    }

    pub fn clearEvent(self: *Registry, T: type) void {
        self.assureEvent(T).clearRetainingCapacity();
    }

    pub fn removeEvent(self: *Registry, T: type) bool {
        self.assureEvent(T).deinit(self.allocator);
        return self.eventMap.remove(hashTypeId(T));
    }

    fn assure(self: *Registry, T: type) *SparseMap(T) {
        const result = self.componentMap
            .getOrPut(self.allocator, hashTypeId(T)) catch oom();

        if (!result.found_existing) {
            const value = SparseMap(T).init(self.allocator);
            result.value_ptr.* = std.mem.toBytes(value catch oom());
        }
        return @ptrCast(@alignCast(result.value_ptr));
    }

    pub fn add(self: *Registry, entity: Entity, value: anytype) void {
        if (!self.validEntity(entity)) return;
        _ = self.doAdd(entity.index, value);
    }

    pub fn alignAdd(self: *Registry, e: Entity, comps: anytype) void {
        if (!self.validEntity(e)) return;
        var index: [comps.len]u16 = undefined;
        inline for (comps, &index) |v, *i| i.* = self.doAdd(e.index, v);
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    fn doAdd(self: *Registry, index: Entity.Index, value: anytype) u16 {
        var map = self.assure(@TypeOf(value));
        const isEmpty = @sizeOf(@TypeOf(value)) == 0;
        const dummy = if (isEmpty) undefined else value;
        if (map.tryGet(index)) |ptr| ptr.* = dummy else //
        map.add(self.allocator, index, dummy) catch oom();
        return map.sparse.items[index];
    }

    pub fn has(self: *Registry, entity: Entity, T: type) bool {
        if (!self.validEntity(entity)) return false;
        return self.assure(T).has(entity.index);
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
        if (!self.validEntity(entity)) return null;
        return self.assure(T).tryGet(entity.index);
    }

    pub fn raw(self: *Registry, T: type) []T {
        return self.assure(T).components();
    }

    pub fn indexes(self: *Registry, T: type) //
    struct { []Entity.Index, View(.{T}, .{}, false) } {
        return .{ self.assure(T).dense.items, self.view(.{T}) };
    }

    pub fn sort(self: *Registry, T: type, lessFn: fn (T, T) bool) void {
        self.assure(T).sort(lessFn);
    }

    pub fn remove(self: *Registry, entity: Entity, T: type) void {
        if (!self.validEntity(entity)) return;
        _ = self.assure(T).remove(entity.index);
    }

    pub fn alignRemove(self: *Registry, e: Entity, types: anytype) void {
        if (!self.validEntity(e)) return;
        var index: [types.len]u16 = undefined;
        inline for (types, &index) |T, *i|
            i.* = self.assure(T).remove(e.index);
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    pub fn removeAll(self: *Registry, entity: Entity) void {
        if (!self.validEntity(entity)) return;

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var map: *SparseMap(u8) = @ptrCast(@alignCast(value));
            _ = map.remove(entity.index);
        }
    }

    pub fn clear(self: *Registry, T: type) void {
        self.assure(T).clear();
    }

    pub fn clearAll(self: *Registry, types: anytype) void {
        inline for (types) |T| self.clear(T);
    }

    pub fn view(self: *Registry, types: anytype) View(types, .{}, .{}) {
        return self.viewOptions(types, .{}, .{});
    }

    // zig fmt: off
    pub fn viewOptions(self: *Registry, includes: anytype, excludes: anytype,
        comptime opt: ViewOptions) View(includes,excludes, opt) {
    // zig fmt: on
        return View(includes, excludes, opt).init(self);
    }
};

pub const ViewOptions = struct { reverse: bool = false };
pub fn View(includes: anytype, excludes: anytype, opt: ViewOptions) type {
    const Index = Entity.Index;
    return struct {
        reg: *Registry,
        slice: []Index = &.{},
        index: Index,

        pub fn init(r: *Registry) @This() {
            var slice = r.assure(includes[0]).dense.items;
            inline for (includes) |T| {
                const entities = r.assure(T).dense.items;
                if (entities.len < slice.len) slice = entities;
            }
            const index = if (opt.reverse) slice.len - 1 else 0;
            return .{ .reg = r, .slice = slice, .index = @intCast(index) };
        }

        pub fn next(self: *@This()) ?Index {
            blk: while (self.index < self.slice.len) {
                const entity = self.slice[self.index];
                if (opt.reverse) self.index -%= 1 else self.index += 1;

                inline for (includes) |T| {
                    if (!self.has(entity, T)) continue :blk;
                }
                inline for (excludes) |T| {
                    if (self.has(entity, T)) continue :blk;
                }
                return entity;
            } else return null;
        }

        pub fn get(self: *@This(), entity: Index, T: type) T {
            return self.getPtr(entity, T).*;
        }

        pub fn tryGet(self: *@This(), entity: Index, T: type) ?T {
            return (self.tryGetPtr(entity, T) orelse return null).*;
        }

        pub fn getPtr(self: *@This(), entity: Index, T: type) *T {
            return self.reg.assure(T).get(entity);
        }

        pub fn tryGetPtr(self: *@This(), entity: Index, T: type) ?*T {
            return self.reg.assure(T).tryGet(entity);
        }

        pub fn has(self: *const @This(), entity: Index, T: type) bool {
            return self.reg.assure(T).has(entity);
        }

        pub fn is(self: *const @This(), entity: Index, T: type) bool {
            const e = self.reg.getIdentityEntity(T) orelse return false;
            return e.index == entity;
        }

        pub fn add(self: *@This(), entity: Index, value: anytype) void {
            _ = self.reg.doAdd(entity, value);
        }

        pub fn remove(self: *@This(), entity: Index, T: type) void {
            self.reg.assure(T).remove(entity);
        }
    };
}

fn oom() noreturn {
    @panic("oom");
}
fn hashTypeId(T: type) TypeId {
    return comptime std.hash.Fnv1a_64.hash(@typeName(T));
}

var registry: Registry = undefined;
pub var w = &registry;
pub fn init(allocator: std.mem.Allocator) void {
    registry = Registry.init(allocator);
}

pub fn clear() void {
    registry.deinit();
    registry = Registry.init(registry.allocator);
}

pub fn deinit() void {
    registry.deinit();
}
