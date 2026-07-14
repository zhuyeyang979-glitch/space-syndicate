# Agent B — VS06-B P0 起始怪兽首召交接

## 结论

I 级 starter first-summon 已在唯一 `MonsterRuntimeController` 中闭合为 revisioned `prepare → commit → rollback/finalize` 生命周期。相同 transaction exact-once；成功 commit 后怪兽进入现有生产 roster snapshot；checkpoint/save-load、公开/本人私有/开发快照均复用同一 owner。人类与 AI 使用同一 intent/API，不存在第二套怪兽状态。

升级、IV refresh、诱导、固定兽技及更广 rank 没有开放。升级统一 fail-closed：`monster_upgrade_duration_policy_conflict`。

## 修改文件

- `scripts/runtime/monster_runtime_controller.gd`
- `scripts/runtime/monster_runtime_world_bridge.gd`
- `scenes/runtime/MonsterRuntimeWorldBridge.tscn`
- `scripts/cards/v06/units/monster_card_owner_port_v06.gd`
- `docs/monster_deploy_atomic_lifecycle_v06_contract.md`
- `tests/monster_deploy_atomic_lifecycle_v06_test.gd`
- `tests/monster_card_real_owner_integration_v06_test.gd`
- `tests/monster_runtime_v06_privacy_test.gd`
- `reports/coordination/agent_b_vs06_first_summon_handoff.md`

## 公开 API

- 能力：`monster_runtime_capabilities_v06()`、`unit_card_runtime_capabilities_v06("monster")`
- 首召上下文：`monster_starter_first_summon_context_v06(actor_id, region_id, card_id)`
- 生命周期：`prepare_unit_card_intent_v06`、`commit_unit_card_intent_v06`、`rollback_unit_card_intent_v06`、`finalize_unit_card_intent_v06`
- 快照：`unit_card_snapshot_v06("monster")`、`monster_private_snapshot_v06(actor_id)`；开发诊断另用 `monster_card_developer_snapshot_v06()`
- 存档：`unit_card_checkpoint_status_v06("monster")`、`unit_card_save_data_v06("monster")`、`apply_unit_card_save_data_v06(data, "monster")`
- WorldBridge 权威事实：`monster_deploy_region_snapshot_v06`、`monster_deploy_profile_snapshot_v06`、`monster_deploy_rule_snapshot_v06`、`monster_deploy_cross_owner_capabilities_v06`

Profile 没有额外 patch 时，P0 只原子提交 roster/UID/selection/starter marker。若 Profile 声明 bound-skill、经济或角色现金 patch，而对应 owner 没有完整四阶段能力，则在 roster mutation 前返回 `monster_cross_owner_atomicity_unavailable`。

## 最小自检

- Godot：`4.7.stable.official.5b4e0cb0f`
- 场景加载：
  - `godot --headless --path . --quit-after 1 res://scenes/runtime/MonsterRuntimeController.tscn` — PASS
  - `godot --headless --path . --quit-after 1 res://scenes/runtime/MonsterRuntimeWorldBridge.tscn` — PASS
- 聚焦测试：`godot --headless --path . --script res://tests/monster_deploy_atomic_lifecycle_v06_test.gd` — PASS，`51/51`，`failures=0`
- `git diff --check`（本轮独占文件）— PASS

依协调指令，本线程没有重复跑完整回归、全套隐私扫描、完整局或 MCP 有头验收。

## 尚未接线与风险

- `REQ-MON-P0-001`：Agent A/Coordinator 仍需让真人与 AI 的正式卡牌入口通过同一个 SS06-07 adapter/router 调用上述 owner API，并提供权威 region/profile/rule snapshots；不得绕过 Card Flow。
- Card state commit 失败时，只有 owner 明确 `rolled_back=true` 才算补偿成功；成功后须调用 finalize，失败则保留 committed 状态重试。
- Profile 带跨 owner patch 时仍需真实 participant 四阶段能力；reference owner 回执不等于 production。
- 升级 duration 的“剩余时间 +60 秒”与旧 owner“重置完整 duration”冲突未裁决，故升级保持 fail-closed。
- 完整跨模块回归、递归隐私扫描、真实整局、存档隔离和二号屏有头验收由协调线程统一执行。

## Lessons for other agents

- **invariant**：唯一业务 owner；transaction→effect/association 是权威，人类与 AI 同 API。
- **failed approach**：旧 `_summon_monster_from_card` 会在构造期间分配 UID 并串行触发外部副作用，不能作为原子入口。
- **stable API**：四阶段 lifecycle、三层 snapshot、flat `monster_card_atomic_*` save keys。
- **test oracle**：duplicate 不增加 roster/UID；失败前后 core fingerprint 相等；成功 commit 后生产 roster 可见。
- **integration trap**：response-ID journal 不能替代 transaction journal；reference owner 不能证明 production ready。
- **reusable pattern**：preimage/postimage 一次 swap、binding fingerprint、terminal journal、finalize 后 presentation exact-once。
- **stale evidence**：旧 full-duration upgrade 断言不是 v0.6 真值。
- **next dependency**：Coordinator 完成 `REQ-MON-P0-001` 并统一执行垂直切片验收。
