# SS06-07 怪兽与军队卡牌运行时合同 v0.6

日期：2026-07-14  
状态：独立合同与接线骨架；尚未接入生产主循环

## 1. 范围与硬边界

本合同为怪兽单位牌、怪兽一次性诱导、怪兽固定技能、军队单位牌与可回收军令定义字段化 intent/receipt、权威 owner 转发、事务生命周期、隐私分层和存档门禁。它是未来接入唯一 `CardFlowTransactionServiceV06` 的效果边界，不是第二套手牌、资产、单位或世界状态。

本轮明确不做：

- 不接入 `main.gd` 或 `GameRuntimeCoordinator`；
- 不修改 `MonsterRuntimeController`、`MilitaryRuntimeController`、移动或战斗平衡模型；
- 不在 adapter 中模拟移动、攻击、击退、区域伤害、怪兽 AI、军队冷却或单位存续；
- 不根据中文卡名写专用分支，也不把旧 v0.4 动态技能直接宣称为 v0.6 已支持；
- 不创建新的 `CardFlowTransactionServiceV06`，也不复制手牌、现金、六色资产、怪兽或军队 roster；
- 不改变怪兽自主行动规则。玩家只能通过部署/升级、一次性诱导和明确的固定技能影响怪兽，不能取得持续直接控制；
- 不让军队自主行动。军队只接受绑定且可回收的军令 intent，真实执行仍由军队 owner 完成。

角色带来的怪兽或军队上限修正必须作为权威公开规则输入进入 owner。adapter 不识别角色名，也不自行计算角色被动。普通基准上限仍为每名玩家一只归属怪兽与一支军队。

## 2. 当前目录覆盖与迁移差距

`data/cards/card_runtime_catalog_v06.json` 当前有两组可审计的单位牌：

| v0.6 目录效果 | 数量 | 家族 | 本合同状态 |
| --- | ---: | --- | --- |
| `deploy_or_upgrade_monster` | 32 | 8 个怪兽家族 × I–IV | schema、router 和 reference owner 已覆盖；真实 owner 未满足原子事务能力，生产 fail-closed |
| `deploy_or_upgrade_military` | 28 | 7 个军队家族 × I–IV | schema、router 和 reference owner 已覆盖；真实 owner 未满足原子事务能力，生产 fail-closed |

八个怪兽家族为 `spore_tide_emperor`、`sand_armor_rover`、`prism_blade_colossus`、`meteor_sentinel`、`oasis_repairer`、`flame_ring_proto_star`、`blue_edge_knight`、`mirror_hunter`。七个军队家族为 `planetary_defense_force`、`air_superiority_fighter`、`orbital_bomber`、`heavy_tank`、`missile_emplacement`、`submarine_fleet`、`star_ocean_battleship`。

合同同时预留以下字段化效果族，但它们目前不是 v0.6 JSON 目录中的可购买正式条目：

- `monster_lure_once`：只覆盖下一次怪兽自主移动的一次性诱导；
- `monster_bound_action`：怪兽固定技能的一次结算入口；
- `military_reusable_command`：不计普通五张手牌上限、但仍要求资产的绑定军令入口。

旧 `resources/cards/runtime/card_runtime_catalog_v04.tres` 与 `packs/09_monster_actions.tres` 包含运行时生成、中文 `card_id`、`kind` 驱动且效果差异很大的诱导/固定技能。它们不能仅凭名称映射到 v0.6。迁移每个旧技能前必须补齐稳定的 `effect_kind`、`action_kind`、profile ID、目标字段、资产费用、公开范围、持续/终止条件和权威 owner 能力；缺任一项即返回结构化 unsupported/capability reason。

`monster_bound_action` 中的 `monster_move`、`monster_attack`、`monster_guard`、`monster_area_suppress` 只表示一张已绑定固定技能的一次 intent，不授予玩家持续控制。真实 owner 若无法证明该 profile 是固定技能、仍遵守怪兽自主生态并使用既有移动/战斗 owner，则必须拒绝。

## 3. Intent schema

所有 intent 使用 `contract_version = "v0.6"`。`UnitCardRuntimeSchemaV06.make_intent()` 生成稳定指纹；调用方不得自行删改哈希后重用旧 intent。

### 3.1 权威绑定字段

