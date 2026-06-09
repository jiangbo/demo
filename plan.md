教程路径：C:\workspace\github\cppgamedev\backend\src\courses\OpenGL与迷你农场
CPP 源码路径：C:\workspace\github\TinyFarm

如果是linux环境，路径前缀为：/root/workspace/github，其它路径一样。

## 实现原则

这份计划按原教程目录推进。每节实现时仍保持小步、可验证、易理解；
如果某个可见功能依赖前置系统，就先实现该功能需要的最小系统，不提前铺完整框架。

每节完成后至少运行：

```bash
zig build
```

涉及纯逻辑或组件规则时再运行：

```bash
zig build test
```

## 原教程目录

- [x] 00-开篇.md
- [x] 01-构建与运行.md
- [x] 02-游戏架构设计.md
- [x] 03-从入口到第一帧.md
- [x] 04-测试用例入门.md
- [x] 05-Debug UI 与可观测性基础.md
- [x] 06-事件系统.md
- [x] 07-场景系统.md
- [x] 08-ECS 在本项目中的落地.md
- [x] 09-2D 渲染最小闭环.md
- [x] 10-Renderer 与 GLRenderer.md
- [x] 11-精灵批处理与着色器.md
- [x] 12-光照与后处理.md
- [x] 13-资源系统.md
- [x] 14-字体与文本渲染.md
- [x] 15-输入系统.md
- [x] 16-音频系统.md
- [x] 17-UI 框架基础.md
- [x] 18-UI 布局与预设.md
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

## 不做

1. 不做 C++ 的后处理光照管线。Zig 项目不实现多 pass Lighting/Emissive/Bloom/Composite，
  光照效果优先使用纹理、全屏覆盖色和简单 sprite 叠加来模拟。
2. 不做 C++ 的 `ResourceManager`、`resource_mapping.json` 和资源语义 key 映射层。
3. 不做 C++ 的 FreeType/HarfBuzz 动态字体管线和 TextRenderer 调试面板。
4. 不做 C++ 的完整 `InputManager` 和 Input Debug 面板。
5. 不做 C++ 的完整 UI 框架、布局和 preset 系统。

## 待后续完成

遇到未实现跳过的功能，记录到这里。

- UI：考虑做 ZON 文件监听，实时刷新 ZON 中的数据。
- BUG：exterior ↔ town 之间的连通触发器位置和大小还需调整。
- BUG：对话只能对话动物，交互范围不对，隔很远也能触发对话。
- 31-对话气泡：对话框没有引入图片资源（CPP 使用九宫格图片背景）。
- 28-交互：宝箱交互功能没有，需要实现。
- 30-NPC 显示与简单漫游：NPC 一个都没有，需要实现。
- 31-对话气泡：对话功能没有，需要实现。
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
- 33-昼夜颜色变化：C++ `DayNightSystem` 会计算环境光、太阳方向光和月亮方向光，
  再写入 `GlobalLightingState` 交给引擎 `LightSystem`；Zig 本步先在
  `system/light.zig` 中按时间计算全屏 overlay，直接画出可见色调变化。
- 33-昼夜颜色变化：C++ 从 `light_config.json` 运行时加载关键帧和太阳/月亮参数；
  Zig 本步先使用编译期关键帧插值，保留 4/6/9/14/18/22 这些参考时点的色调；
  用 28 点表示次日 4 点处理跨午夜插值，后续需要调参时再挪到 ZON 配置。
- 33-昼夜颜色变化：C++ 会区分室外地图和室内 `ambient_override`；
  Zig 当前地图还没有室内外元数据，本步默认当前地图都受昼夜色调影响。
- 33-昼夜颜色变化：C++ 同节包含 `TimeOfDayLightSystem` 控制夜间灯光显隐；
  Zig 已拆到 34，本步不实现路灯、窗户光、点光源或光圈。
- 34-夜间灯光占位效果：C++ 使用完整多 pass renderer，包括 LightingPass、
  EmissivePass、BloomPass 和 CompositePass；Zig 本节只做 ECS 光源数据、
  时间显隐规则和 `circle.png` 圆形光圈占位。
- 34-夜间灯光占位效果：C++ 支持真实 `SpotLight` 参数解析；Zig 当前
  `Spot` 只保留默认数据，没有保留 Tiled class 嵌套属性。
- 34-夜间灯光占位效果：C++ 支持 `EmissiveRect` 和 `EmissiveSprite`；
  Zig 本节暂不实现自发光矩形和自发光精灵。
