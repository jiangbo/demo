# Monster Wars - Zig 游戏项目

## 项目概述

这是一个 Zig 编写的 2D 游戏项目，包含：
- **zhu 引擎**：自定义 2D 游戏引擎，位于 `src/engine/`
- **Monster Wars（怪物战争）**：塔防游戏，位于 `monster/`，是当前工作的主要目录

最低 Zig 版本：**0.15.1**

## 构建命令

```bash
# 原生构建
zig build
zig build run

# WebAssembly 构建
zig build -Dtarget=wasm32-emscripten --release=safe

# 编译着色器（修改 shader/*.glsl 后需要运行）
.\generate-shader.ps1
```

## 项目结构

```
demo/
├── build.zig              # 构建配置
├── build.zig.zon          # 依赖声明（sokol, stb, cimgui）
├── generate-shader.ps1    # GLSL → Zig 着色器编译脚本
│
├── src/engine/            # "zhu" 游戏引擎（作为模块 "zhu" 引入）
│   ├── root.zig           # 引擎入口，重新导出所有子系统
│   ├── window.zig         # 窗口和主循环
│   ├── gpu.zig            # GPU 抽象层
│   ├── batch.zig          # 2D 批量渲染系统
│   ├── graphics.zig       # 核心图形类型（Image, Color, Animation, Atlas）
│   ├── input.zig          # 键盘/鼠标输入
│   ├── assets.zig         # 资源加载和缓存
│   ├── audio.zig          # 音频播放系统
│   ├── math.zig           # 数学工具（Vector2/3/4, Rect, Matrix, Timer, PRNG）
│   ├── text.zig           # 位图字体文本渲染
│   ├── ecs.zig            # 实体组件系统框架
│   ├── c.zig              # C 互操作（stb_image, stb_vorbis）
│   ├── camera.zig         # 相机系统
│   ├── extend/font.zig    # SDF 字体渲染扩展
│   ├── extend/tiled.zig   # Tiled 地图编辑器格式解析
│   └── shader/            # GLSL 着色器源文件
│
└── monster/               # Monster Wars 塔防游戏（当前工作目录）
    ├── main.zig           # 应用入口点
    ├── scene.zig          # 主场景管理器
    ├── gui.zig            # ImGui 调试界面
    ├── map.zig            # Tiled 地图加载器
    ├── spawn.zig          # 实体生成系统
    ├── component.zig      # 所有 ECS 组件定义
    ├── system/            # ECS 系统（按执行顺序）
    │   ├── timer.zig      # 计时器事件处理
    │   ├── target.zig     # 目标选择系统
    │   ├── motion.zig     # 移动系统
    │   ├── state.zig      # 状态机
    │   ├── animation.zig  # 动画播放
    │   ├── projectile.zig # 投射物系统
    │   ├── attack.zig     # 攻击发起
    │   ├── health.zig     # 生命值/伤害系统
    │   └── facing.zig     # 朝向系统
    └── zon/               # 数据定义文件
        ├── enemy.zon      # 敌人类型定义
        ├── player.zon     # 玩家单位定义
        ├── projectile.zon # 投射物类型定义
        ├── atlas.zon      # 纹理图集定义
        ├── tile.zon       # 瓦片集定义
        └── level1.zon     # 关卡地图数据
```

## 引擎模块说明

| 模块 | 职责 |
|------|------|
| `window` | 窗口创建、主循环、增量时间平滑、文件 I/O |
| `gpu` | sokol-gfx 封装，渲染管线、缓冲区、着色器管理 |
| `batch` | 2D 精灵批量渲染，自动按纹理批次合并绘制调用 |
| `graphics` | Image（纹理+子区域）、Color、Animation、Atlas 类型定义 |
| `input` | 键盘/鼠标状态跟踪，支持 `pressed()`/`released()` 检测 |
| `assets` | sokol-fetch 异步资源加载，FNV-1a 哈希缓存 |
| `audio` | OGG 音乐流 + 音效混音播放 |
| `math` | Vector2/3/4、Rect、Matrix、Timer、PRNG |
| `text` | 位图字体 UTF-8 文本渲染（支持换行、对齐） |
| `ecs` | 稀疏集组件存储、实体版本管理、View 迭代、事件队列 |
| `camera` | 世界/窗口坐标转换，键盘控制，跟随模式 |
| `extend/tiled` | Tiled .tmj 地图解析，层/瓦片集/对象处理 |

**重要**：引擎通过 `const zhu = @import("zhu");` 引入，各子系统如 `zhu.window`、`zhu.batch`、`zhu.ecs` 使用。

## Monster Wars 架构

### ECS 系统（每帧按顺序执行）

1. **timer** — 处理冷却计时器，到期授予 `attack.Ready`
2. **target** — 目标选择（最近敌人或最低生命值友军）
3. **motion** — 移动系统，敌人沿路径图移动
4. **state** — 动画完成后状态转换（idle → walk）
5. **animation** — 动画帧更新，触发动作事件（hit/emit）
6. **projectile** — 投射物飞行（抛物线轨迹）
7. **attack** — 攻击发起，播放动画，设置冷却
8. **health** — 伤害计算，播放受击音效，绘制血条
9. **facing** — 根据目标/移动方向翻转精灵

### 组件定义

所有组件定义在 `monster/component.zig`，包括：
- 位置、精灵、计时器
- `Enemy` / `Player` / `Projectile` / `Dead`
- `Stats`（生命值/攻击/防御）
- `motion` 命名空间（Velocity, FaceLeft, Blocker, BlockBy）
- `attack` 命名空间（Target, Ready, Range, Lock, Healer, Injured, CoolDown, Ranged, Hit, Emit）
- `animation` 命名空间（Finished, Play）
- `audio` 命名空间（Hit, Emit）

### 数据文件

`.zon` 文件使用 Zig 的结构化数据格式定义游戏数据：
- `enemy.zon` — 4 种敌人类型（Slime, Wolf, Goblin, Dark Witch）
- `player.zon` — 4 种玩家单位（Warrior, Archer, Lancer, Witch）
- `projectile.zon` — 投射物类型（arrow, magic）

## 依赖

- **sokol** (sokol-zig) — 跨平台图形/音频/输入库
- **stb** — PNG 加载（stb_image）和 OGG 解码（stb_vorbis）
- **cimgui** — Dear ImGui C 绑定（调试 GUI）

## 注意事项

以下目录是**旧项目/工具**，不是当前工作范围，不需要关注：
- `dungeon/`、`shooter/`、`ghost/`、`sunny/` — 早期游戏原型
- `extend/` — 独立工具（图集打包、字体生成、Tiled 解析）
- `assets-00/` ~ `assets-04/` — 旧/备用资源集
- `src/main.zig` — ECS 测试程序（不是构建目标）