以下字段必须在 prepare、commit、rollback 和 finalize 收据中保持一致：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `transaction_id` | String | 全局稳定事务 ID；同 ID 只能绑定一个 intent |
| `actor_id` | String | 私有行动者 ID；不得进入 public receipt |
| `card_id` | String | 目录机器 ID；不是玩家显示文本 |
| `card_instance_id` | String | 手牌实例 ID；不得进入 public receipt |
| `effect_kind` | String | 字段化效果族；prepare 时由 router 固定 |
| `action_kind` | String | 效果族内动作；不得由后续收据改写 |
| `target_hash` | String | 规范化 `target_context` 指纹 |
| `payload_hash` | String | 规范化 `effect_fields` 指纹 |
| `intent_hash` | String | 外层唯一卡牌事务服务的原始 intent 指纹；跨阶段原样保持 |
| `unit_intent_fingerprint` | String | 将外层 `intent_hash`、动作、owner revision 与目标/载荷指纹再次绑定的 SHA-256 |
| `expected_owner_revision` | int | prepare 必须比较的权威单位状态 revision，值不得小于 0 |

`target_context`、`effect_fields` 和 `visibility_context` 是 intent 的数据正文。`target_hash` 和 `payload_hash` 使用规范化 JSON 的 SHA-256；`unit_intent_fingerprint` 再绑定外层事务、`effect_kind`、`action_kind` 与 owner revision。若 `effect_fields` 自带 `effect_kind/action_kind`，它们必须与顶层一致；正式目录载荷可以省略这两个重复字段。

冻结的 `play_core_card(...)` 仍会传入 `effect_payload`。router/adapter 只做结构归一化：保留外层绑定与哈希，把 `effect_payload` 映射为 `effect_fields`，并从 `target_context.expected_owner_revision` 取得 owner revision。部署/升级动作可由正式 `effect_kind` 唯一推导；动态诱导、兽技和军令必须在载荷或目标上下文显式携带 `action_kind`，否则安全拒绝。

### 3.2 效果与动作矩阵

| `effect_kind` | 允许的 `action_kind` | 最低必需字段 |
| --- | --- | --- |
| `deploy_or_upgrade_monster` | `deploy_or_upgrade_monster` | `target_context.region_id` 或正整数 `unit_uid`；`monster_family_id`；`card_rank` 1–4 |
| `monster_lure_once` | `monster_lure` | 正整数 `unit_uid`；`target_region_id`；`consumption_policy = next_autonomous_move_once` |
| `monster_bound_action` | `monster_move` / `monster_attack` / `monster_guard` / `monster_area_suppress` | 正整数 `unit_uid`；`skill_profile_id`；`bound_action_instance_id`；动作对应目标 |
| `deploy_or_upgrade_military` | `deploy_or_upgrade_military` | `target_context.region_id` 或正整数 `unit_uid`；`military_family_id`；`card_rank` 1–4 |
| `military_reusable_command` | `military_move` / `military_guard` / `military_attack_monster` / `military_suppress_region` | 正整数 `unit_uid`；`command_instance_id`；`persistent = true`；动作对应目标 |

区域动作需要 `target_region_id`；攻击怪兽需要正整数 `target_monster_uid`。所有权、同族升级、地形、范围、冷却、单位是否仍在场、目标是否被摧毁以及角色修正后的上限，仍必须由权威 owner 在 prepare 再验证。

### 3.3 字段驱动规则

router 只能按 `effect_kind` 选择 handler，owner 只能按验证后的 `action_kind` 和 profile 字段选择规则。以下写法禁止：

- 按玩家可见中文名、卡名后缀或插画资源路径分支；
- 由 commit/rollback/finalize receipt 自报另一个 `effect_kind`；
- adapter 自行把部署位置改写为当前 UI 选区；
- adapter 自行计算米/秒、射程、伤害、击退、区域生命或 GDP 压力；
- 用 `unit_control_limit = 1` 覆盖权威公开角色修正。

## 4. Receipt schema

owner 每一阶段返回 Dictionary，且必须原样回传第 3.1 节全部绑定字段。共同字段如下：

