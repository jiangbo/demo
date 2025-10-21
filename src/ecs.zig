const std = @import("std");

const Allocator = std.mem.Allocator;

const Entity = struct {
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
        return entity.index < self.versions.items.len and
            self.versions.items[entity.index] == entity.version and
            (entity.version & alive) == alive;
    }
};

pub fn SparseSet(T: type) type {
    return struct {
        const Self = @This();
        const Index = Entity.Index;
        const initCapacity = @max(1, std.atomic.cache_line / @sizeOf(T));

        dense: std.ArrayList(Index),
        sparse: std.ArrayList(u32) = .empty,
        valuePtr: [*]T,
        alignment: std.mem.Alignment = .of(T),
        bytes: u32 = @sizeOf(T),

        pub fn init(gpa: Allocator) !Self {
            return Self{
                .dense = try .initCapacity(gpa, initCapacity),
                .valuePtr = (try gpa.alloc(T, initCapacity)).ptr,
            };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            const u8Ptr: [*]u8 = @ptrCast(@alignCast(self.valuePtr));
            const u8Slice = u8Ptr[0 .. self.dense.capacity * self.bytes];
            gpa.rawFree(u8Slice, self.alignment, @returnAddress());
            self.dense.deinit(gpa);
            self.sparse.deinit(gpa);
        }

        pub fn add(self: *Self, gpa: Allocator, entity: Index, value: T) !void {
            if (self.has(entity)) return;

            if (entity >= self.sparse.capacity) {
                try self.sparse.ensureTotalCapacity(gpa, entity + 1);
                self.sparse.expandToCapacity();
            }

            const index: u32 = @intCast(self.dense.items.len);
            const oldCapacity = self.dense.capacity;
            try self.dense.append(gpa, entity);
            if (oldCapacity != self.dense.capacity) {
                const slice = self.valuePtr[0..oldCapacity];
                const capacity = self.dense.capacity;
                self.valuePtr = (try gpa.realloc(slice, capacity)).ptr;
            }
            self.valuePtr[index] = value;
            self.sparse.items[entity] = index;
        }

        pub fn get(self: *Self, entity: Index) ?*T {
            if (!self.has(entity)) return null;
            return &self.valuePtr[self.sparse.items[entity]];
        }

        pub fn has(self: *Self, entity: Index) bool {
            if (entity >= self.sparse.items.len) return false;
            const index = self.sparse.items[entity];
            const items = self.dense.items;
            return index < items.len and items[index] == entity;
        }

        pub fn remove(self: *Self, entity: Index) void {
            if (!self.has(entity)) return;
            const last = self.dense.items[self.dense.items.len - 1];
            const index = self.sparse.items[entity];

            _ = self.dense.swapRemove(index);
            const u8Ptr: [*]u8 = @ptrCast(@alignCast(self.valuePtr));
            const u8Slice = u8Ptr[self.bytes * index ..][0..self.bytes];
            @memmove(u8Slice, u8Ptr[self.bytes * last ..][0..self.bytes]);
            self.sparse.items[last] = index;
        }

        pub fn clear(self: *Self) void {
            self.dense.clearRetainingCapacity();
        }
    };
}

const ComponentTypeId = u64;
const ComponentStorage = [@sizeOf(SparseSet(u8))]u8;
const Map = std.AutoHashMapUnmanaged;
pub const Registry = struct {
    allocator: Allocator,
    entities: Entities = .empty,
    componentMap: Map(ComponentTypeId, ComponentStorage) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.entities.deinit(self.allocator);
        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var set: *SparseSet(u8) = @ptrCast(@alignCast(value));
            set.deinit(self.allocator);
        }
        self.componentMap.deinit(self.allocator);
    }

    pub fn create(self: *Registry) Entity {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn destroy(self: *Registry, entity: Entity) void {
        std.debug.assert(self.valid(entity));
        self.removeAll(entity);
        self.entities.destroy(entity);
    }

    pub fn remove(self: *Registry, entity: Entity, comptime T: type) void {
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

    pub fn valid(self: *const Registry, entity: Entity) bool {
        return self.entities.isAlive(entity);
    }

    fn assure(self: *Registry, comptime T: type) *SparseSet(T) {
        const id = comptime std.hash.Fnv1a_64.hash(@typeName(T));

        const result = self.componentMap.getOrPut(self.allocator, id) catch oom();
        if (!result.found_existing) {
            const value = SparseSet(T).init(self.allocator);
            result.value_ptr.* = std.mem.toBytes(value catch oom());
        }
        return @ptrCast(@alignCast(result.value_ptr));
    }

    pub fn add(self: *Registry, entity: Entity, value: anytype) void {
        std.debug.assert(self.valid(entity));
        var set = self.assure(@TypeOf(value));
        set.add(self.allocator, entity.index, value) catch oom();
    }

    pub fn addTyped(self: *Registry, comptime T: type, e: Entity, v: T) void {
        self.add(e, v);
    }

    pub fn has(self: *Registry, entity: Entity, comptime T: type) bool {
        std.debug.assert(self.valid(entity));
        return self.assure(T).has(entity.index);
    }

    pub fn get(self: *Registry, entity: Entity, comptime T: type) ?T {
        return (self.getPtr(entity, T) orelse return null).*;
    }

    pub fn getPtr(self: *Registry, entity: Entity, comptime T: type) ?*T {
        std.debug.assert(self.valid(entity));
        return self.assure(T).get(entity.index);
    }
};

fn oom() noreturn {
    @panic("oom");
}