- 34-夜间灯光占位效果：C++ 的玩家灯有独立事件和配置；Zig 已取消玩家跟随灯，
  只保留地图光源。
- 35-音效反馈：C++ 使用 `resource_mapping.json`、`AudioManager`、
  `AudioPlayer`、`PlaySoundEvent` 和 `AudioSystem` 形成完整音频链路；Zig
  已有 `zhu.audio`，本节只新增 `SoundPlay` 事件和 `system/sound.zig`
  收口播放，不新增资源管理层。
- 35-音效反馈：C++ 支持 2D 空间声、实体 `AudioComponent` 映射、音量配置和
  Debug 面板；Zig 本节先全局播放 OGG 音效，不做空间声、配置文件或调试 UI。
- 35-音效反馈：C++ `ActionSoundSystem` 监听动作状态变化并支持概率/冷却；
  Zig 当前工具结算没有完整动画关键帧链，本节直接在锄地、浇水、种植、收获和
  拾取的成功路径发出音效事件。
- 渲染稳定性：Zig 已新增 `graphics.RenderTarget` / `graphics.RenderPass`；
  当前已把 `farm` 对 render target 的直接使用收回，并在 `batch`
  内部按窗口视口尺寸创建可选 render target，自动完成逻辑画面绘制和
  swapchain 缩放绘制。
- 36-暂停菜单：C++ 使用 Scene stack（push/pop）管理暂停菜单嵌套；
  Zig 当前用 `active` 布尔标记，暂停菜单和游戏在同一场景内切换显示。
  槽位选择界面需要场景栈时再扩展。
- 36-暂停菜单：C++ 暂停面板显示存档/读档成功或失败的彩色提示文字；
  Zig 当前用 `std.log` 输出，待后续补 UI 提示。
- 36-暂停菜单：C++ 游戏速度使用指数步进（0.01x~100x）；
  Zig 使用线性 ±0.1，简单够用。
- 37-存档与读档：C++ 保存所有地图数据，Zig 只保存当前地图；
  切换地图时重新生成，当前够用。
- 37-存档与读档：C++ 保存 HP/Gold、完整背包、宝箱、资源节点、作物 planted_day；
  Zig 游戏还没有这些系统，存档字段随游戏系统一起加。
- 38-标题存档选择：C++ `SaveSlotSelectScene` 是可 push/pop 的 Scene，
  通过 callback 把选择结果交给 Title/Pause；Zig 当前用 `ui/save_slot.zig`
  顶层覆盖层和 `Mode` 分支处理，不新增通用 Scene stack。
- 38-标题存档选择：C++ 存档使用 JSON 的 `schema_version`/`timestamp`；
  Zig 保留当前 ZON 存档和 `schemaVersion` 字段，摘要读取只解析最小字段。
- 38-标题存档选择：C++ 会把 timestamp 格式化为本地时间；
  Zig 当前写入并读取 timestamp，但槽位 UI 先只显示 Slot/Day/Empty/Invalid。
- 38-标题存档选择：C++ PauseMenu 显示保存/读取成功失败提示；
  Zig 当前仍主要使用 `std.log` 输出，后续补 UI 提示文字。
- 38-标题存档选择：C++ 练习建议为槽位摘要增加缓存或异步读取；
  Zig 当前每次打开槽位界面同步刷新 10 个槽位，不做缓存/异步。
- 38-标题存档选择：C++ 写存档使用临时文件 + rename 原子替换；
  Zig 当前只保证覆盖写入时会 truncate，不做原子替换。
- 38-标题存档选择：C++ 读档失败会把错误消息带回标题界面显示；
  Zig 当前读档失败只记录日志并请求回标题，不显示错误文字。
- 39-收尾：C++ 使用 `DebugUIManager` 注册多个 `DebugPanel`；
  Zig 当前保留 F5/F6 两个入口，直接在 `ui/debug.zig` 中用折叠区显示信息，
  不新增面板注册框架。
- 39-收尾：C++ 有空间索引、资源管理器、UI preset、音频等独立 Debug 面板；
  Zig 当前只显示已存在且可直接读取的玩家、地图、快捷栏、时间、实体计数、
  事件 trace 和渲染统计。
- 39-收尾：C++ Debug 面板支持较多运行时修改能力；
  Zig 本步只保留重置时间、暂停/恢复时间、恢复 1x 速度这些小操作，
  不做任意传送、任意改背包、任意改存档。
- 39-收尾：C++ 收尾课建议继续扩展任务系统、系统更新顺序图和更强调试工具；
  Zig 本步只完成课程计划中的可见调试面板，不实现任务系统或文档图。