| 字段 | 用途 |
| --- | --- |
| `receipt_version` | 收据合同版本 |
| `prepared` | 仅在权威 owner 已建立可撤销预留后为 true |
| `committed` | 仅在规则效果恰好执行一次后为 true |
| `rolled_back` | 仅在 owner 明确恢复 preimage 后为 true |
| `finalized` | 仅在 owner 明确关闭回滚窗口后为 true |
| `idempotent_replay` | exact-once journal 返回原结果时为 true |
| `reason_code` | 机器/开发字段；不得直接显示给玩家 |
| `player_feedback.reason` | 本地化、可直接显示的拒绝原因 |
| `player_feedback.next_step` | 本地化、可执行的下一步 |
| `public_fields` | 可进入公开过滤器的候选字段，仍要执行 allowlist/递归清洗 |
| `private_fields` | 仅行动者本人可见的候选字段 |
| `developer_fields` | owner receipt、revision、指纹和诊断；只供开发者 |

标准失败 receipt 保持 `prepared/committed/rolled_back/finalized = false`；已经发生的早期阶段由 router 的权威关联记录，而不是从失败 receipt 反推。任何 bool 返回、空 Dictionary、绑定错配或阶段成功位缺失都不是成功证明。

## 5. Owner forwarding port

生产 owner 必须显式声明 `unit_card_runtime_capabilities_v06(domain)`，且 `contract_version` 必须为 `v0.6`。只因对象恰好有同名或相似旧方法，不得推断事务能力。

### 5.1 必需方法

```gdscript
func unit_card_runtime_capabilities_v06(domain: String) -> Dictionary
func prepare_unit_card_intent_v06(intent: Dictionary) -> Dictionary
func commit_unit_card_intent_v06(prepared: Dictionary) -> Dictionary
func rollback_unit_card_intent_v06(receipt: Dictionary) -> Dictionary
func finalize_unit_card_intent_v06(receipt: Dictionary) -> Dictionary
func unit_card_checkpoint_status_v06(domain: String) -> Dictionary
```

可选的隐私安全读接口为：

```gdscript
func unit_card_snapshot_v06(domain: String) -> Dictionary
```

capability 声明至少包含：

- `revision`
- `prepare`
- `commit`
- `rollback`
- `finalize`
- `exact_once`
- `checkpoint_gate`
- `privacy_safe_snapshot`
- `supported_effect_kinds`
- `supported_action_kinds`

只有 `revision/prepare/commit/rollback/finalize/exact_once/checkpoint_gate` 全部为 true、方法存在、版本匹配且效果/动作列入 owner 声明，`atomic_mutation_ready` 才能为 true。否则转发端口在 prepare 入口 fail-closed，禁止消费卡牌、现金或资产。

### 5.2 当前 capability matrix

| 能力 | `MonsterRuntimeController` | `MilitaryRuntimeController` | `UnitCardReferenceOwnerV06` |
| --- | --- | --- | --- |
| snapshot/roster 读 | 有 | 有 | 有，隐私安全的 reference snapshot |
| save/load | 有旧运行时 save/load | 有旧运行时 save/load | 本轮不作为生产存档 owner |
| 单调 unit-card revision | 无 | 无 | 有 |
| prepare | 无 | 无 | 有 |
| commit | 无原子收据；旧入口直接变更 | 无原子收据；旧入口直接变更 | 有 |
| rollback | 无 | 无 | 有 |
| finalize | 无 | 无 | 有 |
| exact-once journal | 无 | 无 | 有 |
| inflight checkpoint gate | 无 | 无 | 有 |
| production atomic mutation ready | **否** | **否** | **否；reference-only** |

真实怪兽 owner 的 `resolve_targeted_skill()`、私有 `_summon_monster_from_card()` 与 `_upgrade_field_monster_from_card()` 返回 bool 或直接变更 roster、世界、市场和固定技能库存；它们没有 revisioned prepare/preimage/rollback/finalize。现有升级还会把 `remaining_time` 重置为完整 `duration`，而 v0.6 目录要求在剩余时间上增加 60 秒且 `refresh_total_presence_time=false`。因此不得由 adapter 直接调用；当前 prepare 必须以 `monster_owner_atomic_contract_missing` fail-closed。

真实军队 owner 的 `summon_from_card()` 与 `trigger_command()` 同样直接变更 roster、运动、冷却、区域/路线或怪兽 owner，并直接编排固定军令库存；没有原子收据和补偿。其达到上限时刷新最早军队的旧行为也不能替代 v0.6 目录的“同族升级”目标约束。因此不得把旧 bool 成功包装成 v0.6 commit 成功；当前 prepare 必须以 `military_owner_atomic_contract_missing` fail-closed。

`UnitCardReferenceOwnerV06` 只用于聚焦测试与独立 Bench。它验证状态机、exact-once、一次性 lure 和隐私边界，不是生产怪兽/军队真相，也不证明真实移动、攻击或伤害已经接线。

