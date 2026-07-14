# 《太空辛迪加》v0.6 核心经济卡生产接线验证报告

验证日期：2026-07-14  
验证范围：生产玩家状态端口、商品履带/动态市场/合成事务、核心经济效果 router、CommodityFlow 原子供需 batch sink，以及独立真实 Godot 场景 `CoreEconomyProductionWiringV06Bench`。  
不在本报告范围：怪兽、军队、玩家互动与反制效果；`main.gd`、`GameRuntimeCoordinator` 和 Agent A 热文件的最终整合。

## 结论先行

独立生产接线与聚焦测试当前全部通过。真实 Godot 场景以生产 owner、生产玩家状态 adapter 和现有卡牌源运行了 27 项检查，验证了主动合成、履带领取、市场购买与立即刷新、精确现金扣除、商品安装、六色资产以及 transaction exact-once。严格 CommodityFlow candidate snapshot、权威绑定与共享容量聚合门禁均已覆盖。

但本批次仍不能宣布“生产主循环已经在主游戏中完整可用”：公共设施出牌因设施 rollback 的已知原子性缺陷而主动 fail-closed；新的生产玩家状态 adapter 尚未由最终整合者替换当前生产组合中的旧 bridge；部分效果 owner 还缺少完整 rollback/finalize 转发。Godot add-on MCP 的真实运行、debug output 与停止硬门已经通过。

因此，**可以开始下一阶段“怪兽与军队卡牌运行时 API”的接口合同与独立 adapter 工作，但不得把它们接入主运行时，也不得把本阶段标记为生产完成，直到下述硬门关闭。**

## 真实场景验证

场景：`res://scenes/tools/CoreEconomyProductionWiringV06Bench.tscn`  
驱动：`res://scripts/tools/core_economy_production_wiring_v06_bench.gd`  
Godot：`4.7.stable.official.5b4e0cb0f`

本地真实场景 CLI 复核命令：

```powershell
godot_console.cmd --headless --path . --quit-after 60 res://scenes/tools/CoreEconomyProductionWiringV06Bench.tscn
```

输出：

```text
CORE_ECONOMY_PRODUCTION_WIRING_V06_BENCH|status=PASS|checks=27|failures=0|terminology=assets
```

场景使用真实 `PlayerManaRuntimeController`（兼容文件名）、`RegionInfrastructureRuntimeController`、`CommodityFlowRuntimeController`、`CommodityCardInventoryRuntimeController`，并注入 `CardPlayerStateProductionAdapterV06` 与 `CoreEconomicCardRuntimeAdapterV06`，没有建立第二套手牌、现金、资产、商品或设施 owner，也没有访问默认 `user://` 存档。

已验证的运行行为：

- 两张同名同级商品牌主动合成为 II 级；
- 可见履带商品只领取一次，重放返回 exact-once 回执；
- 动态市场只扣一次现金，`cash_cents` 与整数展示同步，买走后 listing revision 从 8 原子推进至 9；
- 公共设施出牌命中 `facility_rollback_atomicity_unavailable` 安全门禁，手牌、现金、资产和 revision 均未改变；
- Bench 通过设施权威 owner 建立测试工厂后，商品牌成功永久安装至真实 CommodityFlow owner；
- 商品牌 transaction 重放不产生第二份安装；
- 商品 effect owner 尚未完成 finalize 的事实被结构化报告为 `finalized=false`，没有伪造成功；
- 玩家余额只含生命、能源、工业、科技、商贸、航运六色资产，不存在 generic 余额池。

说明：以上 CLI 复核另有下文的 add-on MCP 独立验收，不以命令行结果代替 MCP。

## 聚焦测试结果

以下结果均在当前工作树、Godot 4.7 下重新执行：

