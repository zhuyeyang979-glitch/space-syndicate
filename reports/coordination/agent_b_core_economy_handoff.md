# Agent B：v0.6 核心经济卡生产主循环接线交接

日期：2026-07-14  
项目：space-syndicate-sync  
交接范围：生产玩家状态 adapter、CardFlow 事务、核心经济效果 router、CommodityFlow 原子供需 batch sink、聚焦测试与独立 Godot 验证场景。

## 结论

Agent B 的独立生产接线已经形成可复核闭环：8 个本任务聚焦测试在当前工作树重新运行，合计 438 项检查全部通过；履带竞争、满手自动合成/安全拒绝、动态市场购买与连续刷新、精确现金/六色资产提交、商品永久安装、严格 candidate binding、原子供需 batch、rollback 与 transaction exact-once 均有测试证据。

但当前**不能宣称 main 已完整接入，也不能宣称公共设施牌已经可在生产对局打出**：

- 公共设施出牌被生产安全门以机器原因 facility_rollback_atomicity_unavailable 主动拒绝；卡牌、现金、资产和玩家 revision 均不改变。
- RegionInfrastructureRuntimeController.rollback_facility_action 仍存在“尚未完整验证 preimage 就先删除当前设施/slot”的原子性缺陷。最终整合者必须先修成“完整 preflight → 在副本构造 next state → 一次提交”，再增加/放开 facility_rollback_atomic_ready。
- 当前共享树中的 GameRuntimeCoordinator 场景已经出现 CardPlayerStateProductionAdapterV06 与 CoreEconomicCardRuntimeAdapterV06 节点，但这些热文件接线不是 Agent B 的写入，且协调层目前没有完整暴露市场购买和全部核心经济牌的玩家调用路径。必须做交叉 diff 与真实 main/UI 验证。
- 商品安装和全局供需的 owner rollback/finalize 生命周期仍未完整贯穿 transaction service → router → adapter → owner。

可以并行开始“怪兽与军队卡牌运行时 API”的独立合同、intent/receipt schema、adapter 和 focused test；在上述硬门关闭前，不应接入 main，也不应把核心经济主循环标记为生产完成。

## 写入边界与协作事实

### Agent B 独占写入范围

