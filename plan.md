教程路径：C:\workspace\github\cppgamedev\backend\src\courses\OpenGL与迷你农场
CPP 源码路径：C:\workspace\github\TinyFarm

## 实现原则

这份计划不再按原教程章节推进，而是按“每节实现一个能在屏幕上看到的功能点”推进。每节都要能独立编译、独立验证；如果某个可见功能依赖前置系统，就先实现该功能需要的最小系统，不提前铺完整框架。

每节完成后至少运行：

```bash
zig build
```

涉及纯逻辑或组件规则时再运行：

```bash
zig build test
```

## 功能实现计划

- [x] 31-对话气泡
  - 可见效果：靠近 NPC 按键弹出对话框。
  - 需要系统：InteractionSystem、DialogueSystem、UI 文本。
  - 参考源码：`game/system/dialogue_system.*`、`game/ui/dialogue_bubble.*`

- [x] 32-游戏时间与时钟 UI
  - 可见效果：屏幕显示时间，时间会推进。
  - 需要系统：GameTime、TimeSystem、TimeClockUI。
  - 参考源码：`game/data/game_time.*`、`game/ui/time_clock_ui.*`

- [ ] 33-昼夜颜色变化
  - 可见效果：白天/夜晚画面色调明显变化。
  - 需要系统：DayNightSystem、环境色参数、Renderer tint/overlay 最小实现。
  - 参考源码：`game/system/day_night_system.*`、`assets/data/light_config.json`

- [ ] 34-夜间灯光占位效果
  - 可见效果：夜晚路灯/窗户附近有简单亮色覆盖或光圈。
  - 需要系统：PointLight/Emissive 组件、LightToggleSystem、简化光照绘制。
  - 参考源码：`engine/component/light_component.h`、`light_system.*`

- [ ] 35-音效反馈
  - 可见效果：锄地、浇水、拾取时播放声音。
  - 需要系统：AudioPlayer、AudioManager、ActionSoundSystem。
  - 参考源码：`engine/audio/*`、`game/system/action_sound_system.*`

- [ ] 36-暂停菜单
  - 可见效果：按键打开暂停菜单，游戏更新暂停。
  - 需要系统：Scene stack 最小扩展、UI 按钮。
  - 参考源码：`game/scene/pause_menu_scene.*`

- [ ] 37-存档与读档
  - 可见效果：保存后重启/切场景能恢复位置、背包、农田状态。
  - 需要系统：SaveData、WorldState、SaveService 最小版。
  - 参考源码：`game/save/*`、`game/world/world_state.*`

- [ ] 38-标题存档选择
  - 可见效果：标题界面显示存档槽，点击进入对应存档。
  - 需要系统：SaveSlotSummary、SaveSlotSelectScene、按钮 UI。
  - 参考源码：`game/scene/save_slot_select_scene.*`

- [ ] 39-收尾：调试面板与体验整理
  - 可见效果：Debug 面板能查看玩家、地图、背包、时间、渲染统计。
  - 需要系统：各调试面板入口统一，清理临时 mock。
  - 参考源码：`game/debug/*`、`engine/debug/panels/*`

## 待后续完成

遇到未实现跳过的功能，记录到这里。

- 29-地图切换：C++ `MapTransitionSystem` 支持地图边缘出界切换；Zig 本步先只做
  Tiled `map_trigger` 门口切换。
- 29-地图切换：C++ `WorldState` 会解析 Tiled `.world` 文件来得到地图布局和邻接关系；
  Zig 本步先用现有 `maps` 表和 `target_map` 属性直接切换。
- 29-地图切换：C++ 切换时有 `UIScreenFade` 淡入淡出和 `ActionLockedTag`
  行动锁；Zig 本步先瞬时切换。
- 29-地图切换：C++ 会通过碰撞解析寻找安全出生点；Zig 本步先按
  `start_offset` 计算固定落点。
- 29-地图切换：C++ `MapManager` 会按 `MapId` 卸载地图实体并保留玩家；
  Zig 本步先做最小清理，不实现完整地图作用域组件体系。
- 29-地图切换：C++ 有地图快照、离线推进、资源节点和宝箱恢复；Zig 本步不保存
  跨地图动态状态。
- 29-地图切换：C++ 支持邻接地图预加载、外部地图注册、环境色覆盖和相机缩放配置；
  Zig 本步只更新当前地图、碰撞和相机边界。
- 30-NPC 显示与简单漫游：C++ `AnimalBehaviorSystem` 支持睡觉、进食和时间判断；
  Zig 本步先只做显示和随机漫游。
- 30-NPC 显示与简单漫游：C++ 会从 `animal_blueprint.json` 读取动物蓝图；
  Zig 本步先用 `farm.zon` 中的静态配置。