| 测试 | 结果 | 检查数 | 主要覆盖 |
|---|---:|---:|---|
| `card_runtime_catalog_v06_test.gd` | PASS | 1363 | v0.6 全目录 schema、卡牌文本与机器字段 |
| `card_player_state_port_v06_test.gd` | PASS | 65 | reference 端口合同、跨玩家预留与 exact-once 基线 |
| `card_player_state_production_adapter_v06_test.gd` | PASS | 44 | 每玩家 revision/CAS、现金分、六色资产预留、精确 delta、exact-once |
| `card_flow_transaction_service_v06_test.gd` | PASS | 69 | 牌源事务、失败闭合、结构化 compensation、显式 commit 拒绝清理、玩家文本隔离 |
| `card_core_effect_adapters_v06_test.gd` | PASS | 34 | 设施、商品与供需 adapter 的真实 owner 协议 |
| `core_economic_card_effect_router_v06_test.gd` | PASS | 76 | 四类效果路由、rollback/finalize 绑定、重放与缺失 hook |
| `commodity_flow_atomic_batch_sink_v06_test.gd` | PASS | 51 | 真实 candidate、订单/供货、结算、回滚、存档、共享容量 |
| `core_economy_production_integration_v06_test.gd` | PASS | 65 | 履带竞争、满手合成/拒绝、市场刷新、设施/商品生产接线 |
| `commodity_card_inventory_runtime_test.gd` | PASS | 44 | Agent A 权威牌源的履带、市场、播放与 journal 兼容面 |
| `commodity_flow_atomic_batch_sink_contract_v06_test.gd` | PASS | 7 | sink 接口与 fail-closed 合同 |
| `commodity_flow_candidate_snapshot_port_v06_test.gd` | PASS | 4 | candidate snapshot 端口 |
| `card_global_supply_demand_v06_test.gd` | PASS | 122 | 全局供需 planner、标签、分配与原子失败 |
| `card_flow_policy_v06_test.gd` | PASS | 37 | 领取、购买、合成与手牌规则 |
| `asset_terminology_v06_test.gd` | PASS | 661 | 玩家呈现统一使用“资产” |
| `ui_text_smoke_test.gd` | PASS | — | 玩家文本 smoke，无测试失败 |

## 严格 candidate snapshot 与聚合容量

原子 sink 聚焦 fixture 不再手写任意 candidate。测试先从真实 `CommodityFlowRuntimeController.card_effect_candidates_snapshot()` 取得权威快照，再从其中的真实 candidate 构造 allocation，并完整携带：

- `candidate_snapshot_revision` 与 `candidate_snapshot_fingerprint`；
- `candidate_id`、商品 owner、产品/产业、设施与区域 revision；
- 路线、拓扑、运输标签、最短合法距离和 `capacity_resource_ids`；
- candidate 原始 `matching_product_gdp_30s`；
- 一次性效果类型和分配数量。

`prepare` 会重新检查快照 revision/fingerprint、candidate 与 allocation 的完整绑定，以及同一共享运输资源上的聚合容量。当前证据包括：

1. 篡改市场端点后返回 `batch_child_candidate_binding_changed`；prepare 前后的 CommodityFlow save data 完全相等，证明零商品、零 journal、零 receipt、零 revision 副作用。
2. 两个各自合法、但共享同一容量资源的 candidate 合计超额时返回 `batch_shared_capacity_exceeded`，同样零副作用。
3. 实体供货在真实 flow tick 前可原子 rollback，重复 rollback exact-once；已经进入真实成交结算的订单关闭 rollback window，返回 `batch_rollback_closed`。
4. transaction journal 经 save/load 后仍阻止重复生成商品或需求。

该 direct sink 测试没有提前调用 finalize，因此“结算前允许回滚、结算后关闭回滚”的边界与新语义一致；正式 transaction finalize 还应在玩家状态提交成功后立即关闭对应 owner 的回滚窗口。

## Transaction compensation 与 finalize 语义

### Compensation

卡牌效果先提交、玩家状态随后提交失败时，transaction service 会请求效果 owner rollback，并只接受 owner **明确返回** `rolled_back=true` 作为补偿成功。缺少 rollback、返回值类型错误或 owner 返回 false 时：

- 顶层结果为 `effect_compensation_failed`；
- `rolled_back` 不会被伪造为 true；
- 手牌、现金、资产和玩家 revision 不会被提交成成功；
- 机器诊断保留 `original_reason_code`、`state_port_reason_code` 和结构化 `compensation.owner_result`；
- 玩家反馈只显示本地化的“为什么失败”和“下一步怎么做”，不泄漏 card ID、reason code、资源路径或 raw error；
- 相同 transaction 重放返回已记录结果，不重复 commit 或 rollback。

设施与商品流两类 owner rollback 返回 false 的聚焦案例已经通过，证明失败不会被错误声明为“已补偿”。

### Finalize

transaction service 只在玩家状态提交成功后调用 finalize，并把结构化结果写入 `effect_finalization`；缺少 hook 或 finalize 失败均不会被当作完成。router 保存 transaction→effect owner 绑定：

