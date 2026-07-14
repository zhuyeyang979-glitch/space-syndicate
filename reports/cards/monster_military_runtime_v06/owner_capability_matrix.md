# SS06-07 Unit Owner Capability Matrix

日期：2026-07-14  
证据范围：只读审计 `MonsterRuntimeController`、`MilitaryRuntimeController`、现有 ownership contract 与新增 v0.6 unit-card forwarding contract。

## 结论

`MonsterRuntimeController` 与 `MilitaryRuntimeController` 仍分别是怪兽和军队世界状态的唯一生产 owner，但都没有声明或实现 v0.6 unit-card 原子事务协议。两者可提供 roster/debug 读取和旧运行时 save/load，却不能提供 revisioned prepare、exact-once commit、preimage rollback、finalize 或 inflight checkpoint gate。

因此两个生产转发端口的 `atomic_mutation_ready` 均为 false。所有真实 mutating intent 必须在 prepare 前失败闭合：怪兽使用 `monster_owner_atomic_contract_missing`，军队使用 `military_owner_atomic_contract_missing`。旧 bool API、直接 mutation API 或 reference owner 的成功均不得包装成生产成功。

## Owner capability matrix

| Capability | v0.6 硬要求 | `MonsterRuntimeController` | `MilitaryRuntimeController` | 生产结论 |
| --- | --- | --- | --- | --- |
| 唯一世界状态 owner | 必须 | 是：怪兽 roster、生态、行动、战斗、赌局与存档 | 是：军队 roster、部署、移动、军令与存档 | 保留，不复制第二套状态 |
| Snapshot | 应有纯数据、安全视图 | 有 `roster_snapshot`、selected/wager snapshot、`debug_snapshot` | 有 `roster_snapshot`、`debug_snapshot` | 只读可用；未声明 `privacy_safe_snapshot`，不得直接公开 |
| Save/load | 必须覆盖生产状态 | 有 `to_save_data` / `apply_save_data` | 有 `to_save_data` / `apply_save_data` | 只覆盖旧运行时状态，不覆盖 v0.6 inflight 事务 |
| v0.6 capability declaration | 必须 | 无 `unit_card_runtime_capabilities_v06` | 无 `unit_card_runtime_capabilities_v06` | false |
| 单调 unit-card revision | 必须 | 无 | 无 | false；不能检测 stale intent |
| Prepare | 必须无副作用预留 | 无 | 无 | false |
| Commit | 必须 exact-once + 结构化 receipt | 旧入口返回 bool 或私有函数直接修改 roster/世界/库存 | `summon_from_card`、`trigger_command` 返回 bool 并直接修改 roster/世界/库存 | false |
| Rollback | 必须恢复 preimage | 无 | 无 | false |
| Finalize | 必须明确关闭 rollback window | 无 | 无 | false |
| Exact-once journal | 必须 | 无 | 无 | false；重放可能重复生效 |
| Inflight checkpoint gate | 必须 | 无 | 无 | false；不能安全保存 prepared/committed 未终结事务 |
| Privacy-safe snapshot declaration | 必须显式声明 | 无 | 无 | false；旧 `include_private`/viewer 参数不能替代合同声明 |
| Movement owner | adapter 不得重算 | 已有线性米/秒移动与自主生态 | 已有线性米/秒移动 | 只能转发，不得在 adapter 瞬移 |
| Combat/damage owner | adapter 不得重算 | 拥有怪兽护甲/HP/倒地/击退与行动伤害 | 军队命令委托区域/路线与怪兽 owner | 只能转发，不能复制公式 |
| `atomic_mutation_ready` | 上述 mutation 能力全为 true | **false** | **false** | 所有真实 mutation fail-closed |

## 现有 API 的只读或旧语义定位

### MonsterRuntimeController

可安全确认的职责：

- `roster_snapshot(include_private)`、`selected_actor_snapshot(include_private)`、wager snapshot；
- `to_save_data()` / `apply_save_data()`；
- 怪兽自主选目标、一次性 lure 消费、线性移动、攻击、击退、倒地和赌局；
- `take_external_damage()` 作为其他权威系统伤害怪兽的既有入口。

