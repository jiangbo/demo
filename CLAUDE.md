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
    ├── hud.zig            # HUD 肖像条与出击准备渲染
    ├── context.zig        # 关卡全局状态（cost/selected/统计）
    ├── spawn.zig          # 实体生成系统
    ├── component.zig      # 所有 ECS 组件定义
    ├── system/            # ECS 系统（按执行顺序）
    │   ├── timer.zig      # 计时器事件处理
    │   ├── target.zig     # 目标选择系统
    │   ├── skill.zig      # 技能冷却、施放、Buff 与显示
    │   ├── motion.zig     # 移动系统
    │   ├── state.zig      # 状态机
    │   ├── animation.zig  # 动画播放
    │   ├── projectile.zig # 投射物系统
    │   ├── attack.zig     # 攻击发起
    │   ├── health.zig     # 生命值/伤害系统
    │   ├── death.zig      # 死亡与特效清理
    │   ├── facing.zig     # 朝向系统
    │   └── selection.zig  # 鼠标悬停、选中和范围显示
    └── zon/               # 数据定义文件
        ├── enemy.zon      # 敌人类型定义
        ├── player.zon     # 玩家单位定义
        ├── projectile.zon # 投射物类型定义
        ├── effect.zon     # 特效定义（治疗、技能提示等）
        ├── atlas.zon      # 纹理图集定义
        ├── ui.zon         # HUD/UI 资源定义
        ├── levels.zon     # 波次与关卡定义
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

每帧先处理输入选择和部署，再推进生成、地图和 ECS 系统：

1. **selection** — 更新鼠标悬停、选中单位和 `ShowRange`
2. **spawn.update** — 按波次生成敌人
3. **map.update** — 更新地图上的动画等状态
4. **timer** — 处理攻击冷却计时器，到期授予 `attack.Ready`
5. **skill** — 推进技能冷却/持续时间，处理施放、Buff、COST 恢复和头顶显示
6. **target** — 目标选择（最近敌人或最低生命值友军）
7. **motion** — 移动系统，敌人沿路径图移动
8. **state** — 动画完成后的状态转换和一次性特效结束处理
9. **projectile** — 投射物飞行（抛物线轨迹）
10. **attack** — 攻击发起，播放动画，设置冷却
11. **health** — 伤害/治疗结算，播放受击音效，绘制血条，设置 `Dead`
12. **death** — 死亡处理：释放阻挡、生成敌人死亡特效、销毁 Dead 实体
13. **facing** — 根据目标/移动方向翻转精灵
14. **animation** — 动画帧更新，触发动作事件（hit/emit）

`scene.update()` 末尾还会处理到达终点的敌人事件，扣除基地生命值并销毁对应实体。

### 组件定义

所有组件定义在 `monster/component.zig`，包括：
- 位置、精灵、计时器
- `Enemy` / `Player` / `Projectile` / `Dead` / `OneShotEffect`
- `EnemyEnum` / `PlayerEnum` / `SkillEnum` / `EffectEnum` — 数据类型枚举
- `DeathEffectSource` — 敌人死亡特效需要的图集、帧尺寸、偏移和动画
- `Stats`（生命值/攻击/防御）
- `motion` 命名空间（Velocity, FaceLeft, Blocker, BlockBy）
- `attack` 命名空间（Target, Ready, Range, Lock, Healer, Injured, CoolDown, Ranged, Hit, Emit）
- `skill` 命名空间（Skill, Buff, Ready, Active, Passive, Cast, Display, CostRecovery）
- `animation` 命名空间（Finished, Play）
- `audio` 命名空间（Hit, Emit）

### 技能系统（system/skill.zig）

- 玩家单位的技能数据直接定义在 `player.zon` 的模板里，不单独维护 `skill.zon`。
- 主动技能部署后初始冷却为 `coolDown / 2`；冷却完成后添加 `skill.Ready`。
- ImGui 按钮或快捷键 `S` 添加 `skill.Cast`，技能系统消费后进入 `skill.Active`。
- Buff 直接修改 `Stats`、`attack.Range` 和 `attack.CoolDown`，持续结束后按倍率恢复。
- 被动技能部署后直接添加 `skill.Passive`、`skill.Active` 和可选 `skill.CostRecovery`。
- `skill.CostRecovery` 每帧给 `ctx.cost` 增加额外恢复量。
- 技能头顶显示通过 `spawn.skillDisplay()` 创建循环特效实体：
  - `skill.Ready` 显示 `EffectEnum.ready`
  - `skill.Active` 显示 `EffectEnum.active`
  - 状态变化或 owner 失效时销毁旧显示实体

### 特效与死亡处理

