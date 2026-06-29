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
