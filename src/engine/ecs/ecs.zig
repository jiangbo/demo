const std = @import("std");

pub const c = @import("component.zig");
pub const s = @import("system.zig");

const Allocator = std.mem.Allocator;

pub const Entity = struct {
    pub const Index = u16;
    pub const Version = u16;

    index: Index,
    version: Version,
};

const Entities = struct {
    versions: std.ArrayList(Entity.Version) = .empty,
    deletedCount: usize = 0,

    pub const empty: Entities = .{};
    const alive = 1;

    pub fn deinit(self: *Entities, gpa: Allocator) void {
        self.versions.deinit(gpa);
    }

    pub fn create(self: *Entities, gpa: Allocator) !Entity {
        if (self.deletedCount == 0) {
            const idx: u16 = @intCast(self.versions.items.len);
            try self.versions.append(gpa, alive);
            return .{ .index = idx, .version = alive };
        }

        for (self.versions.items, 0..) |*version, i| {
            if (version.* & alive == 0) {
                version.* += 1;
                self.deletedCount -= 1;
                return .{ .index = @intCast(i), .version = version.* };
            }
        }

        unreachable;
    }

    pub fn destroy(self: *Entities, entity: Entity) void {
        if (!self.isAlive(entity)) return;
        self.versions.items[entity.index] += 1;
        self.deletedCount += 1;
    }

    pub fn isAlive(self: *const Entities, entity: Entity) bool {
        return entity.version & alive == alive and
            entity.index < self.versions.items.len and
            self.versions.items[entity.index] == entity.version;
    }

    pub fn getEntity(self: *const Entities, index: Entity.Index) ?Entity {
        if (index < self.versions.items.len) {
            const version = self.versions.items[index];
            if (version & alive == alive) {
                return .{ .index = index, .version = version };
            }
        }
        return null;
    }
};

pub fn SparseSet(T: type) type {
    return struct {
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
            const u8Ptr: [*]u8 = @ptrCast(@alignCast(self.valuePtr));
            const u8Slice = u8Ptr[0 .. self.dense.capacity * self.valueSize];
            gpa.rawFree(u8Slice, self.alignment, @returnAddress());
            self.dense.deinit(gpa);
            self.sparse.deinit(gpa);
        }

        pub fn add(self: *Self, gpa: Allocator, e: Index, v: T) !void {
            if (e >= self.sparse.capacity) {
                try self.sparse.ensureTotalCapacity(gpa, e + 1);
                self.sparse.expandToCapacity();
            }

            const index: u16 = @intCast(self.dense.items.len);
            const oldCapacity = self.dense.capacity;
            try self.dense.append(gpa, e);
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
            if (entity >= self.sparse.items.len) return false;
            const index = self.sparse.items[entity];
            const items = self.dense.items;
            return index < items.len and items[index] == entity;
        }

        pub fn raw(self: *const Self) []T {
            return self.valuePtr[0..self.dense.items.len];
        }

        pub fn remove(self: *Self, entity: Index) void {
            if (!self.has(entity)) return;

            const last = self.dense.items[self.dense.items.len - 1];
            const index = self.sparse.items[entity];

            _ = self.dense.swapRemove(index);
            const u8Ptr: [*]u8 = @ptrCast(@alignCast(self.valuePtr));
            const size = self.valueSize;
            const u8Slice = u8Ptr[size * index ..][0..size];
            @memmove(u8Slice, u8Ptr[size * last ..][0..size]);
            self.sparse.items[last] = index;
        }

        pub fn clear(self: *Self) void {
            self.dense.clearRetainingCapacity();
        }
    };
}

