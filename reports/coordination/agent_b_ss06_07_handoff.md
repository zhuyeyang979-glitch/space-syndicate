# Agent B SS06-07 Monster & Military Card Runtime Contract v0.6 Handoff

日期：2026-07-14  
分支/工作树：共享工作树，未 commit、push、merge 或 `git add -A`  
证据等级：`focused` + 独立 Bench `runtime`；production 仍 blocked

## 结论

SS06-07 独立运行时骨架已完成：字段化 schema、怪兽/军队 forwarding ports、effect adapters、transaction→effect 权威 router、reference owner、public/private/developer receipt filter 与 inflight checkpoint gate 均已实现。五项聚焦测试 `187/187`，Godot 4.7 add-on MCP 独立 Bench `54/54`，最终 debug `errors=[]`、stop `finalErrors=[]`。

真实 `MonsterRuntimeController` 与 `MilitaryRuntimeController` 仍是各自唯一业务 owner，但缺少 revisioned prepare/commit/rollback/finalize/exact-once/checkpoint 合同。真实 mutating path 因此在 prepare 入口明确 fail-closed；本轮没有调用旧 bool mutation、没有更改真实 roster，也没有把 reference owner 成功宣称为 production 成功。

## 执行边界

本轮未修改：

- `scripts/main.gd`；
- `GameRuntimeCoordinator.gd/.tscn`；
- CardInventory、CommodityCardInventory、CommodityFlow、RegionInfrastructure；
- `monster_runtime_controller.gd`、`military_runtime_controller.gd`；
- 冻结的核心经济 transaction/router/production 文件；
- Agent A 文件、中央 `agent_knowledge_index.md`。

未运行访问默认 `user://` 的 full smoke，未终止其他 Agent 的 Godot 进程。

## 修改文件

合同：

- `docs/monster_military_card_runtime_v06_contract.md`

新增运行时骨架（`scripts/cards/v06/units/`）：

- `unit_card_runtime_schema_v06.gd`
- `unit_card_owner_forwarding_port_v06.gd`
- `monster_card_owner_port_v06.gd`
- `military_card_owner_port_v06.gd`
- `monster_card_effect_adapter_v06.gd`
- `military_card_effect_adapter_v06.gd`
- `unit_card_effect_router_v06.gd`
- `unit_card_receipt_filter_v06.gd`
- `unit_card_checkpoint_gate_v06.gd`
- `unit_card_reference_owner_v06.gd`
- Godot 导入为上述脚本生成的 `.gd.uid` sidecars

聚焦测试：

- `tests/monster_card_runtime_v06_test.gd`
- `tests/military_card_runtime_v06_test.gd`
- `tests/unit_card_effect_router_v06_test.gd`
- `tests/unit_card_privacy_v06_test.gd`
- `tests/unit_card_owner_capability_v06_test.gd`

独立 Bench：

- `scenes/tools/MonsterMilitaryCardRuntimeV06Bench.tscn`
- `scripts/tools/monster_military_card_runtime_v06_bench.gd`

报告：

- `reports/cards/monster_military_runtime_v06/owner_capability_matrix.md`
- `reports/cards/monster_military_runtime_v06/effect_support_matrix.md`
- `reports/cards/monster_military_runtime_v06/validation.md`
- `reports/cards/monster_military_runtime_v06/godot_mcp_call_log.md`
- 本 handoff

## 稳定 API

### Schema

`UnitCardRuntimeSchemaV06`：

- `make_intent(...) -> Dictionary`
- `normalize_card_flow_intent(raw_intent, expected_owner_revision, action_kind) -> Dictionary`
- `validate_intent(intent) -> Dictionary`
- `binding_from(...)` / `binding_matches(...)`
- `fingerprint(...)`：规范化 JSON 的 SHA-256
- `unit_intent_fingerprint(...)`

外层 `intent_hash/target_hash/payload_hash` 保持唯一 Card Flow transaction 的绑定；`unit_intent_fingerprint` 再绑定 action、unit owner revision 与外层哈希。Receipt 全阶段必须保持这些字段一致。

### Owner ports/adapters

Monster/Military adapter 均提供：

- `configure(authoritative_owner)`
- `prepare_effect(intent)`
- `commit_effect(prepared)`
- `rollback_effect(receipt)`
- `finalize_effect(receipt)`
- `abort_prepared_effect(prepared)`
- `capability_matrix()`
- `checkpoint_status()`

Port 只有在 owner 显式声明 v0.6、方法实际存在、全部原子能力为 true、effect/action 在 allowlist 时才转发 mutation。相似旧方法或 bool 返回不构成能力证明。

### Router/filter/gate

- `UnitCardEffectRouterV06.configure(handlers_by_effect_kind)` 后实现标准 effect handler 四阶段接口。
- Router 只使用 prepare 保存的 transaction association 选择 handler；后续 receipt 自报 effect/action 不能改路由。
- `UnitCardReceiptFilterV06.public_view/private_view/developer_view/public_leak_scan` 执行显式 allowlist 与递归清洗。
- `UnitCardCheckpointGateV06` 对 router 与所有 owner/adapter 的 checkpoint 状态取逻辑 AND。

