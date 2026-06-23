教程路径：C:\workspace\github\cppgamedev\backend\src\courses\OpenGL与迷你农场
CPP 源码路径：C:\workspace\github\TinyFarm

如果是linux环境，路径前缀为：/root/workspace/github，其它路径一样。

## 实现原则

你提出的所有修改意见，只要是我没有明确同意的，都不准修改。
引擎模块不加测试。

每节完成后至少运行：

```bash
zig build
```

涉及纯逻辑或组件规则时再运行：

```bash
zig build test
```

## 当前状态说明

项目已经按教程主线实现过一轮，大部分功能已有对应的 Zig 实现，
或者已经在本文件中记录了不做项和 Zig 侧的简化取舍。

后续不再按原教程目录机械推进。需要补功能或检查细节时，按具体功能
回到教程和 C++ 源码对照，确认 C++ 做了什么、Zig 已经做到哪里、
哪些差异是有意简化，哪些还需要补实现。

## 不做

1. 不做 C++ 的后处理光照管线。
2. 不做 C++ 的 `ResourceManager`、`resource_mapping.json` 和资源语义 key 映射层。
3. 不做 C++ 的 FreeType/HarfBuzz 动态字体管线和 TextRenderer 调试面板。
4. 不做 C++ 的完整 `InputManager`、Input Debug 面板、UI 框架、布局和 preset 系统。
5. 不做 C++ 的 `StaticTileGrid`、`DynamicEntityGrid`、`CollisionResult`、
  空间索引综合框架和空间索引 Debug 面板。
6. 不做 Debug 面板。
7. 22-关卡载入器与实体建造者：不做 C++ 的
  `LevelLoader`/`BasicEntityBuilder`/`EntityBuilder` 抽象分层、
  每 tile ECS entity、`TileLayerComponent` 和 `ObjectPropertiesReader`。
8. 21-地图数据管线：不做 C++ 的 Auto-tile 系统（WangSets、
  `AutoTileLibrary`、`AutoTileSystem`），地图瓦片拼接由美术直接处理；
  不做地图边缘切图（edge transition），所有跨地图切换统一通过 Tiled
  `map_trigger` 触发器完成；
  不做 `.world` 文件解析，地图布局和邻接关系使用编译期 ZON 配置。
9. 23-蓝图与实体工厂：不做 C++ 的 `BlueprintManager`、运行时 JSON 蓝图、
  hash key 查询和 Blueprint Inspector；Zig 使用编译期 `factory.zon`，
  由 `factory.zig` 直接作为复杂实体的唯一装配点。
10. 不做 C++ 的交互目标固定优先级（`NPC > Chest > Rest`）；Zig 的
  facing probe 命中多个交互目标时统一按距离选择最近目标。
11. 29-物品栏与快捷栏：不做 C++ 的库存/快捷栏 Request、Changed、
  full sync 和 diff 事件链路；Zig 使用 `inventory.zig` 作为单一状态入口，
  UI 和玩法直接读取同一份背包与快捷栏状态。
12. 29-物品栏与快捷栏：快捷栏按物品类型唯一绑定，同一种物品不会同时
  占用多个快捷栏槽位。
13. 32-存档与流程收尾：不做 C++ 的 `schema_version` 或 Zig
  `schemaVersion` 存档版本字段；Zig 保持当前 ZON 存档结构，格式错误
  直接暴露解析错误或使用结构默认值，不做兼容迁移。

## 待后续完成

未完成功能的序号，有些是另外一个教程的，和当前教程的目录对不上，所以不看序号，应该看功能。

遇到未实现跳过的功能，记录到这里。

- 架构/状态管理：后续考虑把 `context.zig`、`inventory.zig`、
  `map.zig`/`land.zig`/`spatial.zig` 这类运行时可变的模块级
  `var` 收进显式 `State` 结构体，减少隐藏全局状态；但系统函数不默认
  传入一个大 `Game` 指针，而是按实际需要传 `world`、`clock`、
  `inventory`、`land` 等具体依赖。若某个系统参数持续变多，优先拆分
  系统边界或小模块，而不是用大对象掩盖依赖。C++ 项目也是由
  `GameApp`/`Context`/`Scene` 做装配，具体系统通常在构造时接收
  自己需要的 `registry`、`dispatcher`、`input`、`camera`、
  `spatial_index` 等依赖；Zig 后续参考这个依赖边界，不照搬
  C++ 的 manager/class 分层。
- 19-空间索引：`ROCK` 还只是 `land.Object.kind` 能表达，地图加载没有把石头写入
  `tile.object`，工具系统也没有敲石头、销毁实体和清理格子的逻辑。