## 6. Router 权威绑定

`UnitCardEffectRouterV06` 在 prepare 成功后保存：

```text
transaction_id
  -> intent_hash
  -> authoritative effect_kind/action_kind
  -> immutable binding
  -> prepared/committed/rollback/finalize receipt
  -> current stage
```

commit、rollback、finalize 必须通过保存的 `transaction_id` 找到 handler。传入 receipt 的 `effect_kind` 只参与绑定核对，不能重新选择 handler。相同 `transaction_id` 与不同 `intent_hash` 冲突；相同绑定的重放返回已记录 receipt，并标记 `idempotent_replay=true`，不得重复下达 lure、军令、部署或攻击。

关联的阶段为：

```text
prepared -> committed -> finalized
    |           |
    +-----------+-> rolled_back
    |           |
commit_failed   rollback_failed / finalize_failed
```

失败阶段必须保留关联和 owner 诊断，不得被伪装成终态。只有 owner 明确返回 `rolled_back=true` 才进入 `rolled_back`；只有 owner 明确返回 `finalized=true` 才进入 `finalized`。owner 返回 false、无效 receipt 或绑定错配时，router 保留回滚/终结窗口用于诊断或显式重试。

## 7. Prepare、rollback 与 finalize 窗口

### 7.1 正常顺序

1. 唯一卡牌事务服务预留玩家卡牌与六色资产，但不提交。
2. router/schema 验证 intent 并把事务绑定到唯一效果 handler。
3. owner `prepare` 验证 revision、目标、所有权、上限、地形、范围、单位状态、profile 与库存绑定，只建立可撤销 reservation。
4. owner `commit` 恰好执行一次权威规则变更；移动与攻击只转发给既有 owner。
5. 玩家状态端口提交卡牌与资产 mutation。
6. owner `finalize` 清理 preimage/reservation 并关闭 rollback window；finalize 不能再次产生规则效果。

### 7.2 补偿

- prepare 失败：不得扣卡、扣钱或扣资产，也不得产生单位副作用；
- owner commit 失败：owner 必须保证零副作用，或保留可用 preimage；
- owner commit 成功而玩家状态提交失败：事务服务调用同一权威关联的 rollback；
- 只有 `rolled_back=true` 才算补偿成功；`rolled_back=false`、无效 receipt 或绑定错配必须报告 `compensation_failed`，且不得伪造已回滚；
- finalize 成功后 rollback 必须返回 window closed；
- finalize 失败时关联继续存在，checkpoint 继续关闭，不得把事务当成完整成功保存。

一次性 lure 的 reservation 必须绑定怪兽 UID、目标区域、owner revision 和 `remaining_uses=1`。重复 transaction 不得覆盖第二次；怪兽自主移动消费后必须由怪兽 owner 的 exact-once journal 记录，不能由 adapter 擅自清除或重复触发。可回收军令同理：卡牌实例可在规则允许时再次使用，但每次下达都必须有新的 transaction ID；同一事务重放不得重复建立运动、伤害或冷却。

## 8. 隐私与三层 receipt

所有未经 reveal 规则公开的单位归属和玩家意图都默认私有。过滤顺序为“owner 原始 receipt → allowlist 视图 → 递归泄漏扫描”，不得把原始 receipt 直接绑定到 UI。

### 8.1 Public

public view 只允许稳定的公开状态位、匿名事件、公开单位 ID/名称/等级、公开目标、公开变化和本地化玩家反馈。默认强制 `anonymous=true`。

public receipt 禁止出现：

- `actor_id`、`transaction_id`、`card_instance_id`、`bound_unit_uid`；
- `true_owner`、`hidden_owner`、`owner_truth`、`owner_player_index`、未触发 reveal 的 owner clue；
- 对手现金、手牌、库存、资产 debit 或 AI 私有计划；
- `reason_code`、revision、fingerprint/hash、owner raw receipt、路径、raw error、developer/private fields。

仅当权威公开规则事件明确给出 `owner_revealed=true` 时，才可显示本地化 `revealed_owner_label`；否则过滤器必须删除该标签。

### 8.2 Private