- 30-NPC 显示与简单漫游：C++ 动物有叫声音效和动作音效；
  Zig 本步不接入音频。
- 30-NPC 显示与简单漫游：C++ NPC 可挂对话组件；
  Zig 本步不做对话交互，留到 31。
- 30-NPC 显示与简单漫游：C++ 后续可接空间索引、寻路和更完整的行为状态；
  Zig 本步只在出生点半径内选随机目标，碰撞后放弃当前目标。
- 31-对话气泡：C++ 使用事件总线（InteractRequest / DialogueShowEvent 等）解耦系统；
  Zig 本步保留 ECS 事件队列，用 DialogStart/Advance/Close 连接交互和显示。
- 31-对话气泡：C++ 使用 SpatialIndexManager 做朝向方向的空间探测；
  Zig 本步遍历所有 NPC 用距离判断。
- 31-对话气泡：C++ 有 3 个气泡频道（对话/通知/物品提示）；
  Zig 本步只做对话频道。
- 31-对话气泡：C++ 从 JSON 运行时加载对话脚本；
  Zig 本步用代码内编译时常量。
- 31-对话气泡：C++ DialogueBubble 使用九宫格图片背景；
  Zig 本步用半透明矩形背景。
- 31-对话气泡：C++ 支持说话者名称显示和打字机逐字效果；
  Zig 本步不实现。
- 31-对话气泡：C++ 对话结束后有冷却计时器防止连续误触；
  Zig 不需要，因为 `pressed()` 只在按键按下帧触发一次，不会误触。
- 32-游戏时间与时钟 UI：C++ 从 `game_time_config.json` 运行时加载配置；
  Zig 本步先直接扩展已有 `context.time`，使用与配置相同的默认值。
- 32-游戏时间与时钟 UI：C++ `GameTime` 是 registry ctx 数据；
  Zig 本步不再新增平行 `game_time` 模块，`context.time` 作为唯一时间状态。
- 32-游戏时间与时钟 UI：C++ 支持 `AdvanceTimeRequest` 快进；
  Zig 本步只做自然时间推进。
- 32-游戏时间与时钟 UI：C++ `TimeClockUI` 使用完整 UI 框架；
  Zig 本步直接用 `zhu.batch` 和 `zhu.text` 画 HUD。
- 32-游戏时间与时钟 UI：C++ 同一讲还实现昼夜光照和灯光显隐；
  Zig 已拆到 33、34，当前步骤不做。

## 暂缓的大系统

下面这些系统只在前面的可见功能需要时取最小实现，不提前完整照搬：

- 完整 GLRenderer 多 pass、Bloom、Composite
- 完整 ResourceManager 路径映射与热重载
- 完整 UI 框架和预设管理
- 完整空间索引优化
- 完整蓝图工厂和地图对象建造器
- 完整昼夜光照与后处理管线

## 原教程目录参考

后续实现某个系统或功能时，先在这里找到对应教程，再按当前功能计划取最小可见实现。这个目录只作为参考索引，不再表示当前实现顺序。

- [x] 00-开篇.md
- [x] 01-构建与运行.md
- [x] 02-游戏架构设计.md
- [x] 03-从入口到第一帧.md
- [x] 04-测试用例入门.md
- [x] 05-Debug UI 与可观测性基础.md
- [x] 06-事件系统.md
- [x] 07-场景系统.md
- [x] 08-ECS 在本项目中的落地.md
- [ ] 09-2D 渲染最小闭环.md
- [ ] 10-Renderer 与 GLRenderer.md
- [ ] 11-精灵批处理与着色器.md
- [ ] 12-光照与后处理.md
- [ ] 13-资源系统.md
- [ ] 14-字体与文本渲染.md
- [ ] 15-输入系统.md
- [ ] 16-音频系统.md
- [ ] 17-UI 框架基础.md
- [ ] 18-UI 布局与预设.md
- [ ] 19-空间索引.md
- [ ] 20-碰撞解析与移动.md
- [ ] 21-地图数据管线.md
- [ ] 22-关卡载入器与实体建造者.md
- [ ] 23-蓝图与实体工厂.md
- [ ] 24-世界状态.md
- [ ] 25-地图管理器.md
- [ ] 26-游戏场景初始化与系统编排.md
- [ ] 27-玩家控制与相机.md
- [ ] 28-交互与对话.md
- [ ] 29-物品栏与快捷栏.md
- [ ] 30-物品使用与农场循环.md
- [ ] 31-游戏时间与昼夜.md
- [ ] 32-存档与流程收尾.md
- [ ] 33-收尾.md
