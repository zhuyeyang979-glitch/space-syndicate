# Agent A SS06-06 商品库存与永久安装交接

日期：2026-07-14  
分支：`rules/v06-runtime-integration`  
范围：商品牌领取、满手合成、动态市场、永久安装、CommodityFlow 卡牌 batch 硬门，以及 A/B 生产组合收口。

## 结论

Agent A 的独占范围已经完成聚焦收口：

- `CardPlayerStateProductionAdapterV06` 是唯一 v0.6 Card Flow 生产状态端口。
- `CommodityCardInventoryWorldBridge` 不再参与组合，也没有第二套 lock/journal。
- `CardInventoryRuntimeService` 不再暴露另一套 v0.6 mutation API。
- `CommodityCardInventoryRuntimeController` 复用唯一的 `CardFlowTransactionServiceV06`，同时提供履带、市场、通用合成和通用出牌入口。
- `CommodityFlowRuntimeController` 仍是永久安装、一次性供需 batch、容量预留、Sale Receipt、租金与 GDP lineage 的唯一 owner。
- 商品安装与全局供需 batch 的 rollback window 都由 Card Flow transaction 的 effect-handler finalization 关闭，不再由控制器在 transaction 返回后直接 finalize。
- 公共设施牌在 `RegionInfrastructureRuntimeController` rollback 尚未原子化前继续以 `facility_rollback_atomicity_unavailable` fail-closed。

本轮没有修改 Agent B 的 `scripts/cards/v06/**` 生产文件或 B 专属测试，没有执行 commit、push、merge、`git add -A`，也没有运行会接触默认玩家存档的完整 smoke。

## A 侧修改与整合文件

生产与组合：

- `scripts/runtime/commodity_card_inventory_runtime_controller.gd`
- `scripts/runtime/commodity_card_effect_runtime_bridge.gd`
- `scripts/runtime/commodity_flow_runtime_controller.gd`
- `scripts/runtime/game_runtime_coordinator.gd` 中仅本任务节点配置、绑定和窄调用入口
- `scenes/runtime/GameRuntimeCoordinator.tscn` 中本任务静态节点
- `scenes/runtime/CommodityCardInventoryRuntimeController.tscn`
- `scenes/runtime/CommodityCardEffectRuntimeBridge.tscn`
- `scenes/runtime/CommodityFlowRuntimeController.tscn`

测试、Bench 与合同：

- `tests/commodity_card_inventory_runtime_test.gd`
- `scripts/tools/commodity_inventory_persistent_installation_bench.gd`
- `scenes/tools/CommodityInventoryPersistentInstallationBench.tscn`
- `docs/commodity_inventory_persistent_installation_runtime_contract.md`
- 本交接文件

已退出生产组合：

- `CommodityCardInventoryWorldBridge` 脚本/场景已移除。
- `CardInventoryRuntimeService` 中重复的 `configure_v06_card_flow` / `commit_v06_card_flow` 写入口已移除；调用图确认无消费者后没有保留 wrapper。

## Agent B 冻结贡献保留情况

已逐项保留并兼容 B 在协调边界前写入 `CommodityFlowRuntimeController` 的外部贡献：

- `prepare_card_effect_batch`
- `commit_card_effect_batch`
- `rollback_card_effect_batch`
- `finalize_card_effect_batch`
- pending one-shot demand/supply
- transaction journal 与 save/load
- authoritative supply/demand candidate snapshot
- flow plan、lineage 与 batch binding

A 补齐或加固了这些缺口：

- 候选来自当前 active production factories × 合法同色 market routes，而不是最近成交 receipt 的路线全集。
- receipt 只提供 player+product 的 30 秒 GDP 权重。
- 预期现金使用当前价格、距离溢价、租金和 `facts.game_time`。
- snapshot revision、fingerprint、candidate binding、共享容量聚合与 pending batch 占用均 fail-closed。
- extra demand 固定到已选 commodity owner、source factory、market、route、mode 与 distance。
- rollback 先校验 binding，再允许 exact-once replay。
- save/load 校验 pending child、batch binding、settled/rolled-back 状态和 rollback window。

Agent B 的只读交接基线位于：

- `reports/coordination/agent_b_core_economy_handoff.md`

其 8 项聚焦测试在当前组合树重新运行仍为 438/438。

## 唯一 owner 图

```text
world.players slots/cash ----------------------+
                                                   -> CardPlayerStateProductionAdapterV06
PlayerManaRuntimeController six-color assets ----+       |
                                                           v
CommodityCardInventoryRuntimeController -> CardFlowTransactionServiceV06
        |                                  | prepare/effect/state/finalize
        |                                  v
        +-> CoreEconomicCardRuntimeAdapterV06 -> Router / effect adapters
                                                   |
                                                   +-> CommodityFlowRuntimeController
                                                   +-> RegionInfrastructureRuntimeController
```

