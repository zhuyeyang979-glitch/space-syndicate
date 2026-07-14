# Agent B — VS06-B3 starter snapshot recursion handoff

## 结果

已在 Monster owner 侧切断无限递归。根因是 `monster_private_snapshot_v06()` 调用 `_monster_card_rule_snapshot_v06()`，后者经 WorldBridge 进入 `main.monster_deploy_rule_snapshot_v06()`；main 又回调 `monster_private_snapshot_v06()`。

现在 `monster_private_snapshot_v06()` 只读取 owner 本地 marker/roster/revision，不再调用 rule snapshot、main 或 WorldBridge。`scripts/runtime/monster_runtime_world_bridge.gd` 无需修改。

## 冻结 API

```gdscript
monster_starter_state_snapshot_v06(actor_id: String) -> Dictionary
```

稳定字段：

- `available: bool`
- `state: "not_summoned" | "summoned" | "legacy_unknown"`
- `unit_uid: int`
- `transaction_id: String`
- `revision: int`
- `owner_revision: int`
- `reason_code: String`

行为：

- 空 roster、无 marker：`available=true, state=not_summoned`。
- 原子首召成功：从 `_monster_starter_state_v06` 返回 `summoned`、UID、transaction 与 revisions。
- save/load：保持同一 marker 结果。
- roster 中存在缺少 `owner_actor_id_v06`/marker 的旧归属怪兽，或 marker 损坏：`available=false, state=legacy_unknown`，禁止猜测为未召唤。
- 查询不调用任何 world fact port，连续调用没有副作用。

## 修改文件

- `scripts/runtime/monster_runtime_controller.gd`
- `tests/monster_deploy_atomic_lifecycle_v06_test.gd`
- `reports/coordination/agent_b_vs06_starter_snapshot_recursion_handoff.md`

## 给 Agent A 的最小接线

将 `main.monster_deploy_rule_snapshot_v06()` 中读取 starter 状态的代码改为：

1. 调用 `monster_runtime_controller.monster_starter_state_snapshot_v06(actor_id)`；
2. 只有 `available=true` 才生成 authoritative rule snapshot；
3. `starter_consumed = state == "summoned"`；
4. `available=false/legacy_unknown` 必须让 rule snapshot fail-closed，不能默认成 `not_summoned`；
5. 不再从 rule snapshot 构造过程中调用 `monster_private_snapshot_v06()`。

## 最小验证

- `godot --headless --path . --script res://tests/monster_deploy_atomic_lifecycle_v06_test.gd` — PASS，`61/61`。
- `godot --headless --path . --quit-after 1 res://scenes/runtime/MonsterRuntimeController.tscn` — PASS。
- 回归包含：空 roster、成功首召、save/load、legacy unknown、连续查询、真实 WorldBridge 的 `rule → private` 回调一次结束、public snapshot 无 owner/private/transaction 字段。

依指令未运行完整垂直切片、full smoke、MCP 或有头验收，未访问默认 `user://`。

## 已知边界

- 本 API 只回答 owner 已持有的 starter 状态，不替代 main 的玩家卡牌资格、binding rule revision 或区域/profile facts。
- legacy unknown 是有意的安全阻断；旧存档迁移策略仍由统一存档/规则 owner 决定。
- 升级、移动、战斗、赌局、AI 与经济逻辑均未改动。
