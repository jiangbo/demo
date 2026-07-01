# 项目记录

## 构建命令

```powershell
zig build -Dtarget=wasm32-emscripten --release=safe
```

## 字体生成

生成 `0` 到 `30000` 范围的字体贴图：

```powershell
msdf-atlas-gen.exe -font assets\fonts\VonwaonBitmap-16px.ttf -yorigin top -chars "[0,30000]" -json assets\fonts\font-0.json -imageout assets\fonts\font-0.png -type softmask -size 16 -dimensions 1024 1024
```

生成 `30000` 到 `100000` 范围的字体贴图：

```powershell
msdf-atlas-gen.exe -font assets\fonts\VonwaonBitmap-16px.ttf -yorigin top -chars "[30000,100000]" -json assets\fonts\font-1.json -imageout assets\fonts\font-1.png -type softmask -size 16 -dimensions 1024 1024
```

## 字体转换

```powershell
zig run .\extend\font\main.zig -- assets\fonts
```

输出文件：

```text
assets\fonts\font.zon
```

## 图集生成

```powershell
bun atlas.js
```

## 图集转换

```powershell
zig run .\extend\atlas\main.zig -- C:\workspace\assets\dist\atlas\atlas-0.json
```

复制图集图片到游戏资源目录：

```powershell
Copy-Item C:\workspace\assets\dist\atlas\atlas-*.png C:\workspace\demo\assets\atlas\
```

输出文件：

```text
C:\workspace\assets\dist\atlas\atlas.zon
```

## Tiled 地图转换

以下命令都从项目根目录运行。

先根据 `assets\maps\tileset` 下的 `.tsj` 生成全局 `tileSet.zon`：

```powershell
zig run .\extend\tiled\tileSet.zig -- assets\maps\tileset
```

输出文件：

```text
assets\maps\tileset\tileSet.zon
```

再根据 `tileSet.zon` 的数组顺序生成地图。生成器会把 tileset 序号写入
gid 高 8 位，低 24 位保留 local tile id。

```powershell
zig run .\extend\tiled\main.zig -- assets\maps\town.tmj
zig run .\extend\tiled\main.zig -- assets\maps\school.tmj
zig run .\extend\tiled\main.zig -- assets\maps\home_exterior.tmj
zig run .\extend\tiled\main.zig -- assets\maps\home_interior.tmj
```

批量生成可以使用：

```powershell
foreach ($map in rg --files assets/maps -g "*.tmj") {
    zig run .\extend\tiled\main.zig -- $map
}
```

输出文件：

```text
assets\zon\town.zon
assets\zon\school.zon
assets\zon\home_exterior.zon
assets\zon\home_interior.zon
```

`assets` 目录当前被 `.gitignore` 忽略，生成文件不会出现在普通
`git status` 里。

确认生成结果后，移动到项目使用的 ZON 目录：

```powershell
Move-Item assets\zon\town.zon farm\zon\map\town.zon -Force
Move-Item assets\zon\school.zon farm\zon\map\school.zon -Force
Move-Item assets\zon\home_exterior.zon farm\zon\map\exterior.zon -Force
Move-Item assets\zon\home_interior.zon farm\zon\map\interior.zon -Force
Move-Item assets\maps\tileset\tileSet.zon farm\zon\map\tileSet.zon -Force
```

项目内地图文件名使用 `exterior.zon` 和 `interior.zon`，不要带 `home_`
前缀。运行时代码默认读取 `farm\zon\map\tileSet.zon`。

### 地图人工补充

重新生成地图后，只补充非 `.data` 字段。不要从旧地图复制 `.data`，也不要
复制旧 object 的 `.gid`，因为旧文件还是旧的 gid 编码。

对比关系：

```text
farm\zon\map\town.zon      -> assets\zon\town.zon
farm\zon\map\school.zon    -> assets\zon\school.zon
farm\zon\map\exterior.zon  -> assets\zon\home_exterior.zon
farm\zon\map\interior.zon  -> assets\zon\home_interior.zon
```

需要补充的内容：

- `town.zon`：补回 `town -> exterior` 的 `map_trigger`，`self_id = 2`，
  `start_offset = "right"`，`target_id = 2`，`target_map = "exterior"`。
- `home_exterior.zon`：补回 `exterior -> town` 的 `map_trigger`，
  `self_id = 2`，`start_offset = "left"`，`target_id = 2`，
  `target_map = "town"`。
- `home_exterior.zon`：把进屋触发器的 `target_map` 改为 `"interior"`，
  位置保持旧文件的 `.position = .{ .x = 317.16666, .y = 120 }`。
- `home_interior.zon`：把出屋触发器的 `target_map` 改为 `"exterior"`。
- `home_exterior.zon`：箱子物品属性使用运行时枚举名
  `potatoSeed` 和 `strawberrySeed`，不要使用 Tiled 生成的 snake_case 名。

`school.zon` 当前没有额外人工补充项。