- Production adapter 只持有 reservation、lock、CAS、revision 和 journal；不复制手牌、现金或资产余额。
- Core Economic adapter 不创建第二个 transaction service。
- CommodityFlow 拥有安装、供需 claim、容量、成交和经济 receipt。
- RegionInfrastructure 拥有设施；其 rollback 原子性未达标，因此设施牌生产入口保持关闭。

## 冻结公开 API

### CommodityCardInventoryRuntimeController

- `configure(profile_snapshot, state_port, flow_controller, infrastructure_controller) -> Dictionary`
- `catalog() -> Resource`
- `configure_belt(revision, entries) -> Dictionary`
- `belt_snapshot() -> Dictionary`
- `claim_belt_card(actor_id, source_item_id, expected_player_revision, expected_belt_revision, transaction_id) -> Dictionary`
- `configure_market(revision, listing) -> Dictionary`
- `market_snapshot() -> Dictionary`
- `purchase_market_card(actor_id, source_item_id, next_listing, expected_player_revision, expected_market_revision, transaction_id) -> Dictionary`
- `manual_merge(actor_id, first_slot, second_slot, expected_player_revision, transaction_id) -> Dictionary`
- `play_commodity_card(actor_id, slot_index, target_context, expected_player_revision, transaction_id) -> Dictionary`
- `play_core_card(actor_id, slot_index, target_context, effect_handler, expected_player_revision, transaction_id) -> Dictionary`
- `to_save_data() -> Dictionary`
- `apply_save_data(data) -> Dictionary`

`play_core_card` 是复用同一内部 Card Flow transaction service 的通用端口；没有向调用方暴露第二个 transaction service 对象。

### CommodityFlowRuntimeController

- `install_commodity(request) -> Dictionary`
- `finalize_commodity_installation(receipt) -> Dictionary`
- `rollback_commodity_installation(transaction_id) -> Dictionary`
- `card_effect_candidates_snapshot() -> Dictionary`
- `prepare_card_effect_batch(plan) -> Dictionary`
- `commit_card_effect_batch(prepared) -> Dictionary`
- `finalize_card_effect_batch(receipt) -> Dictionary`
- `rollback_card_effect_batch(receipt) -> Dictionary`
- `card_effect_batch_snapshot(transaction_id) -> Dictionary`
- `to_save_data() -> Dictionary`
- `apply_save_data(data) -> Dictionary`

所有 snapshot、receipt、save data 和 report 均为纯数据。

## Rollback / finalize 生命周期

### 永久商品安装

1. Transaction service 调用 `EffectTransactionBoundary.prepare_effect`。
2. Commodity adapter/bridge 在 Flow owner 中创建 bound installation receipt。
3. Transaction service 提交唯一生产 state port 的手牌/现金/资产 delta。
4. Transaction service 主动调用 `EffectTransactionBoundary.finalize_effect`。
5. Flow receipt 变为 `finalized=true`、`rollback_open=false`。
6. 后续 rollback 返回 `installation_rollback_closed`，安装不被移除。

若步骤 3 失败，transaction service 在 state commit 前通过同一 effect boundary rollback 新安装；不会留下“卡未消费但安装已生效”的部分状态。

### 全局供需 batch

真实验证链为：

```text
CardFlowTransactionServiceV06
-> EffectTransactionBoundary
-> CoreEconomicCardEffectRouterV06
-> GlobalSupplyDemand adapter/planner
-> CommodityFlowAtomicBatchSinkV06
-> CommodityFlowRuntimeController
```

成功 state commit 后，transaction service 调用外层 boundary finalize。冻结的 B adapter 当前没有原生 finalize hook；router 明确返回 unsupported 后，boundary 从同一 bound effect receipt 中找到唯一 authoritative Flow receipt，校验 transaction/binding，并在 transaction lifecycle 内调用 Flow finalize。不存在 transaction 返回后的内部补写。Owner rollback window 关闭，后续返回 `batch_rollback_closed`。

Router 的原生 finalize journal 尚未记录这个 fallback；这不允许 owner 再回滚，但后续若 B 解冻，应把同样的 finalize 转发下沉到 adapter/sink，并删除 fallback，而不是建立第二个 owner。

## 设施牌硬门

`RegionInfrastructureRuntimeController.rollback_facility_action` 在完整 preflight 前仍可能删除当前 facility/slot，因此：