## Owner/API 依赖

冻结的未来接线入口：

```gdscript
CommodityCardInventoryRuntimeController.play_core_card(
    actor_id,
    slot_index,
    target_context,
    effect_handler,
    expected_player_revision,
    transaction_id
)
```

未来可把 `UnitCardEffectRouterV06` 作为 `effect_handler` 注入，继续复用唯一 `CardFlowTransactionServiceV06`。冻结入口原始 intent 使用 `effect_payload` 且没有 unit action/revision 顶层字段；router 会保持外层绑定并归一为 `effect_fields`。调用方必须在 `target_context.expected_owner_revision` 提供权威 unit revision；正式 deploy/upgrade action 可由 effect kind 推导，动态 lure/skill/command 必须显式提供 `action_kind`。

不需要也不得创建第二个 Card Flow transaction service、玩家状态端口、手牌、现金、六色资产或 unit roster。

## 支持矩阵

| Effect/action | Schema/router | Reference owner | 真实 owner |
| --- | --- | --- | --- |
| 怪兽 deploy/upgrade | 支持 | 支持 | Blocked：`monster_owner_atomic_contract_missing` |
| 怪兽 lure once | 支持 | 支持一次消费/exact-once | Blocked；正式 v0.6 目录也缺条目 |
| 怪兽 move/attack/guard/area suppress 固定技能 | 字段化支持 | 只验证 intent 状态机，不模拟公式 | Blocked；缺 v0.6 profile 与 owner 原子 API |
| 军队 deploy/upgrade | 支持 | 支持 | Blocked：`military_owner_atomic_contract_missing` |
| 军令 move/guard/attack monster/suppress region | 字段化支持 | 支持 exact-once command acceptance | Blocked；缺 v0.6 command profile 与跨 owner 补偿 |

正式目录的可执行审计事实：

- `deploy_or_upgrade_monster`：32 张（8 家族 × I–IV）；
- `deploy_or_upgrade_military`：28 张（7 家族 × I–IV）；
- 正式 `monster_lure_once / monster_bound_action / military_reusable_command`：当前均为 0；旧动态卡不能按中文名偷渡为 v0.6 支持。

## 测试结果

| Test | Checks | Result |
| --- | ---: | --- |
| Monster runtime | 52 | PASS |
| Military runtime | 49 | PASS |
| Unit router | 41 | PASS |
| Privacy | 17 | PASS，public leak 0 |
| Owner capability/catalog | 28 | PASS |
| **Focused total** | **187** | **PASS** |
| Godot MCP Bench | **54** | **PASS** |

最终 MCP：Godot `4.7.stable.official.5b4e0cb0f`，真实场景运行，`errors=[]`，`finalErrors=[]`。完整调用记录见 `godot_mcp_call_log.md`。

## 运行中发现并修复的问题

Router 初版在 owner 返回 `finalized=false` 后把 stage 记录为 `finalize_failed`，但重试只允许 `committed`，会永久阻塞 checkpoint。聚焦测试将其复现后，现改为 `committed` 或 `finalize_failed` 均可使用保存的 authoritative committed receipt 重试；只有 owner 明确 `finalized=true` 才终结。

MCP 首轮还发现两个命名遮蔽 warning；均在独占文件内改名，最终 debug 清零。

## 跨 owner 接口需求

### MonsterRuntimeController owner

- Observed：只有直接 bool mutation；升级剩余时间语义与 v0.6 `+60 seconds` 不一致；旧 roster public snapshot 仍可能含 lure 细节。
- Severity：P1 production blocker；可能重复 lure、留下不可补偿 roster/inventory/world 副作用或泄露隐藏信息。
- Required owner：Monster runtime owner。
- Required interface：本合同第 5 节六个 lifecycle/capability/checkpoint 方法、单调 revision、稳定 unit/region binding、v0.6 duration policy、隐私安全 snapshot。
- Evidence：owner capability test、只读 matrix、Reference Bench；真实 adapter roster before==after。
- Boundary：Agent B 未编辑该 owner 文件。

### MilitaryRuntimeController owner

- Observed：deploy/command 为直接 bool mutation；guard/strike/attack 的下游 receipt 传播与 rollback/finalize 不足；旧 bound UID 语义不能证明 exact-once。
- Severity：P1 production blocker；可能出现 cooldown/运动已生效但下游效果失败，或旧军令控制新单位。
- Required owner：Military runtime owner。
- Required interface：同一 lifecycle API、command instance+unit revision 绑定、跨 Region/Monster owner 的结构化 prepare/commit/rollback/finalize receipt。
- Evidence：owner capability test、只读 matrix；真实 adapter roster before==after。
- Boundary：Agent B 未编辑该 owner 文件。

### Card catalog/profile owner

