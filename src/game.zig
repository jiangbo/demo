const std = @import("std");
const zlm = @import("zlm");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const resource = @import("resource.zig");
const SpriteRenderer = @import("renderer.zig").SpriteRenderer;
const Sprite = @import("sprite.zig").Sprite;

const Allocator = std.mem.Allocator;
const GameState = enum { active, menu, win };
pub const Game = struct {
    state: GameState = .active,
    width: f32 = 0,
    height: f32 = 0,
    keys: [1024]bool = [_]bool{false} ** 1024,
    spriteRenderer: SpriteRenderer = undefined,
    levels: [4]GameLevel = undefined,
    level: usize = 1,

    pub fn init(self: *Game, allocator: std.mem.Allocator) !void {
        resource.init(allocator);

        const vs: [:0]const u8 = @embedFile("shader/vertex.glsl");
        const fs: [:0]const u8 = @embedFile("shader/fragment.glsl");
        const shader = resource.loadShader(.shader, vs, fs);

        const projection = zlm.Mat4.createOrthogonal(0, self.width, self.height, 0, -1, 1);
        shader.setUniformMatrix4fv("projection", &projection.fields[0][0]);
        shader.setUniform1i("image", 0);

        self.spriteRenderer = SpriteRenderer{ .shader = shader };
        self.spriteRenderer.initRenderData();

        _ = try resource.loadTexture(.face, "assets/awesomeface.png");
        _ = try resource.loadTexture(.block, "assets/block.png");
        _ = try resource.loadTexture(.solid_block, "assets/block_solid.png");
        _ = try resource.loadTexture(.background, "assets/background.jpg");

        //  GameLevel one; one.Load("levels/one.lvl", this->Width, this->Height * 0.5);
        //     GameLevel two; two.Load("levels/two.lvl", this->Width, this->Height * 0.5);
        //     GameLevel three; three.Load("levels/three.lvl", this->Width, this->Height * 0.5);
        //     GameLevel four; four.Load("levels/four.lvl", this->Width, this->Height * 0.5);

        self.levels[0] = GameLevel{ .width = self.width, .height = self.height };
        try self.levels[0].init(allocator, "assets/lv1.json");
        // self.levels[1] = GameLevel{ .width = self.width, .height = self.height };
        // try self.levels[1].init(allocator, "assets/lv2.json");
        // self.levels[2] = GameLevel{ .width = self.width, .height = self.height };
        // try self.levels[2].init(allocator, "assets/lv3.json");
        // self.levels[3] = GameLevel{ .width = self.width, .height = self.height };
        // try self.levels[3].init(allocator, "assets/lv4.json");
    }
    // game loop
    pub fn processInput(self: Game, deltaTime: f64) void {
        _ = deltaTime;
        _ = self;
    }
    pub fn update(self: Game, deltaTime: f64) void {
        _ = self;
        _ = deltaTime;
    }

    pub fn render(self: Game) void {
        if (self.state == .active) {
            const options = Sprite{
                .texture = resource.getTexture(.face),
                .position = zlm.Vec2.new(200, 200),
                .size = zlm.Vec2.new(300, 400),
                .rotate = 45,
                .color = zlm.Vec3.new(0, 1, 0),
            };

            self.spriteRenderer.draw(options);

            // const background = resource.getTexture(.face);
            // self.spriteRenderer.draw(Sprite{
            //     .texture = background,
            //     .size = zlm.Vec2.new(self.width, self.height),
            // });

            // self.levels[self.level].draw(self.spriteRenderer);
        }
    }

    pub fn deinit(self: Game) void {
        for (self.levels) |level| level.deinit();
        resource.deinit();
    }
};

const GameLevel = struct {
    bricks: std.ArrayList(Sprite) = undefined,
    width: f32 = 0,
    height: f32 = 0,

    fn draw(self: GameLevel, renderer: SpriteRenderer) void {
        for (self.bricks.items) |brick| {
            renderer.draw(brick);
        }
    }

    fn deinit(self: GameLevel) void {
        self.bricks.deinit();
    }
    // fn isCompleted() bool{
    //     return false;
    // };
    fn init(self: *GameLevel, allocator: std.mem.Allocator, path: []const u8) !void {
        try self.doInit(allocator, path);
    }

    fn doInit(self: *GameLevel, allocator: std.mem.Allocator, path: []const u8) !void {
        std.log.info("load level: {s}", .{path});
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const text = try file.readToEndAlloc(allocator, 1024 * 4);
        defer allocator.free(text);

        const parsed = try std.json.parseFromSlice(FileLevel, allocator, text, .{});
        defer parsed.deinit();

        try self.parse(allocator, parsed.value);
    }

    fn parse(self: *GameLevel, allocator: std.mem.Allocator, level: FileLevel) !void {
        const size = level.width * level.height;
        self.bricks = try std.ArrayList(Sprite).initCapacity(allocator, size);

        const unitWidth = self.width / @as(f32, @floatFromInt(level.width));
        const unitHeight = self.height / @as(f32, @floatFromInt(level.height));

        for (level.level, 0..) |unit, index| {
            const x: f32 = @floatFromInt(index % level.width);
            const y: f32 = @floatFromInt(index / level.width);
            if (unit == 1) {
                return try self.bricks.append(Sprite{
                    .position = zlm.Vec2.new(x * unitWidth, y * unitHeight),
                    .size = zlm.Vec2.new(unitWidth, unitHeight),
                    .texture = resource.getTexture(.solid_block),
                    .solid = true,
                });
            }

            const color = switch (unit) {
                2 => zlm.Vec3.new(0.2, 0.6, 1.0),
                3 => zlm.Vec3.new(0.0, 0.7, 0.0),
                4 => zlm.Vec3.new(0.8, 0.8, 0.4),
                5 => zlm.Vec3.new(1.0, 0.5, 0.0),
                else => zlm.Vec3.new(1.0, 1.0, 1.0),
            };

            const sprite = Sprite{
                .position = zlm.Vec2.new(x * unitWidth, y * unitHeight),
                .size = zlm.Vec2.new(unitWidth, unitHeight),
                .texture = resource.getTexture(.block),
                .color = color,
            };
            try self.bricks.append(sprite);
        }
    }
};

const FileLevel = struct {
    level: []const u8,
    width: usize,
    height: usize,
};