- 通用特效数据定义在 `monster/zon/effect.zon`，包含图片路径、源区域、绘制大小、偏移和动画帧。
- `spawn.effect()` 创建一次性特效实体，并添加 `OneShotEffect` 标签。
- `spawn.skillDisplay()` 创建循环特效实体，不添加 `OneShotEffect`，由技能系统按状态销毁。
- `spawn.enemyDeathEffect()` 使用敌人的 `DeathEffectSource` 创建独立死亡特效实体。
- `state.zig` 看到 `animation.Finished + OneShotEffect` 时添加 `Dead`。
- `death.zig` 统一销毁 `Dead` 实体；敌人本体死亡时会释放阻挡、统计击杀、生成死亡特效并立即销毁本体。
- 当前不再使用“把敌人本体改成 Ghost 播放死亡动画”的流程。

### HUD（hud.zig）

- 底部肖像条，显示可出击单位、职业图标、消耗费用
- `update()` 检测悬停音效和左键点击选择，选中后直接 return 跳过后续逻辑
- `drawPrepare(playerEnum)` 绘制跟随鼠标的准备单位精灵，远程单位额外渲染攻击范围圈
- `ctx.selected != null` 时肖像条禁用交互

### 关卡状态（context.zig）

- 模块级全局变量管理关卡状态：`cost`、`homeHealth`、`selected` 等
- `update(delta)` 负责基础 COST 自增长；技能系统负责额外 COST 恢复
- `spendSelected()` 扣费、移除已部署单位槽位并清除选择状态
- `isGameOver()` / `isLevelClear()` 判定函数
- 不使用 getter/setter，直接读写公开字段

### 数据文件

`.zon` 文件使用 Zig 的结构化数据格式定义游戏数据：
- `enemy.zon` — 4 种敌人类型（Slime, Wolf, Goblin, Dark Witch）
- `player.zon` — 4 种玩家单位（Warrior, Archer, Lancer, Witch）
- `projectile.zon` — 投射物类型（arrow, magic）
- `effect.zon` — 一次性特效与技能显示特效（heal, active, ready）
- `levels.zon` — 关卡波次、准备时间和敌人等级/稀有度
- `context.zon` — 初始关卡、点数和玩家出击单位列表
- `ui.zon` — HUD 肖像、职业图标和边框资源

## 依赖

- **sokol** (sokol-zig) — 跨平台图形/音频/输入库
- **stb** — PNG 加载（stb_image）和 OGG 解码（stb_vorbis）
- **cimgui** — Dear ImGui C 绑定（调试 GUI）

## 后续实现约定

后续根据教程或参考项目实现功能时，必须遵循小步、可验证、易理解的方式：

- 每次先列出实现计划，用户确认后再编码。
- 循序渐进地实现功能，不一次性完成整节或多节内容。
- 每一步都要能独立编译、独立提交，不能留下编译错误。
- 单步代码量优先控制在约 100 行，最多不超过 300 行。
- 如果需要依赖后续逻辑，可以先用占位、mock、空实现或固定值保持当前步骤完整。
- 优先使用 Zig 风格的简单直接实现，避免照搬 C++ 的强封装、继承和复杂框架。
- 每步计划需要说明目标、修改文件、新增命名、实现方式、占位策略、验证方式和本步不做的内容。
- 编码后至少运行 `zig build` 验证。
- 代码中的日志默认使用英文；只有用户明确要求时才写中文日志。
- 每行代码长度不超过 88 个字符。

## 博客写作约定

后续编写博客时，遵循已有文章的编号、标题和章节格式：

- 写作前先读取相邻编号或同系列近期文章，保持格式、语气和代码展示风格一致。
- 参考部分沿用用户提供或系列固定的主要参考资料，不额外加入临时查阅资料。
- `想法` 是用户自己的记录，默认保留空白，不代写。
- `附录` 默认留空；只在需要补充源码链接、错误解决方案、额外参考等内容时填写。
- 正文聚焦本次实现的关键代码和关键思路，不写过细的 import、init/update 调用等简单过程。
- 二级标题用文件名（不带目录前缀），下面分段说明该文件的修改。
- 说明以简单为主，不需要详细描述；必要时在代码中加注释辅助说明。
- 不写与其他语言或参考实现的对比说明，除非用户明确要求。
- 段落要紧凑，避免一句话单独空一行；相关句子合并成自然段。
- 效果部分简洁概括，不要展开说明；需要图片引用，文件名使用”项目名称 + 序号.png”的形式，图片由用户自行提供。

## 注意事项

以下目录是**旧项目/工具**，不是当前工作范围，不需要关注：
- `dungeon/`、`shooter/`、`ghost/`、`sunny/` — 早期游戏原型
- `extend/` — 独立工具（图集打包、字体生成、Tiled 解析）
- `assets-00/` ~ `assets-04/` — 旧/备用资源集
- `src/main.zig` — ECS 测试程序（不是构建目标）