- `CommodityCardInventoryRuntimeController` 在 effect prepare 前检查 `facility_rollback_atomic_ready()`。
- readiness 不成立时返回 `facility_rollback_atomicity_unavailable`。
- 卡牌、现金、资产、revision 和设施状态均不改变。
- 没有伪造 compensation 成功。

解除硬门前必须由设施 owner 完成：完整 preflight、在副本构造 next state、一次替换、恶意 preimage 与 save/load 聚焦测试，以及成功后的 preimage 清理/finalize。

## 测试结果

当前组合树聚焦脚本：

| 测试 | 结果 | checks |
|---|---:|---:|
| card_flow_policy_v06_test.gd | PASS | 37 |
| card_flow_transaction_service_v06_test.gd | PASS | 69 |
| card_player_state_port_v06_test.gd | PASS | 65 |
| card_player_state_production_adapter_v06_test.gd | PASS | 44 |
| card_global_supply_demand_v06_test.gd | PASS | 122 |
| commodity_flow_candidate_snapshot_port_v06_test.gd | PASS | 4 |
| commodity_flow_atomic_batch_sink_contract_v06_test.gd | PASS | 7 |
| commodity_flow_atomic_batch_sink_v06_test.gd | PASS | 51 |
| card_core_effect_adapters_v06_test.gd | PASS | 34 |
| core_economic_card_effect_router_v06_test.gd | PASS | 76 |
| core_economy_production_integration_v06_test.gd | PASS | 65 |
| commodity_card_inventory_runtime_test.gd | PASS | 46 |
| **合计** | **PASS** | **620/620** |

场景门：

- `CommodityInventoryPersistentInstallationBench`: 49/49 passed。
- 新增真实外层门 `global_supply_demand_outer_finalize_closed` 已通过。
- 项目内 Godot MCP addon：`connected=true`，项目路径正确，目标 runtime root 与四个关键节点可查询，`get_errors=0`。
- manifest：`user://space_syndicate_design_qa/commodity_inventory_persistent_installation/manifest.json`
- report：`user://space_syndicate_design_qa/commodity_inventory_persistent_installation/report.md`
- screenshot：`user://space_syndicate_design_qa/commodity_inventory_persistent_installation_sprint_6.png`
- screenshot absolute path：`C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_design_qa/commodity_inventory_persistent_installation_sprint_6.png`

### B 冻结 Bench 的陈旧断言

`CoreEconomyProductionWiringV06Bench` 在 B 冻结时为 27/27，其中一项明确要求商品安装 `effect_finalization.finalized=false`，用于诚实报告当时的缺口。

A 关闭该缺口后，当前组合树该旧断言成为 26/27：

- stale case：`commodity_finalize_gap_reported_honestly`
- 当前真实值：`effect_finalization.finalized=true`

没有修改 B 的冻结 Bench，也没有恢复旧缺口。协调者解冻该证据时应把它改成“finalize 已闭合”的正向断言。

### 全局 composition 基线

`main_runtime_composition_test.gd` 当前仍为 22 项失败。失败集中在并行迁移已经移除/替换的旧 owner 与旧反射面：

- CityDevelopmentRuntimeController / WorldBridge
- EconomyCashflowRuntimeController
- GdpFormulaRuntimeController
- IndustryCapacityRuntimeService / WorldBridge
- 旧 Sprint 40/SS05-03/SS05-04/SS05-05/SS06-00 组合断言
- `main.gd` 已不存在的 `_capture_run_state` 反射入口

这些不是 SS06-06 回归，未恢复任何旧 owner 或 wrapper。应由 CityDevelopment/旧 owner 迁移协调者更新组合基线。

## 尚存风险与后续消费方式

1. 公共设施牌仍阻塞，必须先修 RegionInfrastructure 原子 rollback。
2. B 的 global adapter 尚无原生 finalize；当前由 transaction effect boundary 安全关闭 authoritative owner。B 解冻后可把转发下沉并移除 fallback。
3. Coordinator 已静态组合唯一 production state port 与 Core Economic adapter；按协调要求本轮没有继续扩大 Coordinator 公共 API。市场购买和统一 core-card UI 路由仍需后续明确 owner。
4. Production adapter 的 inflight reservation 尚无 checkpoint 恢复协议；保存应避免发生在 transaction 中间态。
5. 另一位 agent 的 UI/卡牌改动保持原样，本轮未修改其 production 文件、测试或视觉资产。

## Godot MCP 说明

本轮最终验证使用项目内 Godot MCP addon，在可见 Godot 4.7 编辑器中完成 open、scene tree、run、runtime query、screenshot、console、errors 与 stop。运行场景已停止，编辑器保持打开。

项目内 MCP addon 是编辑器开发/QA 工具，不是玩家运行时玩法依赖。
