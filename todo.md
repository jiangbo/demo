# TODO

## 当前验证

- [x] 实际运行并验证所有传送点的目标地图、落点、朝向和间隔。
- [x] 验证受剧情进度限制的传送点。
- [x] 验证开始游戏、读取存档和战斗返回后的玩家位置与朝向。
- [x] 当前重构通过 `zig build` 编译。
- [ ] 当前迁移完成后通过完整通关统一回归验证。

## UI 迁移

- [x] 迁移标题、暂停、存档、关于、对话和提示 UI。
- [x] 删除旧 `menu.zig`，最终将战斗菜单并入
  `battle/battle.zig`。
- [x] 迁移状态 UI。
- [x] 迁移物品 UI。
- [x] 迁移商店和出售 UI。
- [x] 迁移圣剑提示和结局文字。

## ECS 迁移

- [x] 传送点 ECS 化。
- [x] 死亡 NPC ECS 化。
- [x] 拆分玩家长期属性，将剧情进度、生命等移入 `storage` 中的
  ECS 长期数据；存档直接使用该数据，不再与 `player.zig` 相互转换。
- [x] 地图创建时按进度设置人物状态，剧情系统处理运行期间的变化。
- [x] 为宝箱设计稳定 ID，替代临时数字索引。
- [x] 引入 `Sprite` 静态渲染组件，并调整现有动画渲染结构。
- [x] 宝箱 ECS 化，一个宝箱对应一个实体。
- [x] `Portal` 组件位于 `component` 顶层；地图画面和碰撞数据不进入 ECS。
- [x] 普通地图由 `map` 模块的 `draw` 渲染、`walk` 处理碰撞，不做成 ECS 实体。
- [x] `factory.spawnMapObjects` 统一生成传送区域、宝箱和地图人物。
- [x] 地图对象（传送区域、宝箱、人物）ECS 化；地图画面和碰撞保持 `map` 模块全局。

地图迁移时保持以下设计：

- 静态 ZON 地图和瓦片配置不进入 ECS。
- 普通地图只保留当前地图实例，不让所有普通地图长期共存。
- 战斗使用独立场景，不销毁或重建普通世界的 ECS。
- 切换普通地图时清空 ECS，只保留 `storage.keep` 中的长期状态。
- 普通地图进入时生成全部顶点，不做视口裁剪。
- `map.zig` 持有顶点和碰撞场；当前地图标识存于玩家实体的
  `zon.Map.Key` 组件。
- 战斗地图由 `battle.zig` 生成并长期持有，不进入普通地图 ECS。
- 地图创建只负责创建实体，地图逻辑由系统处理。
- 删除 `world.zig` 时再评估普通地图顶点所有权和 `map.zig`。

## 战斗迁移

战斗保留状态机，采用半 ECS：传递 `world`、读写其中的数据，但战斗状态
不接入 ECS（与 UI 模块一致）。

- [x] 迁移战斗状态栏、结算和文字提示。

## 长期目标

以下模块都是 ECS 迁移期间的过渡模块。不要再向其中增加新的状态和逻辑，
现有内容只允许逐步迁出，最终完全删除：

- [x] 删除 `world.zig`。
- [x] 删除 `player.zig`。
- [x] 删除 `menu.zig`。
- [x] 删除 `world.zig` 时重新评估 `map.zig`，由其继续持有普通地图
  顶点和当前地图位置。
- [x] 删除根目录的 `item.zig`。
- [x] 删除 `context.zig`。
- [x] `battle/` 作为战斗永久实现保留，不删除。

## 场景切换

- [x] 删除 `sceneCall` 和 `window.call` 隐式分发，显式调用各场景的
  `enter`、`exit`、`update` 和 `draw`。
- [x] 普通世界淡出完成后再进入战斗场景，避免提前重置战斗状态和相机。
- [x] 使用 `pendingScene` 携带普通世界的进入模式，替代
  `world.back`。

## 地图渲染

- [x] 解决像素地图在非整数 `nearest` 缩放下移动时的闪动。

问题表现和原因：

- 逻辑画面为 `640x480`，当前 DPI 下普通窗口为 `800x600`，
  最终使用 `125%` 非整数最近邻缩放。
- 相机移动到非物理像素位置时，深色 Tile 细节会在相邻帧中忽粗忽细，
  看起来像短暂出现黑色细线。
- 整数缩放和最终使用 `linear` 合成都不闪。纯色 Tile、删除 ground
  图层和最近邻离屏绘制均证明问题不是图集 padding、Tile 几何空隙、
  图层重叠或素材损坏。

解决方案：

- 保持地图直接使用 `nearest` 绘制，不使用 Tile 离屏合成。
- ZhuYu 的 `window.scale` 在 `computeViewRect` 中根据
  `viewRect.size / size` 更新，包含 DPI 和窗口缩放。
- `camera.roundPosition(null)` 使用 `window.scale` 和
  `window.viewRect.min`，将相机对齐到最终物理像素；显式传入缩放时，
  用于对齐从零点开始的离屏目标。
- Demo 在每次 `camera.directFollow` 后调用
  `camera.roundPosition(null)`。
- 已验证普通窗口和最大化窗口移动时没有明显闪动或顿挫。

如果问题再次出现，先检查 `window.scale`、`viewRect.min` 是否正确更新，
以及 `roundPosition` 是否在最后一次相机移动后调用，再检查渲染目标和
采样方式是否发生变化。

## 战斗状态

- [x] 使用 `Enemy` identity 表示当前选中的战斗对象，不再通过
  `context.zig` 传递人物标识和战斗结果。
- [x] `battle.enter` 通过 ECS world 取得当前敌人，并在战斗内部保存
  可变数据副本。
- [x] 战斗阶段直接返回胜利、逃跑和标题终止标识。
- [x] `battle.update` 返回 `Request`，战斗系统内部完成胜利和逃跑
  结算，scene 只处理场景切换。
- [x] 将战斗菜单状态和选择逻辑并入 `battle/battle.zig`，删除
  `ui/battle.zig`。

## 全局状态

- [x] 重新评估玩家剧情进度的归属，决定随玩家长期属性移入
  `storage`。
- [x] 用 ECS 状态替代 `world` 中的对话状态。
- [x] 将 `world.tip` 迁入 UI，删除临时的 `event.Tip` 转接逻辑。
- [ ] 重新评估 `Interact.Disabled`。当前对话由 UI 阻塞，不再依赖该
  组件；暂时保留，确认后续是否存在非对话的禁用交互需求。
