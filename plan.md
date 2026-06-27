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
14. 25-地图管理器：不做 C++ 的双触发离线推进；Zig 当前地图按
  `DayChanged` 推进，非当前地图在重新进入时按 day 差额结算。
15. 30-NPC 显示与简单漫游：不做 C++ 的 `animal_blueprint.json`
  运行时蓝图加载；Zig 使用 ZON 作为动物/NPC 蓝图配置。
- 对话气泡：不做 C++ 的 JSON 运行时对话脚本加载；Zig 使用
  ZON 配置对话文本。

## 待后续完成

未完成功能的序号，有些是另外一个教程的，和当前教程的目录对不上，所以不看序号，应该看功能。

遇到未实现跳过的功能，记录到这里。

- 架构/场景流转：后续让 title、pause、save slot 等 UI 只返回用户意图，
  不直接请求切场景；由 `scene.zig` 统一把意图转换成场景切换、读档、
  退出等流程，避免 UI 反向依赖场景管理。
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
- UI：种子图标目前在 32x32 背包/快捷栏格子里显得偏大，后续不改动
  原始图片，也不新增裁切后的图标资源；优先扩大背包格子和快捷栏格子，
  让工具、种子和数量文字在同一套整数像素缩放下显示得更协调。
- 30-NPC 显示与简单漫游：C++ `AnimalBehaviorSystem` 支持睡觉、进食和时间判断；
  Zig 本步先只做显示和随机漫游。
- 引擎/batch：后续支持多个 vertex buffer，但暂不把 `order`/`layer`
  概念混入本次设计。`batch` 只关心绘制状态，不内置图片、文字、UI
  等业务概念。
  - `commands` 保持全局一个，用来记录真实提交历史，继续支持
    `target` 和 `draw` 命令。
  - vertex buffer 可以有多个，由用户或上层模块显式选择当前 buffer。
    每个 buffer 只保存自己的 CPU 顶点数组和 GPU `handle`。
  - `DrawCommand` 记录 `buffer` 索引、`start`/`end`、`view`、
    `camera`、`size`、`pipeline`、`sampler` 等绘制所需状态。
  - 切换 buffer 必须结束当前 draw command，因为 `start`/`end`
    只对所属 buffer 有意义。
  - 保持当前风格：`drawImage` 只自动按纹理切换拆命令；buffer、
    pipeline、target 等状态切换由明确的 `useBuffer`、`usePipeline`、
    `useTarget` 完成。
  - 第一版 `flush` 仍按全局 commands 提交顺序绘制；后续如需
    绘制层级，再单独设计 order/layer，不和多 vertex buffer 混为一谈。

  2. Query 切片在迭代中可能悬垂(379-392、429)
  Query 把 dense/sparse/values 切片捕获进结构体。Store 一旦 add 触发 growValue/growDense
  重分配,这些切片就悬空;即便不重分配,len 变了切片也 stale。destroyEntities 靠 .reverse() +
  只删尾元巧妙避开了,但这是隐含契约——用户若 query() 后在循环里 add(),会 UB。建议在 Query
  上加一句文档注释写清「迭代期间不得 add」。