private view 首先生成 public view。仅当 `viewer_actor_id == receipt.actor_id` 时，才可追加 allowlist 内的本人字段，例如自己的绑定单位 UID、军令实例、本次资产扣款、冷却、私有目标、自己的现金/手牌或单位状态。即使在 private view 中，也不得包含对手或 AI 私有字段、raw error 或原始 owner receipt。

### 8.3 Developer

developer view 可保留完整收据、绑定、reason code、revision、capability matrix 与 owner 诊断，但只能进入测试、日志和报告，不能作为玩家文本 fallback。玩家反馈必须始终使用本地化 `reason` 与 `next_step`，不得显示内部 ID 或英文开发默认值。

## 9. Checkpoint 与 save/load 门禁

`UnitCardCheckpointGateV06` 对 router 和所有参与 owner/port 执行逻辑 AND：

- router 中所有事务必须处于 `rolled_back` 或 `finalized`；
- 每个 owner 必须显式返回 `can_checkpoint=true` 且 inflight reservation 为 0；
- 任一参与者缺 gate、返回无效结构或报告 inflight，保存即 fail-closed；
- `commit_failed`、`rollback_failed`、`finalize_failed` 都不是可安全保存的终态。

未来生产 owner 必须二选一：

1. 在 save/load 中完整持久化 reservation、preimage、transaction binding、exact-once journal 与 lure/command 消费状态，并在加载时恢复；或
2. 在任何 inflight 期间拒绝保存，直到明确 finalize 或 rollback。

现有怪兽/军队 save/load 只覆盖 roster 与既有运行时字段，不覆盖本合同的 inflight 事务。因此在 owner 补齐 checkpoint API 前，真实 mutating intent 全部 fail-closed，不能以“旧存档可以保存 roster”为由放行。

## 10. 真实 owner 接口需求

### 怪兽 owner

- 增加单调 revision 与 transaction journal；
- 把部署/同族升级拆为无副作用 prepare、exact-once commit、preimage rollback、无规则副作用 finalize；
- v0.6 升级按剩余时间增加 60 秒、恢复满血，IV 重复只恢复并延时，不再使用旧“刷新总时长”语义；
- 固定技能库存授予/失效必须与唯一卡牌库存 owner 处于同一事务或可完整补偿；
- lure reservation/消费在怪兽自主移动 owner 内恰好一次；
- 移动、攻击、击退继续调用现有米/秒和战斗 owner，不把公式复制进 card adapter；
- 提供明确的隐私安全 snapshot，而非把含 hidden owner 的 roster/debug data 直接公开。

### 军队 owner

- 增加单调 revision 与 transaction journal；
- 部署/同族升级和四类军令提供 prepare/commit/rollback/finalize；
- 军令实例绑定、资产要求、冷却与目标合法性在 prepare 重新验证；
- `move` 只启动现有线性运动，`guard`、`suppress`、`attack_monster` 继续转发既有区域/路线/怪兽 owner；
- 固定军令授予/失效必须与唯一库存 owner 原子化；
- 不把“达到上限刷新最早任意军队”的旧行为静默映射成 v0.6 同族升级；
- 提供 inflight checkpoint 和隐私安全 snapshot。

## 11. 未来接入 Coordinator 的最小步骤

1. 在两个真实 owner 中实现并聚焦验证第 5.1 节 API，不修改卡牌 adapter 的 owner 事实。
2. 为旧动态诱导/固定技能生成正式 v0.6 目录条目；只使用字段化 profile，不按名称分支。
3. 使用 `MonsterCardOwnerPortV06` 与 `MilitaryCardOwnerPortV06` 读取 capability matrix；矩阵未全绿时保持入口关闭。
4. 在现有唯一核心经济效果 router 之外，用 `UnitCardEffectRouterV06` 作为单位效果子路由，并由现有 `play_core_card(...)`/唯一 `CardFlowTransactionServiceV06` 驱动；不得创建第二个玩家状态端口或事务服务。
5. 把 `UnitCardCheckpointGateV06` 接到 Coordinator 的存档前门；任何 inflight 或失败关联都阻止 checkpoint。
6. 所有 UI、公共事件和日志先经过 `UnitCardReceiptFilterV06`，并保留 public leak scan = 0 的回归门。
7. 在接主场景前，交叉验证卡牌/资产提交失败后的 owner rollback、成功提交后的 finalize、save/load replay，以及 lure/军令 exact-once。

在以上步骤完成前，独立 Bench 的 reference owner 成功只证明合同状态机可运行；真实 owner capability/fail-closed 结果才是当前生产结论。
