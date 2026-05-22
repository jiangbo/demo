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

- [x] 01-打开窗口并显示第一帧
  - 可见效果：窗口启动，背景清屏色可见。
  - 需要系统：window、frame 回调、batch 初始化。
  - 参考源码：`engine/core/game_app.*`

- [x] 02-Debug UI 开关与基础状态面板
  - 可见效果：按 F5/F6 能打开调试面板。
  - 需要系统：ImGui 初始化、输入按键、context 调试开关。
  - 参考源码：`engine/debug/*`

- [x] 03-标题场景与农场场景切换
  - 可见效果：标题界面能切到农场界面。
  - 需要系统：scene 状态、事件队列、场景请求。
  - 参考源码：`engine/scene/*`、`game/scene/title_scene.*`

- [x] 04-用色块搭出最小农场
  - 可见效果：屏幕上看到玩家、作物、土地色块。
  - 需要系统：ECS World、Position/Sprite/Render 组件。
  - 参考源码：`engine/component/*`、`engine/system/render_system.*`

- [x] 05-YSort 与 layer/depth 排序
  - 可见效果：不同 y 坐标的对象遮挡顺序正确。
  - 需要系统：YSort 标记、Render 排序。
  - 参考源码：渲染深度更新与排序相关逻辑

- [x] 06-加载第一张 PNG 图片
  - 可见效果：玩家或按钮不再是色块，显示真实 PNG。
  - 需要系统：`assets.loadImage`、Sprite 使用真实 Image。
  - 参考源码：`engine/resource/texture_manager.*`

- [x] 07-裁剪 sprite sheet 的第一帧
  - 可见效果：从角色 Idle 图里裁出单帧角色。
  - 需要系统：Image.sub、Sprite 源矩形、尺寸约定。
  - 参考源码：`engine/render/image.*`、`sprite_component.h`

- [x] 08-Sprite pivot 与脚底定位
  - 可见效果：角色脚底落在格子上，YSort 更自然。
  - 需要系统：Sprite.pivot，RenderSystem 用 pivot 计算绘制位置。
  - 参考源码：`engine/component/sprite_component.h`

- [x] 09-角色待机动画
  - 可见效果：玩家站立时播放 Idle 动画。
  - 需要系统：Animation 组件、AnimationSystem、帧计时。
  - 参考源码：`engine/component/animation_component.h`、`animation_system.*`

- [x] 10-键盘移动玩家
  - 可见效果：WASD/方向键移动玩家图片。
  - 需要系统：Input、Velocity、MovementSystem、PlayerControlSystem 最小版。
  - 参考源码：`engine/input/*`、`game/system/player_control_system.*`

- [x] 11-移动动画与朝向
  - 可见效果：移动时切 Walk 动画，停止后回 Idle。
  - 需要系统：Actor 状态、方向、Animation 切换。
  - 参考源码：`game/component/actor_component.h`、`state_system.*`

- [x] 12-相机跟随玩家
  - 可见效果：玩家移动到屏幕边缘时相机跟随。
  - 需要系统：camera position、CameraFollowSystem。
  - 参考源码：`engine/render/camera.*`、`game/system/camera_follow_system.*`

- [x] 13-Renderer 外观层（跳过，视口裁剪直接在 render 系统中实现）

- [x] 14-视口裁剪
  - 可见效果：Debug 面板能看到屏幕外对象被跳过。
  - 需要系统：相机可视矩形、Renderer culling、统计显示。
  - 参考源码：`engine/system/render_system.*`

- [x] 15-批处理统计面板
  - 可见效果：面板显示 sprites、commands、sprites/command。
  - 需要系统：batch stats 命名整理、Debug UI 展示。
  - 参考源码：`engine/render/opengl/sprite_batch.*`

- [x] 16-绘制简单草地 tiles
  - 可见效果：屏幕上出现一片由真实 tileset 拼出的草地。
  - 需要系统：固定二维 tile 数组、tileset sub image。
  - 参考源码：`engine/component/tilelayer_component.h`

- [x] 17-绘制土地与作物贴图
  - 可见效果：土地和作物使用真实素材，而不是色块。
  - 需要系统：作物/土地组件绑定 sprite sheet 子图。
  - 参考源码：`game/component/crop_component.h`、`farmland_component.h`

- [x] 18-工具目标格高亮
  - 可见效果：鼠标指向的邻近格子有高亮框。
  - 需要系统：Target 组件、鼠标位置到目标格计算、debug/overlay 绘制。
  - 参考源码：`game/component/target_component.h`

- [x] 19-锄地交互
  - 可见效果：按键后目标格变成耕地贴图。
  - 需要系统：ItemUse 最小入口、FarmSystem hoe 操作、格子状态。
  - 参考源码：`game/system/item_use_system.*`、`farm_system.*`

- [x] 20-浇水交互
  - 可见效果：耕地按键后切换为湿润土地贴图。
  - 需要系统：Farmland.watered、贴图切换、操作反馈。
  - 参考源码：`game/component/farmland_component.h`

- [x] 21-播种与作物生长
  - 可见效果：播种后出现种子，时间推进后变成下一阶段。
  - 需要系统：Crop.growth、CropSystem、作物阶段 sprite。
  - 参考源码：`game/system/crop_system.*`、`assets/data/crop_config.json`

- [x] 22-收获与掉落物
  - 可见效果：成熟作物被收获，地上出现可拾取物图标。
  - 需要系统：Pickup 组件、收获规则、掉落 sprite。
  - 参考源码：`game/component/pickup_component.h`、`pickup_system.*`

- [x] 23-物品栏与快捷栏 UI
  - 可见效果：屏幕底部显示快捷栏和物品图标数量。
  - 需要系统：Inventory、Hotbar、UI 图片绘制、图标配置。
  - 参考源码：`game/ui/hotbar_ui.*`、`inventory_system.*`

- [x] 24-快捷栏选择与工具切换
  - 可见效果：数字键/滚轮切换选中格，工具图标变化。
  - 需要系统：HotbarSystem、Input、选中状态显示。
  - 参考源码：`game/system/hotbar_system.*`

- [x] 25-拾取物进入背包
  - 可见效果：玩家靠近掉落物后物品消失，快捷栏数量增加。
  - 需要系统：简单碰撞/距离检测、PickupSystem、Inventory 合并。
  - 参考源码：`game/system/pickup_system.*`

- [x] 26-碰撞阻挡
  - 可见效果：玩家不能穿过房子、栅栏或测试障碍。
  - 需要系统：Collider、StaticTileGrid 最小版、Movement 碰撞解析。
  - 暂缓内容：DynamicGrid 放到地图对象/动态实体生成后再接入。
  - 参考源码：`engine/spatial/*`、`movement_system.*`

- [x] 27-加载 Tiled 地图背景
  - 可见效果：从 `.tmj` 显示真实地图 tile layer。
  - 需要系统：Tiled JSON 解析、tileset 图片加载、tile layer 绘制。
  - 参考源码：`engine/loader/level_loader.*`

- [ ] 28-地图对象生成实体
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
