const std = @import("std");

pub const Stage = struct {
    width: usize = 0,
    height: usize = 0,
    data: []u8 = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator, level: usize) Stage {
        return doInit(allocator, level) catch |e| {
            std.log.err("init stage error: {}", .{e});
            return Stage{};
        };
    }

    fn doInit(allocator: std.mem.Allocator, level: usize) !Stage {
        var buf: [30]u8 = undefined;
        const name = try std.fmt.bufPrint(&buf, "data/stage/{}.txt", .{level});

        std.log.info("load stage: {s}", .{name});
        const file = try std.fs.cwd().openFile(name, .{});
        defer file.close();

        const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        std.log.info("stage text: \n{s}", .{text});

        return parse(allocator, text);
    }

    fn parse(allocator: std.mem.Allocator, text: []u8) Stage {
        var stage = Stage{ .data = text, .allocator = allocator };

        var width: usize = 0;
        for (text) |char| {
            if (char == '\r') continue;
            width += 1;
            if (char != '\n') continue;

            if (stage.height != 0 and stage.width != width) {
                @panic("stage width error");
            }
            stage.width = width;
            width = 0;
            stage.height += 1;
        }

        return stage;
    }

    pub fn isValid(self: Stage) bool {
        return self.width != 0 and self.height != 0;
    }

    pub fn deinit(self: Stage) void {
        if (self.isValid()) self.allocator.free(self.data);
    }
};
