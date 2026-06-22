# Tiny Farm - Zig 游戏项目

## 项目概述

这是一个 Zig 编写的 2D 游戏项目，包含：
- **zhu 引擎**：自定义 2D 游戏引擎，位于 `src/engine/`
- **Tiny Farm（迷你农场）**：2D 农场模拟游戏，位于 `farm/`，是当前工作的主要目录

最低 Zig 版本：**0.15.1**。

## 实现原则

- 强调，重要强调，特别强调：需要进行实现时，不要按照CPP的那套继承封装多态来。
- 不要抽象，需要简单和直接。不要兜底，不要防御，提前暴露错误，避免运行正常，逻辑错误。
- 方案和实际基于第一原理，从最佳实践考虑，不需要考虑修改范围和任何兼容性。

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

## 依赖

- **sokol** (sokol-zig) — 跨平台图形/音频/输入库
- **stb** — PNG 加载（stb_image）和 OGG 解码（stb_vorbis）
- **cimgui** — Dear ImGui C 绑定（调试 GUI）

## 后续实现约定

后续根据教程或参考项目实现功能时，必须遵循小步、可验证、易理解的方式：

- 每次先列出实现计划，用户确认后再编码。
- 每一步都要能独立编译、独立提交，不能留下编译错误，对新增的逻辑建立单元测试。
- 优先使用 Zig 风格的简单直接实现，避免照搬 C++ 的强封装、继承和复杂框架。

## 注意事项

以下目录是**旧项目/工具**，不是当前工作范围，不需要关注：
- `dungeon/`、`shooter/`、`ghost/`、`sunny/`、`monster/` — 早期游戏原型
- `extend/` — 独立工具（图集打包、字体生成、Tiled 解析）
- `assets-00/` ~ `assets-04/` — 旧/备用资源集
- `src/main.zig` — ECS 测试程序（不是构建目标）
