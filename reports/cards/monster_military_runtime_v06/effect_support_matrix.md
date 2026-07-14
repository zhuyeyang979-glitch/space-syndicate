# SS06-07 Unit Card Effect Support Matrix

日期：2026-07-14  
口径：区分“schema/router 已表达”“reference owner 可验证”和“真实生产 owner 可执行”。前两项不能替代第三项。

## v0.6 正式目录覆盖

`data/cards/card_runtime_catalog_v06.json` 当前包含 60 张单位牌：

| Category | `effect_kind` | 数量 | 家族数 | 等级 | 真实生产状态 |
| --- | --- | ---: | ---: | --- | --- |
| monster | `deploy_or_upgrade_monster` | 32 | 8 | I–IV | blocked：`monster_owner_atomic_contract_missing` |
| military | `deploy_or_upgrade_military` | 28 | 7 | I–IV | blocked：`military_owner_atomic_contract_missing` |

怪兽家族：

- `spore_tide_emperor`
- `sand_armor_rover`
- `prism_blade_colossus`
- `meteor_sentinel`
- `oasis_repairer`
- `flame_ring_proto_star`
- `blue_edge_knight`
- `mirror_hunter`

军队家族：

- `planetary_defense_force`
- `air_superiority_fighter`
- `orbital_bomber`
- `heavy_tank`
- `missile_emplacement`
- `submarine_fleet`
- `star_ocean_battleship`

正式目录暂未提供 `monster_lure_once`、`monster_bound_action` 或 `military_reusable_command` 的 v0.6 机器条目。新增 runtime schema 为这些效果预留了字段边界，但没有凭空把旧动态技能升级为正式目录内容。

## Effect/action support

| `effect_kind` | `action_kind` | Schema/router | Reference owner | 真实 owner | 主要阻塞 reason / 接口差距 |
| --- | --- | --- | --- | --- | --- |
| `deploy_or_upgrade_monster` | `deploy_or_upgrade_monster` | 支持；要求 region 或 owned unit、family、rank 1–4 | 支持合同状态机 | **Blocked** | `monster_owner_atomic_contract_missing`；没有 revision/prepare/rollback/finalize/exact-once；旧升级刷新总时长而非剩余时间 +60 秒；固定技能库存 side effect 未原子化 |
| `monster_lure_once` | `monster_lure` | 支持；要求 unit、target region、`next_autonomous_move_once` | 支持一次待消费 lure 与重放保护 | **Blocked** | 正式 v0.6 目录缺失；`monster_owner_atomic_contract_missing`；旧 `resolve_targeted_skill` 直接 mutation，无一次覆盖 reservation/journal/checkpoint |
| `monster_bound_action` | `monster_move` | 支持为一次固定技能 intent；不授予持续控制 | 支持记录接受的固定技能动作 | **Blocked** | 正式 v0.6 profile 缺失；`monster_owner_atomic_contract_missing`；需证明只触发现有自主/线性移动 owner，不能由 adapter 瞬移 |
| `monster_bound_action` | `monster_attack` | 支持；要求 target monster | 支持记录接受动作 | **Blocked** | 正式 v0.6 profile 缺失；`monster_owner_atomic_contract_missing`；伤害、范围、击退与赌局必须由现有 owner 执行并可补偿 |
| `monster_bound_action` | `monster_guard` | 支持固定技能绑定 | 支持记录接受动作 | **Blocked** | 正式 v0.6 profile/目标/持续语义未迁移；`monster_owner_atomic_contract_missing` |
| `monster_bound_action` | `monster_area_suppress` | 支持；要求 target region | 支持记录接受动作 | **Blocked** | 正式 v0.6 profile/公开范围/终止语义未迁移；`monster_owner_atomic_contract_missing`；区域 mutation 无原子补偿链 |
| `deploy_or_upgrade_military` | `deploy_or_upgrade_military` | 支持；要求 region 或 owned unit、family、rank 1–4 | 支持合同状态机 | **Blocked** | `military_owner_atomic_contract_missing`；没有 revision/prepare/rollback/finalize/exact-once；旧达到上限刷新最早任意军队，不满足同族升级约束；军令库存 side effect 未原子化 |
| `military_reusable_command` | `military_move` | 支持；要求 bound unit、command instance、persistent、target region | 支持重放不重复下令 | **Blocked** | 正式 v0.6 command profile 缺失；`military_owner_atomic_contract_missing`；必须只转发现有米/秒移动和冷却 owner |
| `military_reusable_command` | `military_guard` | 支持；要求 bound unit 与 reusable command | 支持重放不重复下令 | **Blocked** | 正式 v0.6 command profile 缺失；`military_owner_atomic_contract_missing`；保卫对区域/路线状态的 rollback 未定义 |
| `military_reusable_command` | `military_attack_monster` | 支持；要求 target monster | 支持重放不重复下令 | **Blocked** | 正式 v0.6 command profile 缺失；`military_owner_atomic_contract_missing`；攻击须跨 `MilitaryRuntimeController` 与 `MonsterRuntimeController` 原子补偿 |
| `military_reusable_command` | `military_suppress_region` | 支持；要求 target region | 支持重放不重复下令 | **Blocked** | 正式 v0.6 command profile 缺失；`military_owner_atomic_contract_missing`；区域、路线、GDP pressure 的跨 owner rollback/finalize 未定义 |