- 19-空间索引：目前 crop 收获时能按已知 tile 清理 `tile.object`；资源节点销毁
  需要补一个按 entity 清理所在格的简单函数。
- 25-地图管理器：Zig 已保存耕地/作物的地图状态，并按天做离线推进；当前地图由
  `DayChanged` 立即推进，非当前地图只在重新进入时按 day 差额结算，不做 C++ 的
  双触发离线推进。
- 25-地图管理器：树/石头 destroyed/hit_count 后续随交互/工具系统加入；
  仍使用 tile 状态记录，不引入 C++ `RegistrySnapshot`。
- 30-物品使用与农场循环：斧头、镐子已补物品和动画资源，但当前不接入
  目标点击和 `farm` 结算；后续资源节点实现时再让 `.axe`、`.pickaxe`
  进入工具使用链路。
- 30-物品使用与农场循环：资源节点未实现 `ResourceNode` 状态，包括
  tree/rock 类型、hit_count、hits_to_break、掉落物品和掉落数量。
- 30-物品使用与农场循环：地图加载尚未把树/石头资源节点写入
  `land.Tile.object` 或独立实体，也没有资源节点命中、销毁、清理格子、
  生成 pickup、命中音效和命中动画逻辑。
- 30-物品使用与农场循环：资源产物如木材、石头还没有加入 `ItemEnum`、
  `factory.zon` 物品配置和对应图标。
- UI：考虑做 ZON 文件监听，实时刷新 ZON 中的数据。
- UI：种子图标目前在 32x32 背包/快捷栏格子里显得偏大，后续不改动
  原始图片，也不新增裁切后的图标资源；优先扩大背包格子和快捷栏格子，
  让工具、种子和数量文字在同一套整数像素缩放下显示得更协调。
- 30-NPC 显示与简单漫游：NPC 一个都没有，需要实现。
- 29-地图切换：C++ 切换时有 `UIScreenFade` 淡入淡出和 `ActionLockedTag`
  行动锁；Zig 本步先瞬时切换。
- 29-地图切换：C++ 有资源节点和宝箱恢复；Zig 已保存耕地/作物/宝箱打开状态，
  资源节点状态后续随对应玩法实现。
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
  Zig 使用 `context.clock.restHours` 做按小时推进，不新增
  `AdvanceTimeRequest` 事件类型。
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
  Zig 使用 `map.isOutdoor()` 写死室内外规则：`.town`、`.exterior`
  为室外，`.school`、`.interior` 为室内；室内不绘制昼夜 overlay，
  不实现 `ambient_override`。
- 33-昼夜颜色变化：C++ 同节包含 `TimeOfDayLightSystem` 控制夜间灯光显隐；
  Zig 已拆到 34，本步不实现路灯、窗户光、点光源或光圈。
- 34-夜间灯光占位效果：C++ 使用完整多 pass renderer，包括 LightingPass、
  EmissivePass、BloomPass 和 CompositePass；Zig 本节只做 ECS 光源数据、
  时间显隐规则和 `circle.png` 圆形光圈占位。
- 34-夜间灯光占位效果：C++ 支持真实 `SpotLight` 参数解析；Zig 当前
  `Spot` 只保留默认数据，没有保留 Tiled class 嵌套属性。
- 34-夜间灯光占位效果：C++ 的玩家灯有独立事件和配置；Zig 已取消玩家跟随灯，
  只保留地图光源。
- 34-夜间灯光占位效果：Zig 室内地图光源始终启用，`system.light.update`
  会清理 `light.Disabled`，不按 18/6 点切换；室外地图仍按
  `HourChanged` 在 18 点启用 night-only、6 点启用 day-only。
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
- 37-存档与读档：C++ 保存所有地图数据；Zig 保存
  `context.map.states` 中已初始化的地图状态，保存前先用
  `map.saveState(world)` 写回当前地图，未访问地图继续由 ZON 重新生成。
- 37-存档与读档：C++ 保存 HP/Gold、完整背包、宝箱、资源节点、
  作物 planted_day；Zig 当前保存时间、玩家地图/位置/朝向、完整背包、
  快捷栏、耕地/作物和宝箱状态，HP/Gold、资源节点和 planted_day 后续
  随对应系统一起加。
- 38-标题存档选择：C++ `SaveSlotSelectScene` 是可 push/pop 的 Scene，
  通过 callback 把选择结果交给 Title/Pause；Zig 当前用 `ui/save_slot.zig`
  顶层覆盖层和 `Mode` 分支处理，不新增通用 Scene stack。
- 38-标题存档选择：C++ 存档使用 JSON 的 `schema_version`/`timestamp`；
  Zig 保留当前 ZON 存档和 timestamp，不做版本字段，摘要读取只解析最小字段。
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