- owner 明确 `finalized=true` 后记录 exact-once finalize 结果、释放 association，并关闭后续 rollback；
- 重复 finalize 返回 `idempotent_replay=true`，不会第二次调用 owner；
- owner 没有 finalize hook 时返回 `owner_finalize_supported=false`、`finalized=false`、`effect_owner_finalize_unavailable`，association 保留用于诊断或重试；
- owner 缺少 rollback 或 rollback 失败时也保留 association，不伪造撤销成功。

当前 owner 生命周期缺口：

- 设施 adapter 有 rollback 转发，但权威设施 rollback 的原子实现仍需最终整合者修复，随后还需定义成功提交后的 preimage 清理/finalize；
- 商品 adapter 目前没有把 CommodityFlow 已有的商品安装 rollback 能力向 transaction router 完整转发，也没有 finalize；Bench 因而明确报告 finalize gap；
- 全局供需 adapter 能 rollback batch，但尚未把 CommodityFlow 的 `finalize_card_effect_batch` 完整串接至 planner/sink/adapter finalize 链。

## Godot add-on MCP 验收

状态：**通过。** 使用项目安装的 Godot add-on MCP 完成真实项目识别、编辑器打开、指定场景运行、debug output 读取与停止；不是静态 mock 或纯脚本截图。

| MCP 步骤 | 证据 |
|---|---|
| `get_godot_version` | `4.7.stable.official.5b4e0cb0f` |
| `get_project_info` | 项目名 `space-syndicate-sync`；路径 `C:\Users\Administrator\Documents\New project\space-syndicate-sync` |
| `launch_editor` | Godot 编辑器成功打开该项目 |
| `run_project` | 指定 `scenes/tools/CoreEconomyProductionWiringV06Bench.tscn`，debug mode 启动成功 |
| `get_debug_output` | `CORE_ECONOMY_PRODUCTION_WIRING_V06_BENCH|status=PASS|checks=27|failures=0|terminology=assets`；`errors=[]` |
| `stop_project` | `message="Godot project stopped"`；`finalErrors=[]` |

第一次 MCP 运行曾捕获 `card_player_state_production_adapter_v06.gd:742` 的不兼容三元类型警告；已改为显式 `if/else`，聚焦测试 44/44 通过，并完成第二次 MCP 运行。上表记录的是修复后的最终无错误结果。

## 尚未关闭的生产硬门

1. **P0：设施 rollback 原子性。** 当前权威 rollback 在完整验证 preimage 前会先动当前设施/slot。Bench 因此通过 `facility_rollback_atomicity_unavailable` 拒绝真实设施出牌。最终整合者必须实现“完整 preflight → 副本构造 next state → 一次提交”，再解除门禁。
2. **P0：生产组合唯一状态端口。** 独立 Bench 使用新 `CardPlayerStateProductionAdapterV06`，但主生产组合尚未完成从旧 bridge 的替换。两者不得并存，否则会出现两套 lock/journal/CAS 元数据同时写同一 world。最终整合必须替换旧 bridge 或把旧 bridge 改成单向委托。
3. **P0：效果生命周期转发不完整。** 商品安装 rollback/finalize、设施 finalize、全局供需 finalize 链尚未全部贯通；在此之前不得假设 post-effect state commit failure 总能补偿。
4. **P1：生产存档边界。** inflight/prepared 玩家资产预留需要 checkpoint gate 或加载恢复策略，避免保存时留下孤儿预留。
5. **P1：权威牌源边界。** 新玩家状态 adapter 依赖可信 CardFlow 调用路径；最终组合还应确保所有 inventory transition 都经过现有牌源规则验证，不能让其他调用方直接提交任意合法形状的手牌快照。
6. **MCP 验收已关闭。** 最终 run/debug/stop 为 PASS、`errors=[]`、`finalErrors=[]`；剩余阻塞均为生产组合与 owner 生命周期问题。

## 下一阶段判断

| 工作 | 判断 |
|---|---|
| 怪兽/军队运行时 API 合同、intent/receipt schema、独立 adapter 与 focused test | **可以开始**，可复用现有 transaction binding、结构化 compensation、exact-once 和玩家文本隔离原则 |
| 把怪兽/军队效果接进 `main` / `GameRuntimeCoordinator` | **暂缓**，等待状态端口唯一化、设施 rollback 与 owner finalize 硬门关闭 |
| 宣布核心经济卡生产主循环完成 | **不可以**，MCP 已通过，但上述生产 P0 尚未关闭 |

最终建议：下一阶段先做独立 API 和 owner 生命周期合同，同时由最终整合者关闭本报告三个 P0；关闭后重新运行本表全部测试与 MCP Bench，再决定生产合入。
