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
texturePacker --sheet assets/atlas.png --format json-array --data assets/atlas.json --texturepath assets --ignore-files *font.png --force-publish --padding 1 --disable-rotation --trim-mode None .\assets-02\
```