不能作为 v0.6 unit-card commit 的入口：

- `resolve_targeted_skill(...) -> bool` 会直接改变 lure 或技能状态，没有 prepare/preimage/receipt；
- `_summon_monster_from_card(...)` 与 `_upgrade_field_monster_from_card(...)` 是私有、直接 mutation，并会编排固定技能库存；
- 当前升级把 `remaining_time` 重置为完整 `duration`，与 v0.6 `add_to_remaining_time + 60 seconds` 不一致；
- 旧 owner 没有 transaction replay journal，不能证明 lure 或技能恰好消费一次。

### MilitaryRuntimeController

可安全确认的职责：

- `roster_snapshot(include_private)`、`debug_snapshot(viewer_index)`；
- `to_save_data()` / `apply_save_data()`；
- 线性移动、冷却、保卫、区域压制/摧毁和攻击怪兽的权威执行；
- 通过现有怪兽/区域/路线 owner 处理跨域 mutation。

不能作为 v0.6 unit-card commit 的入口：

- `summon_from_card(...) -> bool` 直接部署/刷新并授予固定军令；
- `trigger_command(...) -> bool` 直接启动移动、冷却或世界 mutation；
- 达到上限时刷新最早军队的旧行为不能替代 v0.6 “升级自己的同族军队”目标约束；
- 没有 command transaction journal，重放同一事务可能重复下令。

## 必须补齐的 owner API

两个真实 owner 都必须显式实现：

```gdscript
func unit_card_runtime_capabilities_v06(domain: String) -> Dictionary
func prepare_unit_card_intent_v06(intent: Dictionary) -> Dictionary
func commit_unit_card_intent_v06(prepared: Dictionary) -> Dictionary
func rollback_unit_card_intent_v06(receipt: Dictionary) -> Dictionary
func finalize_unit_card_intent_v06(receipt: Dictionary) -> Dictionary
func unit_card_checkpoint_status_v06(domain: String) -> Dictionary
func unit_card_snapshot_v06(domain: String) -> Dictionary
```

capability 声明必须真实列出 `contract_version/revision/prepare/commit/rollback/finalize/exact_once/checkpoint_gate/privacy_safe_snapshot` 和支持的 effect/action 列表。forwarding port 只有在版本匹配、方法存在、声明为 true 且 action 在允许列表时才可放行。

## 不可伪造成功的证明条件

以下任一情况都必须返回结构化失败，而不是成功：

- 只得到旧 API 的 `true`，但没有绑定完整的 Dictionary receipt；
- receipt 缺少 `transaction_id`、外层 `intent_hash`、`unit_intent_fingerprint`、`effect_kind`、`action_kind`、目标/载荷指纹或 expected owner revision；
- owner 未显式声明 exact-once，却由 adapter 自行记一个成功 bool；
- rollback 返回 false、无结构或 binding 不匹配，却记录 `rolled_back=true`；
- finalize 未实现或失败，却关闭 router 关联或 checkpoint gate；
- adapter 自行修改 roster、消费 lure、启动移动、计算伤害或授予军令；
- 使用 reference owner 的成功来宣称真实 owner 已接线；
- 旧 save/load 可以保存 roster，但不能恢复 inflight reservation、preimage 和 journal，却仍允许 checkpoint。

真实成功至少需要 owner 明确返回：

- prepare：`prepared=true`；
- commit：`committed=true`，且相同事务重放返回原 receipt；
- rollback：仅在 preimage 确实恢复后 `rolled_back=true`；
- finalize：仅在 rollback window 确实关闭后 `finalized=true`；
- 全阶段 binding 与 router 保存的权威关联完全一致。

## Reference owner 的边界

`UnitCardReferenceOwnerV06` 声明 revision、prepare、commit、rollback、finalize、exact-once、checkpoint gate 与隐私安全 snapshot，用于独立 Bench 和聚焦合同验证。它只维护 reference state，不是生产怪兽或军队 owner，也不执行真实生态、移动、战斗、区域伤害、库存或经济结算。它的成功不能改变本矩阵中两个生产 owner 的 false 结论。
