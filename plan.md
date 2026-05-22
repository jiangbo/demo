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

- [x] 27-加载 Tiled 地图背景
  - 可见效果：从 `.tmj` 显示真实地图 tile layer。
  - 需要系统：Tiled JSON 解析、tileset 图片加载、tile layer 绘制。
  - 参考源码：`engine/loader/level_loader.*`

- [x] 28-地图对象生成实体
  - 可见效果：Tiled object layer 里的玩家出生点、房子、树等生成出来。
  - 需要系统：BasicEntityBuilder、EntityBuilder、对象属性读取。
  - 参考源码：`engine/loader/basic_entity_builder.*`、`game/loader/entity_builder.*`

- [ ] 29-地图切换
  - 可见效果：走到门口/边界后切换到另一个地图。
  - 需要系统：MapManager、Transition 触发区、玩家出生点。
  - 参考源码：`game/world/map_manager.*`、`map_transition_system.*`

- [ ] 30-NPC 显示与简单漫游
  - 可见效果：NPC 在地图上出现并随机走动。
  - 需要系统：NPC 组件、Animal/NPC wander、动画复用。
  - 参考源码：`game/system/npc_wander_system.*`、`animal_behavior_system.*`

- [ ] 31-对话气泡
  - 可见效果：靠近 NPC 按键弹出对话框。
  - 需要系统：InteractionSystem、DialogueSystem、UI 文本。
  - 参考源码：`game/system/dialogue_system.*`、`game/ui/dialogue_bubble.*`

- [ ] 32-游戏时间与时钟 UI
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