const TypeId = u64;
const ComponentStorage = [@sizeOf(SparseSet(u8))]u8;
const Map = std.AutoHashMapUnmanaged;
pub const Registry = struct {
    allocator: Allocator,
    entities: Entities = .empty,
    componentMap: Map(TypeId, ComponentStorage) = .empty,

    identityMap: Map(TypeId, Entity.Index) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.entities.deinit(self.allocator);
        self.identityMap.deinit(self.allocator);

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var set: *SparseSet(u8) = @ptrCast(@alignCast(value));
            set.deinit(self.allocator);
        }
        self.componentMap.deinit(self.allocator);
    }

    pub fn createEntity(self: *Registry) Entity {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn validEntity(self: *const Registry, entity: Entity) bool {
        return self.entities.isAlive(entity);
    }

    pub fn destroyEntity(self: *Registry, entity: Entity) void {
        std.debug.assert(self.validEntity(entity));
        self.removeAll(entity);
        self.entities.destroy(entity);
    }

    pub fn addIdentity(self: *Registry, e: Entity, T: type) void {
        std.debug.assert(@sizeOf(T) == 0);
        const id = hashTypeId(T);
        self.identityMap.put(self.allocator, id, e.index) catch oom();
    }

    pub fn getIdentity(self: *Registry, T: type) ?Entity {
        const index = self.identityMap.get(hashTypeId(T));
        return self.entities.getEntity(index orelse return null);
    }

    pub fn removeIdentity(self: *Registry, T: type) void {
        _ = self.identityMap.remove(hashTypeId(T));
    }

    pub fn remove(self: *Registry, entity: Entity, T: type) void {
        std.debug.assert(self.valid(entity));
        self.assure(T).remove(entity.index);
    }

    pub fn removeAll(self: *Registry, entity: Entity) void {
        std.debug.assert(self.valid(entity));

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var set: *SparseSet(u8) = @ptrCast(@alignCast(value));
            set.remove(entity.index);
        }
    }

    fn assure(self: *Registry, T: type) *SparseSet(T) {
        const result = self.componentMap
            .getOrPut(self.allocator, hashTypeId(T)) catch oom();

        if (!result.found_existing) {
            const value = SparseSet(T).init(self.allocator);
            result.value_ptr.* = std.mem.toBytes(value catch oom());
        }
        return @ptrCast(@alignCast(result.value_ptr));
    }

    pub fn add(self: *Registry, entity: Entity, value: anytype) void {
        std.debug.assert(self.validEntity(entity));
        var set = self.assure(@TypeOf(value));
        set.add(self.allocator, entity.index, value) catch oom();
    }

    pub fn addTyped(self: *Registry, T: type, entity: Entity, v: T) void {
        self.add(entity, v);
    }

    pub fn has(self: *Registry, entity: Entity, T: type) bool {
        std.debug.assert(self.validEntity(entity));
        return self.assure(T).has(entity.index);
    }

    pub fn raw(self: *Registry, T: type) []T {
        return self.assure(T).raw();
    }

    pub fn get(self: *Registry, entity: Entity, T: type) ?T {
        return (self.getPtr(entity, T) orelse return null).*;
    }

    pub fn getPtr(self: *Registry, entity: Entity, T: type) ?*T {
        std.debug.assert(self.validEntity(entity));
        return self.assure(T).tryGet(entity.index);
    }

    pub fn view(self: *Registry, includes: anytype) View(includes, .{}) {
        return self.viewExcludes(includes, .{});
    }

    // zig fmt: off
    pub fn viewExcludes(self: *Registry,  includes: anytype,
        excludes: anytype) View(includes, excludes) {
    // zig fmt: on
        return View(includes, excludes).init(self);
    }
};

pub fn View(includes: anytype, excludes: anytype) type {
    return struct {
        r: *Registry,
        slice: []Entity.Index = &.{},
        index: Entity.Index = 0,

        pub fn init(r: *Registry) @This() {
            var slice = r.assure(includes[0]).dense.items;
            inline for (includes) |T| {
                const entities = r.assure(T).dense.items;
                if (entities.len < slice.len) slice = entities;
            }
            return .{ .r = r, .slice = slice };
        }

        pub fn next(self: *@This()) ?Entity {
            if (self.index >= self.slice.len) return null;

            const e = self.slice[self.index];

            inline for (includes) |T| {
                if (!self.r.assure(T).has(e)) return null;
            }
            inline for (excludes) |T| {
                if (self.r.assure(T).has(e)) return null;
            }

            self.index += 1;
            return self.r.entities.getEntity(e);
        }

        pub fn get(self: *@This(), entity: Entity, T: type) T {
            return self.getPtr(entity, T).*;
        }

        pub fn getPtr(self: *@This(), entity: Entity, T: type) *T {
            return self.r.assure(T).get(entity.index);
        }

        pub fn has(self: *@This(), entity: Entity, T: type) bool {
            return self.r.assure(T).has(entity.index);
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

pub fn deinit() void {
    registry.deinit();
}