- Observed：正式 v0.6 JSON 只有 32+28 张单位 deploy/upgrade；lure、固定兽技、可回收军令仍是旧动态资源，缺稳定 action/profile 与资产费用定义。
- Severity：P1 content/runtime integration blocker；不能安全路由或验证费用/目标。
- Required interface：稳定 `effect_kind/action_kind/profile_id`、target schema、六色资产费用、公开范围、持续/终止、hand-limit 规则和 owner capability allowlist。
- Evidence：catalog focused test 与 effect support matrix。
- Boundary：Agent B 未编辑目录或旧资源。

## 未来接入 Coordinator 的最小步骤

1. Monster/Military owner 分别实现并聚焦验证 v0.6 lifecycle、revision、journal、checkpoint API。
2. Catalog owner 正式迁移 lure/skill/command profiles；没有 profile 的 action 保持 unsupported。
3. Coordinator 只组合两个 owner adapter 与一个 Unit router，不创建新玩家状态或 transaction service。
4. UI 调用现有 `play_core_card(...)`，在 target context 携带权威 owner revision/action；失败显示本地化 reason + next step。
5. 玩家状态 commit 失败时，经保存的 transaction association 调用 owner rollback；只有明确 `rolled_back=true` 才算补偿。
6. 玩家状态 commit 成功后 owner finalize；成功前禁止 checkpoint。
7. 主路径接线后再增加跨 owner、save/load replay、真实移动/伤害与玩家 UI 集成验证。

## Lessons for other agents

### SS06-08 reviewed patterns adopted

- **Response ID journal 与 transaction journal 不可互代：已采用。** SS06-07 只实现单位效果的 transaction association/journal，用于 exact-once、rollback 与 finalize；本轮没有 response ID journal，也没有用 transaction journal 冒充公共响应身份账本。未来若为公开事件增加稳定 response ID，必须由独立 journal 管理，并通过明确 binding 引用 transaction，而不是复用其生命周期状态。
- **Reference owner 不是 production：已采用。** `UnitCardReferenceOwnerV06` 只作为合同状态机的 positive control；真实 Monster/Military owner 的能力矩阵、fail-closed 结果和 production blocker 始终单独报告。
- **递归 sanitizer + 独立递归 leak scanner：已采用。** `UnitCardReceiptFilterV06.public_view()` 先执行 allowlist 与递归清洗，`public_leak_scan()` 再以独立递归遍历检查嵌套 Dictionary/Array；聚焦隐私测试与 MCP Bench 均要求 `leak_count=0`。

### invariant

一个运行时领域只有一个业务状态 owner。Adapter 可以保存 binding、reservation、CAS metadata 和 journal，但不能复制 unit roster/owner truth。所有 rollback/finalize 必须由 prepare 保存的 transaction→effect 关联路由，reference owner 永远不等于 production owner。

### failed approach

看似合理但错误的做法包括：把旧 bool API 包装成 committed receipt；相信后续 receipt 自报 effect kind；只检查 public receipt 顶层字段；在 `finalize_failed` 后清掉或锁死关联。最后一项曾被测试真实捕获，正确做法是保留 committed receipt、继续阻止 checkpoint，并允许 owner finalize 重试。

### stable API

稳定版本为 `v0.6`。Binding 使用外层 transaction/target/payload hash 加 `unit_intent_fingerprint`（SHA-256）；owner 必须显式声明能力并实现 prepare/commit/rollback/finalize/checkpoint。冻结生产入口仍是 `play_core_card(..., effect_handler, ...)`。

### test oracle

最小事务 oracle：prepare 后 checkpoint=false；commit 恰好一次；注入 rollback=false 时 `rolled_back` 仍 false 且 checkpoint=false；关闭故障后 rollback=true 并恢复 preimage。Finalize 同理：第一次 false 不关闭，重试 true 后 checkpoint=true。隐私 oracle 必须在嵌套 Dictionary/Array 注入 owner/cash/hand/AI/raw 字段并得到 leak_count=0。

### integration trap

冻结 Card Flow raw intent 没有 unit owner revision/action 顶层字段；若直接注入 router 而不在 target/payload 提供这些字段，会正确 fail-closed。不要改写外层 `intent_hash` 或用 UI 当前选区替代已哈希 target。另一个陷阱是多 Agent 同时跑 Godot 导入导致锁争用，应错峰运行并只停止自己启动的进程。

### reusable pattern

可复用模式是：strict schema → capability-gated forwarding port → authoritative transaction router → explicit owner stage receipt → public allowlist/recursive sanitizer → AND checkpoint gate。成功、失败、重放都使用同一 immutable binding。

### stale evidence

Reference Bench 的 PASS 只证明合同状态机，不证明真实 owner 接线；任何旧报告将它描述为 production 均为 stale。首轮 MCP 两条 warning 已修复，最终 `errors=[]` 才是有效 runtime evidence。另据 Agent A handoff，冻结 CoreEconomy Bench 的 `commodity_finalize_gap_reported_honestly` 已因缺口关闭而成为陈旧断言，不应恢复旧 bug。

### next dependency

最小下一依赖是两个真实 owner 各自提供带稳定 UID/region fingerprint 与单调 revision 的六阶段 capability/lifecycle/checkpoint API；Catalog owner 同时提供正式 lure/skill/command profile。缺任一项，production mutation 继续 fail-closed。
