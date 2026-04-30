# 计划

## 引用路径

- 教程目录：`C:\workspace\github\cppgamedev\backend\src\courses\ECS与怪物战争`
- C++ 参考源码目录：`C:\workspace\github\MonsterWar`
- 后续更新本计划时保留本节路径说明。

## 26 技能施放与显示 [PLANNED]

### 1. 技能数据与组件基础 [DONE]
- **目标**：先让玩家单位拥有技能信息，但不施放。
- **修改文件**：`monster/component.zig`, `monster/spawn.zig`,
  `monster/zon/player.zon`
- **新增命名**：`com.skill.Skill`, `com.SkillEnum`, `com.skill.Buff`,
  `com.skill.Ready`, `com.skill.Active`, `com.skill.Passive`,
  `com.skill.CostRecovery`
- **实现方式**：
  - 不新增独立 `skill.zon`，先把技能字段直接挂在 `player.zon`
    的玩家模板上，保持 Zig 项目现有 ZON 风格。
  - 技能先包含 `name`、`description`、`coolDown`、`duration` 和
    `buff`。
- **占位策略**：特效字段暂不生效。
- **验证方式**：运行 `zig build`；部署玩家后 ImGui 能读到技能组件。
- **本步不做**：技能冷却、按钮、Buff、特效。

### 2. ImGui 显示技能状态 [DONE]
- **目标**：选中玩家单位时显示技能名称、描述、冷却和持续时间。
- **修改文件**：`monster/gui.zig`
- **实现方式**：
  - 在 `renderSelectedUnit()` 中读取 `com.skill.Skill`。
  - 按 C++ 调试面板样式显示技能按钮、状态文本、冷却进度条占位
    和技能描述。
- **占位策略**：按钮暂时只用于显示，不触发技能施放。
- **验证方式**：运行 `zig build`；选中玩家单位能看到技能信息。
- **本步不做**：按键 `S`、技能激活事件。

### 3. 技能冷却计时 [DONE]
- **目标**：技能冷却结束后进入 Ready 状态。
- **修改文件**：`monster/system/skill.zig`, `monster/spawn.zig`,
  `monster/scene.zig`
- **实现方式**：
  - 新增 `system/skill.zig`，集中推进主动技能冷却。
  - 玩家部署时只挂载技能组件和初始标签，不通过 `com.Timer`
    处理技能冷却。
  - 冷却结束添加 `com.skill.Ready`，并让 `coolDownTimer` 停在
    `coolDown`。
- **占位策略**：技能显示实体先不生成，只在 ImGui 显示
  “技能准备就绪”。
- **验证方式**：运行 `zig build`；部署单位后等待冷却，ImGui 状态变化。
- **本步不做**：Buff 和持续时间结束逻辑。

### 4. 手动施放技能 [DONE]
- **目标**：通过 ImGui 按钮或快捷键 `S` 激活 Ready 技能。
- **修改文件**：`monster/gui.zig`, `monster/system/skill.zig`
- **实现方式**：
  - 按钮可用条件是实体有 `com.skill.Ready`。
  - 点击按钮或按 `S` 后给实体添加 `com.skill.Cast`。
  - 技能系统消费 `Cast` 标签，移除 Ready，添加 Active，
    并推进持续时间。
- **占位策略**：暂不做 Buff 和头顶显示实体。
- **验证方式**：运行 `zig build`；按钮点击后状态变为“激活中”，显示剩余时间。
- **本步不做**：属性 Buff、头顶特效。

### 5. Buff 应用与移除 [DONE]
- **目标**：技能激活时修改属性，持续结束后恢复。
- **修改文件**：`monster/component.zig`, `monster/system/skill.zig`,
  `monster/scene.zig`
- **新增命名**：`system/skill.zig`
- **实现方式**：
  - 新增技能系统集中处理 Active 状态。
  - 根据技能配置修改 `Stats`、`attack.Range`、`attack.CoolDown`，
    结束时除回倍率。
- **占位策略**：只支持倍率型 Buff，避免一次性引入复杂蓝图管理。
- **验证方式**：运行 `zig build`；技能前后 ImGui 属性数值变化，
  结束后恢复。
- **本步不做**：治疗特效、升级、撤退等教程后续综合内容。

### 6. COST 恢复被动技能 [DONE]
- **目标**：实现 C++ 中 `CostRegenComponent` 的核心效果。
- **修改文件**：`monster/component.zig`, `monster/context.zig`,
  `monster/system/skill.zig`
- **实现方式**：
  - 被动技能单位部署后直接添加 `com.skill.Passive`、`com.skill.Active`
    和 `com.skill.CostRecovery`。
  - `ctx.update()` 或 `skill.update()` 遍历 `CostRecovery` 叠加 COST。
- **占位策略**：优先在 `skill.update()` 里处理；如果调用链不方便，
  再调整 `scene.zig`。
- **验证方式**：运行 `zig build`；部署带被动技能单位后 COST 增长速度变快。
- **本步不做**：复杂叠加规则和 UI 表格排序。

### 7. 技能显示特效 [DONE]
- **目标**：Ready/Active 时在单位头顶显示提示图标或循环特效。
- **修改文件**：`monster/component.zig`, `monster/spawn.zig`,
  `monster/system/skill.zig`, 可能新增 `monster/zon/effect.zon`
- **实现方式**：
  - 参考 C++ `createSkillDisplay()`，创建一个轻量显示实体，保存到
    `Skill.displayEntity`。
  - 状态切换时销毁旧显示实体。
- **占位策略**：先复用现有图片资源里的 `skill_active.png` 或 `circle.png`，
  动画可先固定帧。
- **验证方式**：运行 `zig build`；冷却完成和激活时头顶显示不同提示。
- **本步不做**：通用 `EffectEvent` 框架。

### 8. 治疗特效复用 [DONE]
- **目标**：补上教程中通用特效事件的可见结果。
- **修改文件**：`monster/system/health.zig`, `monster/spawn.zig`,
  `monster/system/animation.zig`
- **实现方式**：治疗结算后生成一次性 `heal` 特效实体，动画结束后删除。
- **占位策略**：如果现有动画删除机制不足，先用 `Ghost`、`Dead`
  或 `OneShotRemove` 风格的小标签保持最小实现。
- **验证方式**：运行 `zig build`；女巫治疗时出现治疗特效。
- **本步不做**：完整 C++ 蓝图管理器迁移。
