# 代办事项

## 构建命令

```sh
zig build -Dtarget=wasm32-emscripten --release=safe
```

## 生成字体

```sh
msdf-atlas-gen.exe -font .\SourceHanSansSC-Medium.otf -yorigin top -charset .\allchars.txt -json font.json -imageout font.png
```

```sh
msdf-atlas-gen.exe -font .\VonwaonBitmap-12px.ttf -yorigin top -chars [0,65536] -json font.json -imageout font.png -type softmask -size 12 -dimensions 1100 1100
```

```sh
texturePacker --sheet assets/atlas.png --format json-array --data assets/atlas.json --texturepath assets --ignore-files *font.png --force-publish --padding 2 --trim-sprite-names --disable-rotation --trim-mode None .\assets-02\
```

## ASTC 纹理支持

```zig
const AstcHeader = extern struct {
    magic: [4]u8,
    block_x: u8,
    block_y: u8,
    block_z: u8,
    dim_x: [3]u8,
    dim_y: [3]u8,
    dim_z: [3]u8,

    pub fn init(data: []const u8) AstcHeader {
        var stream = std.io.fixedBufferStream(data);
        const reader = stream.reader();
        return reader.readStruct(AstcHeader) catch unreachable;
    }
};

fn init() void {
    const allocator = context.allocator;
    cache.init(allocator);

    context.camera = gfx.Camera.init(context.width, context.height);
    // _ = cache.TextureCache.get("assets/player.bmp").?;

    const playerAstc: []const u8 = @embedFile("player.astc");
    const header = AstcHeader.init(playerAstc);

    std.log.info("astc header: {any}", .{header});
    const sk = @import("sokol");
    const image = sk.gfx.allocImage();

    sk.gfx.initImage(image, .{
        .width = 96,
        .height = 192,
        .pixel_format = .ASTC_4x4_RGBA,
        .data = init: {
            var imageData = sk.gfx.ImageData{};
            imageData.subimage[0][0] = sk.gfx.asRange(playerAstc[@sizeOf(AstcHeader)..]);
            break :init imageData;
        },
    });

    texture = .{
        .width = 96,
        .height = 192,
        .value = image,
    };

    context.textureSampler = gfx.Sampler.liner();

    context.batchBuffer = gfx.BatchBuffer.init(allocator) catch unreachable;
}
```