- scripts/cards/v06/card_flow_transaction_service_v06.gd
- scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd
- scripts/cards/v06/production/*
- 本任务专属 tests、tools scene、合同与报告

### Agent A / 最终整合者热文件

Agent B 在边界确认后没有继续写入以下文件：

- scripts/main.gd
- scripts/runtime/card_inventory_runtime_service.gd
- scripts/runtime/commodity_card_inventory_runtime_controller.gd
- scripts/runtime/commodity_flow_runtime_controller.gd
- scripts/runtime/commodity_card_*
- scripts/runtime/game_runtime_coordinator.gd
- scenes/runtime/GameRuntimeCoordinator.tscn
- scripts/runtime/region_infrastructure_runtime_controller.gd

当前共享树里这些文件包含其他 agent 或最终整合者的后续改动。Agent B 没有回滚、覆盖或重排这些改动，也没有执行 git add、commit 或 push。

### 边界更新前的 overlap

1. RegionInfrastructureRuntimeController.rollback_facility_action 的 rollback 工作发生在边界更新前。交叉审计发现它在验证 facility_before、slot_mapping_before、region_before 完整性之前，已经 erase 当前 facility/slot；失败可能留下半变更。协调者锁定由最终整合者修复，Agent B 随即停止写入该文件。
2. CommodityFlowRuntimeController 的 batch/demand/save/flow-plan/lineage/candidate hooks 有一部分发生在边界更新前。边界明确后，Agent B 停止写入；Agent A 补齐 candidate 构建 helper，并启用 snapshot revision/fingerprint、完整 candidate binding 与共享容量聚合硬门。
3. 严格 binding 上线后，Agent B 只修改自己拥有的 commodity_flow_atomic_batch_sink_v06_test.gd fixture：从真实 card_effect_candidates_snapshot 取得 candidate，原样携带 matching_product_gdp_30s，并把篡改 child 的预期原因更新为 batch_child_candidate_binding_changed。

## Agent B 修改文件清单

### 生产代码

- scripts/cards/v06/production/card_player_state_production_adapter_v06.gd
- scripts/cards/v06/production/commodity_flow_atomic_batch_sink_v06.gd
- scripts/cards/v06/production/commodity_flow_candidate_snapshot_port_v06.gd
- scripts/cards/v06/production/core_economic_card_effect_router_v06.gd
- scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd
- scripts/cards/v06/card_flow_transaction_service_v06.gd
- scripts/cards/v06/effects/global_supply_demand_runtime_service_v06.gd

### 合同与验证场景

- docs/card_flow_transaction_v06_contract.md
- scripts/tools/core_economy_production_wiring_v06_bench.gd
- scenes/tools/CoreEconomyProductionWiringV06Bench.tscn

### 聚焦测试

- tests/card_player_state_production_adapter_v06_test.gd
- tests/card_flow_transaction_service_v06_test.gd
- tests/commodity_flow_atomic_batch_sink_contract_v06_test.gd
- tests/commodity_flow_candidate_snapshot_port_v06_test.gd
- tests/commodity_flow_atomic_batch_sink_v06_test.gd
- tests/core_economic_card_effect_router_v06_test.gd
- tests/core_economy_production_integration_v06_test.gd

Godot 生成的同名 .uid sidecar 随对应脚本存在；交叉审计时应与逻辑文件一起检查，但不要把整个未跟踪目录批量加入版本控制。

## 删除、替换、推进

| 类别 | 项目 | 当前处理 |
|---|---|---|
| 删除/退出生产路径 | reference memory CardPlayerStatePortV06 作为生产真相 | 只保留为测试/reference port；生产 adapter 直接读写既有 owner |
| 删除 | 第二套手牌、现金、资产、商品或设施状态 | Agent B adapter/router/sink 均只保存锁、CAS、journal 或路由关联，不复制业务真相 |
| 删除 | generic 第七资产余额 | 禁止持久化 generic；通用费用从生命、能源、工业、科技、商贸、航运六色组合支付 |
| 删除 | “缺 rollback 也假装 rolled_back=true” | 已改为结构化 compensation；只有 owner 明确返回 rolled_back=true 才算成功 |
| 替换 | 玩家状态提交 | world.players 持有手牌与 cash/cash_cents；PlayerManaRuntimeController 兼容文件持有六色资产；production adapter 只做预留、每玩家 CAS 与精确 delta |
| 替换 | 效果分发 | 由 CoreEconomicCardEffectRouterV06 按 effect_kind 固定路由到商品、设施、订单、供货 owner |
| 替换 | 供需 planner 的直接经济写入 | planner 只分配；CommodityFlowAtomicBatchSinkV06 转发 prepare/commit/rollback，真实成交后才由 CommodityFlow 产生 Sale Receipt、现金、GDP、租金与资产恢复 |
| 替换 | 手工/fallback candidate | CommodityFlowCandidateSnapshotPortV06 只接受权威 snapshot；不允许 fallback candidate |
| 推进 | 设施牌生产可用 | 先修 RegionInfrastructure 原子 rollback，再解除 facility_rollback_atomicity_unavailable 安全门 |
| 推进 | owner 生命周期 | 补齐 commodity install rollback/finalize、facility finalize、global supply/demand finalize 链 |
| 推进 | main/UI | 为市场购买与全部核心经济牌提供协调层 API、玩家按钮状态和本地化失败反馈，并做真实 main 场景验证 |
| 推进 | 存档与恢复 | 增加 inflight checkpoint gate/恢复策略，防止加载后遗留孤儿资产预留 |

## Owner 与 adapter 关系

~~~mermaid
flowchart LR
    W["world.players<br/>手牌、cash/cash_cents 唯一 owner"]
    A["PlayerManaRuntimeController<br/>六色资产唯一 owner"]
    S["CardPlayerStateProductionAdapterV06<br/>锁、每玩家 revision/CAS、journal、精确 delta"]
    C["CommodityCardInventoryRuntimeController<br/>履带、市场、终端操作与共享 CardFlow"]
    T["CardFlowTransactionServiceV06<br/>prepare → effect commit → state commit → finalize"]
    R["CoreEconomicCardEffectRouterV06"]
    I["RegionInfrastructureRuntimeController<br/>设施唯一 owner"]
    F["CommodityFlowRuntimeController<br/>安装、一次性供需、Sale Receipt/GDP/租金唯一 owner"]
    P["GlobalSupplyDemandRuntimeServiceV06<br/>纯 planner/分配器"]
    Q["CandidateSnapshotPort<br/>只读权威候选"]
    B["AtomicBatchSink<br/>只转发 prepare/commit/rollback"]

    W --> S
    A --> S
    C --> T
    T --> S
    C --> R
    R --> I
    R --> F
    R --> P
    Q --> P
    F --> Q
    P --> B
    B --> F
~~~

职责边界：

- CardPlayerStateProductionAdapterV06 不拥有手牌、现金或资产；它只持有锁、预留、每玩家 revision/CAS 元数据和 exact-once journal。
- CoreEconomicCardRuntimeAdapterV06 不建立第二个 CardFlowTransactionService；它把出牌委托回 Agent A 的 CommodityCardInventoryRuntimeController.play_core_card。
- GlobalSupplyDemandRuntimeServiceV06 不制造商品、成交、GDP、租金或资产；它只基于权威候选和 GDP 权益做整数分配。
- CommodityFlowAtomicBatchSinkV06 不拥有商品、收据或经济状态；最终业务真相仍在 CommodityFlowRuntimeController。
- RegionInfrastructureRuntimeController 是设施产权、唯一槽、等级与区域生命池的权威 owner。

## 依赖 Agent A / 最终整合者的公开 API

| Owner | Agent B 依赖 API | 必须保持的合同 |
|---|---|---|
| CommodityCardInventoryRuntimeController | catalog、configure、bind_world、player_snapshot、configure_belt、claim_belt_card、configure_market、purchase_market_card、manual_merge、play_core_card、to_save_data、apply_save_data | 同一履带 item/market listing exact-once；市场立即刷新；连续购买必须用新 revision；只使用注入的 production state port |
| CommodityFlowRuntimeController | install_commodity、card_effect_candidates_snapshot、prepare_card_effect_batch、commit_card_effect_batch、rollback_card_effect_batch、finalize_card_effect_batch | candidate snapshot revision/fingerprint 与 allocation 完整绑定；共享容量聚合；save/load 后 transaction journal 仍 exact-once |
| RegionInfrastructureRuntimeController | region_snapshot、facilities_snapshot、slot_id、apply_facility_action、rollback_facility_action；未来 facility_rollback_atomic_ready | rollback 必须全量 preflight 后一次提交；未达到时 readiness 必须保持 false/缺失，使设施牌 fail-closed |
| PlayerManaRuntimeController | availability_snapshot、plan_reservation、commit_reservation、consume_reservation、release_reservation、to_save_data、apply_save_data | 只持有六色资产；不能把全局 tick revision 当作玩家 revision；预留/消耗/释放 exact-once |
| GameRuntimeCoordinator | 节点组合、公开玩家操作 API、save/load 编排 | 只能有一个生产状态端口；不得同时启用旧 bridge 与新 adapter；UI 不得直调内部 owner 绕过事务 |

当前共享树已经把新 adapter/runtime adapter 节点写入 GameRuntimeCoordinator.tscn，并在 coordinator 的 configure/bind 流程出现注入代码；这属于其他 agent/最终整合者改动。它还不能等同于“main 完整接入”，原因至少包括：

- 协调层当前公开了履带领取、合成和商品牌路径，但没有完整公开动态市场购买与四类核心经济效果统一出牌路径；
- 没有本任务范围内的真实 main/UI 玩家操作证据；
- 设施牌被安全门拒绝；
- finalize 链未闭合；
- 最终 MCP main/composition 验证仍应由整合者完成。

## 已落实的事务行为

### 牌源

- 商品履带免费领取；模糊区 item 不可领取。
- 两名玩家竞争同一 item，只有第一个符合 revision 的事务成功。
- 未满五张时，同名同级牌保持独立牌。
- 满手领取同名同级 I–III 时自动合成一次；IV 不再合成。
- 满手且不能合成时安全拒绝，不弃牌、不卖牌。
- 主动合成要求两张不同实例、同名、同级。
- 市场购买只扣一次现金，并与 next listing/market revision 原子刷新。
- 允许连续购买，但旧 listing revision 会被拒绝。
- transaction ID 重放返回 journaled result，不重复拿牌、扣款、刷新、合成或出牌。

### 生产玩家状态

- world.players.slots 与 cash_cents 是现有生产状态；cash 只是整数显示投影。
- 卡牌整单位现金变化按 ×100 应用于 cash_cents，保留商品流产生的分数分余额。
- 每名玩家独立 revision/CAS；PlayerMana 的全局 tick revision 不进入玩家 revision。
- effect commit 前先 prepare_reserved_mutations，预留精确六色资产 debit。
- commit 使用相对预留快照的精确现金/资产 delta，不会用旧快照覆盖预留期间新增的收入或资产恢复。
- 支持多玩家一组预留与卡牌实例跨 owner 原子移动。
- journal 可 save/load，已结算 transaction 重放不重复扣除。

### 商品与供需

- 商品牌免费打出到真实同色工厂/市场，安装结果由 CommodityFlow owner 持久化。
- 订单只增加一次性真实需求；供货只产生带具体来源工厂 ID 的一次性实体供货。
- 商品仍经过真实工厂、市场、合法路线、共享运输容量、仓库和 CommodityFlow tick。
- 多式联运按任一段包含指定方式满足标签；local/direct 不冒充 land。
- 成交后才产生正常 Sale Receipt；GDP 归商品 owner，设施 owner 只取得正常租金。
- batch 任一 child prepare 失败时整体零生效；transaction 重放不重复注入供需。

## 严格 candidate 与容量硬门

commodity_flow_atomic_batch_sink_v06_test.gd 现在先调用真实 card_effect_candidates_snapshot，再从真实 candidate 构造 allocation。allocation 必须携带：

- candidate_snapshot_revision 与 candidate_snapshot_fingerprint；
- candidate_id、商品 owner、product/industry、factory/market/region 及 revision；
- route、mode tags、shortest_legal_distance、capacity_resource_ids；
- candidate 原始 matching_product_gdp_30s；
- 一次性效果类型、child ID 与 allocated units。

当前测试证据：

1. 篡改 candidate/endpoint 后，prepare 返回 batch_child_candidate_binding_changed。
2. 上述拒绝前后的 CommodityFlow save data 完全相等，证明没有部分商品、需求、journal、receipt 或 revision 变化。
3. 单个 candidate 各自合法但聚合后超出同一共享资源容量时，prepare 返回 batch_shared_capacity_exceeded，仍为零副作用。
4. direct sink 测试没有提前 finalize；真实 flow tick 前 rollback 成功且重放 exact-once。
5. 一旦真实成交或显式 finalize 关闭窗口，后续 rollback 必须返回关闭状态。
6. save/load 后，已记录 transaction 仍不能重复注入需求或供货。

## Rollback / finalize 窗口与缺口

| 层级/owner | 当前 rollback | 当前 finalize | 窗口与缺口 |
|---|---|---|---|
| CardFlowTransactionServiceV06 | 结构化调用 owner；只接受 rolled_back=true | 玩家状态成功提交后调用 | rollback false 时返回 effect_compensation_failed，不伪造成功；玩家状态不提交，但外部效果可能残留，必须进入诊断/同步流程 |
| CoreEconomicCardEffectRouterV06 | 按已保存 transaction→effect_kind 绑定转发 | 只在 owner 明确 finalized=true 时关闭 association 并 journal | 缺 hook/失败会明确 finalized=false 并保留 association；finalize 成功后 rollback 返回 effect_rollback_closed |
| FacilityCardEffectAdapterV06 / RegionInfrastructure | adapter 有 rollback 转发 | 无 finalize | **P0**：owner rollback 不是原子 preflight，因此生产入口以 facility_rollback_atomicity_unavailable 阻塞；最终整合者修复后才可启用，并需增加成功后的 preimage 清理/finalize |
| CommodityCardEffectAdapterV06 / CommodityFlow install | owner 已有 rollback_commodity_installation | adapter 无 rollback 转发、无 finalize | state commit 失败时目前无法由 router 完整补偿；需要 adapter 转发 rollback，并定义安装成功后的 finalize/tombstone 清理 |
| GlobalSupplyDemand adapter/service/sink | adapter→service→sink 可 rollback batch | CommodityFlow 有 finalize_card_effect_batch，但外层链未完整转发 | rollback 只在 pending、真实 flow tick 前开放；Agent A controller 当前会在成功 transaction 后直接寻找嵌套 flow receipt 并 finalize，但 router/service 仍可能保持未 finalized，需统一唯一 finalize owner，避免双重或遗漏 finalize |
| CardPlayerStateProductionAdapterV06 | abort 释放预留；asset consume 失败尝试恢复 | commit 后写 terminal journal | save/load 对 inflight/prepared 事务仍需 checkpoint gate 或恢复协议，避免孤儿 PlayerMana reservation |

设施修复的明确接受条件：

1. rollback 开始前完整验证 original receipt、region revision、facility_after、facility_before、slot mapping、slot generation 与 region_before。
2. 在独立副本构造 next_regions、next_facilities、next_slot_map、next_generations。
3. 所有验证通过后一次替换 owner 状态；任何失败保持 before==after。
4. 增加聚焦测试覆盖恶意/损坏 preimage、重复 rollback、状态已变化和 save/load。
5. 只有上述测试与 MCP 场景通过后，facility_rollback_atomic_ready 才能返回 true；随后更新 Bench，从“安全拒绝”改为真实建造/升级/修复事务。

说明：core_economy_production_integration_v06_test.gd 中的设施成功案例直接使用 transaction service + adapter 以验证机制接线，绕过了 CommodityCardInventoryRuntimeController 的生产安全门；它不能证明当前生产入口可用。真实生产 Bench 验证的正确行为仍是安全拒绝。

## 测试结果

2026-07-14 在当前共享工作树重新运行：

| 测试 | 结果 | checks |
|---|---:|---:|
| card_player_state_production_adapter_v06_test.gd | PASS | 44 |
| card_flow_transaction_service_v06_test.gd | PASS | 69 |
| commodity_flow_atomic_batch_sink_contract_v06_test.gd | PASS | 7 |
| commodity_flow_candidate_snapshot_port_v06_test.gd | PASS | 4 |
| commodity_flow_atomic_batch_sink_v06_test.gd | PASS | 51 |
| core_economic_card_effect_router_v06_test.gd | PASS | 76 |
| core_economy_production_integration_v06_test.gd | PASS | 65 |
| card_global_supply_demand_v06_test.gd | PASS | 122 |
| **合计** | **PASS** | **438** |

独立场景文件 CoreEconomyProductionWiringV06Bench.tscn 已存在，现有验证记录为：

~~~text
CORE_ECONOMY_PRODUCTION_WIRING_V06_BENCH|status=PASS|checks=27|failures=0|terminology=assets
~~~

该 Bench 使用真实 PlayerManaRuntimeController、RegionInfrastructureRuntimeController、CommodityFlowRuntimeController、CommodityCardInventoryRuntimeController、新 production state adapter 与 core runtime adapter；不访问默认 user://。它明确断言设施安全门、商品安装、合成、履带、市场、cash_cents、六色资产和 exact-once。

Godot add-on MCP 已完成最终 run/debug/stop：Bench 为 PASS 27/27，debug errors=[]，停止结果 finalErrors=[]。这证明独立生产验证场景能够在真实 Godot 项目中运行，但不扩大为 main/UI 已完成接入的结论。

## 玩家文本、机器字段与开发字段

| 范围 | 可包含 | 不得包含/显示规则 |
|---|---|---|
| 玩家界面 | 本地化名称、效果、关键词、状态、feedback.reason、feedback.next_step；术语统一为“资产” | 不显示内部 ID、英文默认值、raw error；禁用提示必须同时说明原因和下一步 |
| 机器字段 | card_id、card_instance_id/runtime_instance_id、effect_kind/action_id、reason_code、transaction_id、intent_hash、target_hash、payload_hash、revision、candidate snapshot revision/fingerprint、prepared_token、plan_hash、receipt_kind、rolled_back、finalized | 只用于协议、存档、日志、回放和测试，不直接渲染 |
| 开发字段 | 脚本/资源路径、owner_result、compensation、state_port_receipt、debug snapshot、测试 label、raw debug output | 只出现在开发报告和诊断工具；不得作为玩家 fallback |

transaction compensation 的聚焦测试覆盖设施与商品流 owner rollback=false：

- 顶层 reason_code 为 effect_compensation_failed；
- rolled_back 保持 false，compensation_failed=true；
- machine diagnostics 保留 original_reason_code、state_port_reason_code、compensation.owner_result；
- 玩家 feedback 不包含 reason code、card ID、路径或模拟 raw reason；
- 卡牌、现金、六色资产和 revision 不会被提交为成功；
- transaction 重放不再次 commit/rollback。

PlayerManaRuntimeController 可暂时保留为内部兼容文件名；新 API、报告和玩家界面只能使用“资产”，不得把 mana/法力作为 fallback。

## 尚未完成与风险

### P0

1. 修复 RegionInfrastructure rollback 原子性，解除设施安全门；此前设施牌必须继续 fail-closed。
2. 补齐商品安装 rollback/finalize、设施 finalize、全局供需 finalize 的完整转发链。
3. 对当前共享 GameRuntimeCoordinator/main 改动做交叉 diff；确认运行时只有一个 production state port，且不存在旧 bridge 与新 adapter 双写。
4. Godot add-on MCP 独立 Bench 硬门已关闭：PASS 27/27、debug errors=[]、stop finalErrors=[]；设施 rollback 修复后仍须用更新后的 Bench 再验一次。

### P1

1. Production adapter 的 save data 保存 journal，但不保存 inflight/prepared；需要禁止事务中 checkpoint，或为 PlayerMana reservations 提供加载恢复。
2. 多玩家资产 consume 失败时目前使用 PlayerMana 整体 save snapshot 恢复；若未来引入异步/并行 owner 写入，可能覆盖无关变化。应增加 transaction-scoped batch consume/rollback API。
3. Production adapter 依赖可信 CardFlow 调用者。最终组合应注入窄 inventory transition validator，或限制 adapter 可见性，防止其他调用方直接提交“形状合法但流程非法”的手牌快照。
4. 市场 next_listing 当前由调用方提供；还需要权威随机/价格/listing generator，避免 UI 决定下一张牌或价格。
5. CommodityCardInventory save/load 需要最终整合者审计完整 preflight、空市场清理、belt/market revision 单调性和多个 journal 的一致恢复。
6. 协调层还需公开 purchase_market_card 和统一 play_core_card 路径，并将玩家反馈映射到真实 UI。

### 明确未接入

- 怪兽牌效果；
- 军队牌效果；
- 玩家互动牌；
- 反制牌；
- 上述效果与 card transaction 的生产 owner、rollback/finalize 和 UI 路径。

## 交叉验证命令

在项目根目录运行以下聚焦测试；这些命令不启动完整 main，也不接触默认 user:// 存档：

~~~powershell
$godot = (Get-Command godot).Source
$tests = @(
  "tests/card_player_state_production_adapter_v06_test.gd",
  "tests/card_flow_transaction_service_v06_test.gd",
  "tests/commodity_flow_atomic_batch_sink_contract_v06_test.gd",
  "tests/commodity_flow_candidate_snapshot_port_v06_test.gd",
  "tests/commodity_flow_atomic_batch_sink_v06_test.gd",
  "tests/core_economic_card_effect_router_v06_test.gd",
  "tests/core_economy_production_integration_v06_test.gd",
  "tests/card_global_supply_demand_v06_test.gd"
)
foreach ($test in $tests) {
  & $godot --headless --path . --script ("res://" + $test)
  if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
~~~

跨边界回归还应运行：

~~~powershell
$extra = @(
  "tests/card_runtime_catalog_v06_test.gd",
  "tests/card_flow_policy_v06_test.gd",
  "tests/card_player_state_port_v06_test.gd",
  "tests/card_core_effect_adapters_v06_test.gd",
  "tests/commodity_card_inventory_runtime_test.gd",
  "tests/asset_terminology_v06_test.gd",
  "tests/ui_text_smoke_test.gd"
)
foreach ($test in $extra) {
  & $godot --headless --path . --script ("res://" + $test)
  if ($LASTEXITCODE -ne 0) { throw "Regression failed: $test" }
}
~~~

MCP 交叉验证顺序：

1. 识别 Godot 版本与 space-syndicate-sync 项目。
2. 打开真实项目。
3. 运行 res://scenes/tools/CoreEconomyProductionWiringV06Bench.tscn。
4. 读取 debug output，确认 status=PASS、checks=27、failures=0。
5. 停止项目，确认 finalErrors=[]。
6. 设施 rollback 修复后，更新 Bench 预期并重复相同流程。

## 最终整合清单

- [ ] RegionInfrastructure rollback 完整 preflight/副本/一次提交。
- [ ] facility_rollback_atomic_ready 仅在修复与测试通过后返回 true。
- [ ] Facility owner 成功后的 finalize/preimage 清理。
- [ ] CommodityCardEffectAdapter 转发 rollback_commodity_installation，并定义 finalize。
- [ ] Global supply/demand 的 sink → service → adapter → router finalize 链闭合且 exact-once。
- [ ] 只有一个 CardPlayerStateProductionAdapterV06 写入 world.players/PlayerMana。
- [ ] 市场购买与统一 core card play 暴露给 coordinator/UI。
- [ ] 存档 checkpoint/inflight 恢复策略。
- [ ] 玩家界面术语与泄漏测试为 0。
- [x] 本批 Agent B 聚焦测试与真实 MCP Bench 已通过（438 checks；Bench 27/27；errors=[]；finalErrors=[]）。
- [ ] 设施 rollback 与最终整合改动完成后的跨边界回归、更新后 MCP Bench 全部通过。

## 下一阶段判断

当前可以复用 transaction binding、每玩家 CAS、结构化 compensation、exact-once、玩家文本隔离原则，开始怪兽/军队独立运行时 API 的合同和 focused tests。

在设施 rollback、owner finalize 与 main/UI 集成硬门关闭前：

- 不把怪兽/军队接入生产主循环；
- 不宣布公共设施牌可在真实对局打出；
- 不宣布 main 已完整接入；
- 不宣布 v0.6 核心经济卡生产主循环完成。