## 目标和 stale-state 失败边界

schema 先拒绝结构错误；真实 owner prepare 仍必须重新验证权威状态。常见失败应使用结构化机器 reason，同时给玩家本地化原因和下一步：

| 情况 | 合同 reason 示例 | 零副作用要求 |
| --- | --- | --- |
| owner revision 过期 | `unit_owner_revision_stale` | 不扣卡、不扣资产、不改变单位 |
| 区域或单位目标缺失 | `monster_deploy_target_missing` / `military_deploy_target_missing` | 同上 |
| 单位不存在 | `unit_target_not_found` | 同上 |
| 单位不属于行动者 | `unit_target_not_owned` | 同上；public receipt 不泄露真实 owner |
| 升级家族不匹配 | `monster_upgrade_family_mismatch` / `military_upgrade_family_mismatch` | 同上 |
| lure 已待消费 | `monster_lure_already_pending` | 不覆盖第一次 lure |
| lure 消费策略不受支持 | `monster_lure_policy_unsupported` | 不建立 reservation |
| 固定技能/军令未绑定 | `monster_bound_action_binding_missing` / `military_command_binding_missing` | 不执行动作 |
| 军令不是可回收实例 | `military_command_not_reusable` | 不执行动作 |
| profile 未列入 owner capability | `monster_owner_action_unsupported` / `military_owner_action_unsupported` | 不调用旧 mutation API |
| transaction 与原 intent 冲突 | `unit_transaction_binding_conflict` | 不路由到另一个 handler |

## 动态技能迁移缺口

旧 v0.4 目录与 `packs/09_monster_actions.tres` 包含运行时生成或中文 `card_id/kind` 驱动的诱导和怪兽技能。旧军队 owner 也会在部署时动态授予固定军令。这些内容尚缺正式 v0.6 目录机器字段，不能按中文牌名映射。

每个动态效果进入生产前至少需要：

- 稳定 `card_id/family_id/effect_kind/action_kind`；
- `skill_profile_id` 或 `command_instance_id` 与真实单位 UID 的权威绑定；
- 明确 target schema、资产费用、持续/终止、公开/私有范围；
- 明确是否从五张普通手牌上限排除；
- owner capability allowlist；
- revisioned prepare、exact-once commit、rollback preimage、finalize 和 checkpoint 行为；
- save/load 后 lure/command transaction 不成为孤儿；
- 玩家可见文本本地化，机器 ID、reason、路径和 raw error 不得作为 fallback。

## 生产成功的最低接口证明

某动作只有同时满足以下条件才能从 Blocked 改为 Supported：

1. 真实 owner 声明合同版本 v0.6 和对应 effect/action capability。
2. prepare receipt 明确 `prepared=true`，并绑定外层 `intent_hash`、`unit_intent_fingerprint`、目标/载荷指纹与 expected owner revision。
3. commit receipt 明确 `committed=true`，相同事务重放只返回原 receipt，不重复部署、诱导或下令。
4. 玩家卡牌/资产提交失败时，owner rollback 确实恢复 roster、lure/command、运动/冷却和所有跨 owner side effect，并明确 `rolled_back=true`。
5. 玩家状态提交成功后，owner finalize 明确 `finalized=true` 并关闭 rollback window；失败时保留 router 关联且禁止 checkpoint。
6. public receipt 经 allowlist 与泄漏扫描，不含 true/hidden owner、行动者 ID、事务、卡牌实例、对手现金/手牌或 AI 私有计划。

旧 bool 返回、adapter 自行重算结果、reference owner receipt、静态 mock 或“没有报错”都不满足这些证明条件。
