# VS06-B Rank-I Starter First Summon Atomic Lifecycle Contract

状态：P0 生产接线合同  
规则版本：v0.6  
业务状态 owner：`MonsterRuntimeController`  
P0 唯一真实 action：每名玩家的 Rank-I starter first summon

## 1. P0 结论

VS06-B 不再尝试一次解锁全部怪兽 deploy/upgrade。P0 只把正式 starter monster 的首次 Rank-I 召唤接入 revisioned、exact-once、可保存、可审计且隐私安全的真实 `MonsterRuntimeController`。

以下路径全部延期并 fail-closed：

- 非 starter 的普通怪兽部署；
- Rank II–IV 部署；
- 所有 upgrade 与 IV refresh；
- lure、固定兽技、move、attack、guard、area suppress；
- takeover 及任何未进入正式 v0.6 catalog 的旧动态 action。

Upgrade 同时存在 duration/rank 权威冲突，但 VS06-B 不解决规则。所有 upgrade 统一返回 `monster_upgrade_deferred_vs06`；developer receipt 可另记 `monster_upgrade_rule_authority_conflict`，不得选择旧 owner 或 catalog 中任一候选语义。

Reference owner、legacy bool 成功或 roster-only 成功都不是 production 证据。

## 2. 唯一 owner 与真人/AI 同路

`MonsterRuntimeController` 继续唯一拥有：

- `auto_monsters` roster；
- UID、slot、selected slot 与 special cursor；
- 怪兽 rank、HP、duration、位置、隐藏归属与内部 meters；
- 自动行动、移动、战斗、伤害、击退、复活和赌局；
- 怪兽 save data 与本 P0 transaction journal。

真人与 AI 必须提交相同结构的 Card Flow intent，经过同一个 `MonsterCardEffectAdapterV06`、同一个 SS06-07 port 和同一个 `MonsterRuntimeController` owner lifecycle。AI 不得：

- 直接 append roster；
- 使用更宽松的 target/binding limit；
- 调用旧 bool summon 绕过 transaction；
- 获得隐藏的免费 retry 或不同 exact-once 规则。

`actor_id`、card instance、target、profile、revision 与 hashes 是唯一差异化输入；代码不得按“真人/AI”建立业务分支。

现有 `_summon_monster_from_card(...) -> bool` 暂时只作为 legacy v0.4/main/characterization compatibility surface。它不是 P0 生产入口，也不构成 capability 证明。

## 3. 正式 P0 intent

冻结的 SS06-07 外层 schema 保持：

```text
effect_kind = deploy_or_upgrade_monster
action_kind = deploy_or_upgrade_monster
```

Owner prepare 只在下列条件全部成立时派生：

```text
resolved_action_kind = deploy_monster_rank1_starter_first
```

硬条件：

1. card 来自正式 v0.6 monster catalog；
2. `card_rank = 1`；
3. profile 明确 `starter_play_free = true` 或等价正式 starter 标记；
4. card/profile family、rank 与 hashes 一致；
5. actor 的 first-summon 状态为 `not_summoned`；
6. actor 当前没有 active owned monster；
7. 来自公开规则输入的 binding limit 至少为 1；
8. target 只有一个未毁 region，不同时携带 unit target；
9. region revision/fingerprint 仍与选择时一致；
10. 所有适用 cross-owner dependency 都满足原子合同。

不满足时零业务 mutation。稳定 reason 至少包括：

- `monster_starter_card_required`；
- `monster_starter_rank_must_be_one`；
- `monster_first_summon_already_consumed`；
- `monster_first_summon_state_unknown`；
- `monster_first_summon_owned_actor_exists`；
- `monster_region_binding_changed`；
- `monster_cross_owner_atomicity_unavailable`。

## 4. First-summon truth

“首次召唤”不能只通过当前 roster 是否为空推断。怪兽离场后 roster 可能为空，但 starter 权利不能恢复。

Owner 保存每个 actor 的三态 marker：

- `not_summoned`；
- `summoned`；
- `legacy_unknown`。

Marker 是 first-summon 业务真相，不是第二套 roster。它必须：

- 在 prepare 中只读取/预留；
- 与 actor/card instance/transaction binding 一起提交；
- rollback 时精确恢复；
- finalize 后保持 `summoned`；
- save/load；
- 不进入 public snapshot。

新局由权威 setup 明确初始化为 `not_summoned`。旧存档若没有足够证据证明 starter 是否已经使用，必须迁移为 `legacy_unknown` 并阻止新的 starter summon，不能默认重置为可用。

## 5. Internal meter contract

P0 actor 的 meter 初始化必须完全由正式 Rank-I profile 与已有 balance owner 决定，adapter 不重算数值。

### 5.1 HP 与 duration meters

Commit 后：

- `hp = max_hp =` 正式 Rank-I profile HP；
- `duration` 来自正式 Rank-I profile；
- `remaining_time = duration` 只适用于首次部署初始化；
- P0 不对 upgrade duration 做任何推论；
- duration 后续仍由现有 realtime tick 递减。

### 5.2 Owner-damage cash meter

首次部署只初始化既有内部字段：

- `owner_damage_cash_total`；
- `owner_damage_cash_pool`；
- `owner_damage_cash_lost = 0`；
- last-damage fields 为安全初值；
- `owner_revealed = false`；
- `owner_clue` 为空。

该初始化不得立即扣玩家现金、产生公开 clue 或把 owner 暴露给 public snapshot。后续受伤现金/线索仍由既有 damage lifecycle 处理，不属于 VS06-B。

### 5.3 Movement/action meters

首次部署只设置正式 profile 的初始位置与 movement stats：

- 不创建 linear-motion envelope；
- 不瞬移到第二个区域；
- 不触发 path damage、攻击、赌局或 target roll；
- 不重置全局 `monster_timer` / `special_monster_timer`；
- 后续移动继续使用已有米/秒 owner 与 tick 顺序。

## 6. Side-effect owner matrix

| 副作用 | 权威 owner | P0 分类 | Ready 要求 | 缺能力结果 |
| --- | --- | --- | --- | --- |
| roster/UID/selection/first-summon marker/meters | `MonsterRuntimeController` | 本地 business state | 副本构造、一次 swap、revision + fingerprint | fail-closed |
| starter card 消费及费用 | 唯一 Card Flow + `CardPlayerStateProductionAdapterV06` | 外层 transaction | 继续复用唯一 transaction service | Monster owner 不自行扣卡 |
| Rank-I bound skill grant | 玩家私有 inventory owner | 跨 owner business state | 若正式 starter profile 要求技能，必须有 prepare/commit/rollback/finalize/exact-once/save/checkpoint | `monster_cross_owner_atomicity_unavailable` |
| economy boon / product refresh | `ProductMarketRuntimeController` | 跨 owner business state | 仅在正式 profile 要求时成为 mandatory participant | `monster_cross_owner_atomicity_unavailable` |
| role upgrade cash | 玩家 cash owner | P0 不适用 | 不调用 | 不得产生返现 |
| region lifecycle/revision | `RegionInfrastructureRuntimeController` 经 bridge | 权威 read binding | region id/revision/fingerprint/未毁 | stale/missing 时拒绝 |
| catalog/profile | 正式 v0.6 catalog/profile owner | 权威 read binding | profile id/revision/fingerprint | missing 时拒绝 |
| scenario signal | Scenario owner | finalize 后 outbox | business finalize 后 exact-once emit | 不改变业务真相 |
| log/callout/trail/UI | WorldBridge/presentation | finalize 后 outbox | pure data + exact-once event id | 不伪造 rollback |

跨 owner participant 若只有 bool、缺 rollback/finalize、没有相同 transaction binding，或只在 reference Bench 中成功，均不 ready。禁止只提交 roster、遗漏 starter profile 明确要求的绑定技能或经济副作用后宣称完成。

## 7. Stable owner API

SS06-07 port 使用：

```gdscript
unit_card_runtime_capabilities_v06(domain: String) -> Dictionary
prepare_unit_card_intent_v06(intent: Dictionary) -> Dictionary
commit_unit_card_intent_v06(prepared: Dictionary) -> Dictionary
rollback_unit_card_intent_v06(receipt: Dictionary) -> Dictionary
finalize_unit_card_intent_v06(receipt: Dictionary) -> Dictionary
unit_card_checkpoint_status_v06(domain: String) -> Dictionary
unit_card_snapshot_v06(domain: String) -> Dictionary
```

Owner 可另提供：

```gdscript
monster_runtime_capabilities_v06() -> Dictionary
```

Capability matrix 必须由以下事实计算，禁止常量 `true`：

- method existence；
- declared v0.6 capabilities；
- first-summon state owner ready；
- profile/region binding ready；
- cross-owner dependency matrix；
- save/load/checkpoint；
- privacy-safe production snapshot；
- supported effect/action/resolved action allowlist。

建议矩阵明确：

```text
supported_effect_kinds = [deploy_or_upgrade_monster]
supported_action_kinds = [deploy_or_upgrade_monster]
supported_resolved_actions = [deploy_monster_rank1_starter_first]
blocked_resolved_actions = {
  deploy_monster_nonstarter: monster_nonstarter_deploy_deferred_vs06,
  upgrade_monster: monster_upgrade_deferred_vs06
}
```

`atomic_ready` 只表示 P0 starter first summon ready，不得暗示 upgrade 或普通 deploy ready。

## 8. Immutable binding

必须保留 SS06-07 外层 binding：

- transaction、actor、card 与 card instance IDs；
- effect/action kinds；
- target/payload/intent hashes；
- `unit_intent_fingerprint`；
- `expected_owner_revision`。

Prepare association 再绑定：

- `resolved_action_kind`；
- owner revision 与 owner-state fingerprint；
- profile id/revision/fingerprint；
- family 与 `card_rank = 1`；
- starter marker 与 card-instance fingerprint；
- region id、legacy index、region revision/fingerprint；
- binding-limit input fingerprint；
- reserved UID；
- cross-owner participant bindings。

UID 是单位身份，slot 只用于显示定位。UI 当前 selected district 不能替代已经哈希的 region target。

## 9. Revision + fingerprint

Owner revision 单调递增，rollback/load 不得倒退。

现有 main、AI 和测试仍可能直接赋值 controller public fields，因此仅 `revision += 1` 不足。每个 atomic API 和 production snapshot 入口必须：

1. 规范化当前 business state；
2. 计算 deterministic SHA-256 fingerprint；
3. 与记录值比较；
4. 发现未 touch 的第三方变化时推进 revision 或使旧 binding 失效；
5. 同时校验 revision 与 fingerprint。

Fingerprint 包含会影响 P0 合法性或 rollback 的 roster、UID、selection、first-summon marker 与 meter 字段；排除 callout/trail/UI transient data。

`_make_auto_monster` 当前会递增 UID，prepare 禁止调用。必须以显式 reserved UID 在副本构造候选 actor。

## 10. Prepare

Prepare 的 roster、UID、marker、手牌、现金、市场与 scenario mutation 必须为零。Transaction association/reservation metadata 不算业务 mutation。

顺序：

1. 校验 v0.6 contract 与外层 hashes；
2. 以 transaction ID 查 journal；
3. 同 ID 同 binding 返回保存 receipt；同 ID 不同 binding 返回 conflict；
4. 校验正式 catalog、Rank I 与 starter marker；
5. 派生唯一 P0 resolved action；任何 upgrade/普通 deploy 立即拒绝；
6. 校验 actor first-summon state、owned monster 与 binding limit；
7. 校验 owner revision/fingerprint；
8. 校验 region revision/fingerprint/未毁；
9. 校验并 prepare 所有适用 cross-owner participants；
10. 在副本构造 actor、roster、UID、selection、marker preimage/postimage；
11. 保存 prepared association。

任何失败都必须 abort 已准备 participant，且所有 business state before == after。Prepare 不发 presentation。

## 11. Commit

Commit 只按 transaction ID 读取 prepare association，不信传入 receipt 自报 actor/effect/target。

顺序：

1. 校验 immutable association；
2. exact-once replay terminal/committed receipt；
3. 重验 owner、region、profile、first-summon、binding-limit 与 participant bindings；
4. 在深副本重新构造 next roster/UID/selection/marker；
5. 提交适用 cross-owner participants；
6. 任一失败时，只接受 participant 明确 `rolled_back = true` 的补偿；
7. 补偿失败返回 `monster_compensation_failed`，不得伪造 rolled back；
8. 全部成功后一次 swap Monster owner business state；
9. 推进 owner revision，为新 UID 建 actor revision；
10. 保存 postimage fingerprint、dependency receipts 与 `rollback_open = true`。

Commit 不触发 target roll、移动、战斗、赌局、scenario、log、callout 或 UI。

## 12. Rollback

Rollback 必须完整 preflight 后再恢复：

1. transaction association 选择 authoritative committed record；
2. 校验 binding；
3. 已 rolled back 的同 binding exact replay；
4. finalized/closed 返回 `monster_rollback_closed`；
5. 校验当前 revision、roster/postimage、UID、marker 与 participant state；
6. 任一不符时 before == after；
7. 在副本构造 restored roster/UID/selection/marker；
8. participant rollback 全部明确成功后，一次 swap restored state；
9. owner revision继续增加，不恢复旧整数 revision；
10. 保存 terminal rollback receipt。

Receipt/preimage/postimage 被篡改、第三方 tick/state advance 或 participant rollback false 时，不得先 remove 新怪兽或恢复 starter marker。

## 13. Finalize 与 presentation

Finalize 只使用 association 中的 committed receipt：

- finalized 同 binding replay不重复处理；
- rolled-back transaction 不能 finalize；
- dependency finalize 失败返回 `finalized = false`，保留 committed association、阻止 checkpoint并允许 retry；
- 只有所有 owner 明确成功后，设置 `finalized = true`、`rollback_open = false`；
- 成功后 rollback 永久 closed；
- 成功后写一个以 transaction binding 派生 event ID 的 pure-data presentation outbox event；
- scenario/log/callout/UI 只能消费该 outbox 一次；
- 重放不得重复显示、重复 scenario signal 或重复授予任何收益。

若 dependency 不能证明 finalize all-or-none，或不能持久化可重试进度，P0 capability 不 ready。

## 14. Exact-once journal

每个 record 至少保存：

- immutable binding；
- `resolved_action_kind`；
- stage：prepared/committed/rolled_back/finalize_failed/finalized；
- preimage/postimage 与 fingerprints；
- owner revision before/after；
- starter marker before/after；
- actor/region/profile bindings；
- dependency receipts；
- rollback window；
- terminal receipt；
- presentation outbox delivery state。

同 transaction ID 同 binding返回相同结果；不同 binding拒绝。Commit replay 不重复创建 UID/actor，rollback replay不重复恢复，finalize replay不重复发事件。

Transaction journal 不可替代 response ID journal。

## 15. Production snapshot

`unit_card_snapshot_v06("monster")` 必须来自真实 `MonsterRuntimeController`，不是 reference owner 或 adapter cache。

P0 public-safe snapshot 至少包含：

- `available`、contract version；
- owner revision 与不含秘密的 snapshot fingerprint；
- public roster；
- 每只怪兽的 UID、family/profile public label、Rank I、HP/max HP、region、down、remaining duration 与可见 movement state；
- P0 supported/blocked action summary；
- checkpoint readiness。

Commit 后，新怪兽必须在下一次 production snapshot 中可见；rollback 后消失；save/load 后保持相同 public business facts。

Public snapshot 不包含 first-summon marker、raw owner、owner-damage cash pool、private bound skills、transaction binding 或 developer data。

## 16. Save/load/checkpoint

现有 flat monster save keys 保留。新增纯数据段：

```text
monster_deploy_atomic_v06:
  schema_version
  owner_revision
  owner_state_fingerprint
  actor_revisions
  starter_summon_state_by_actor
  transaction_journal
  presentation_outbox
```

Checkpoint 必须在 prepared、rollback-open committed、compensation failed、finalize failed、孤儿 dependency reservation 或未安全持久化 outbox 时返回 false。

`to_save_data()` 可为 focused crash-recovery 测试序列化 pending 与 terminal record；生产 save writer 必须先尊重 checkpoint gate。

`apply_save_data()` 必须：

1. 接受整个 outer flat envelope；
2. 接受缺新段的 legacy save；
3. 在副本完整验证纯数据、UID、slot、next UID、actor revisions、starter markers、journal stages、bindings、rollback window、terminal receipt、dependency checkpoints 与 fingerprint；
4. pending record 缺 matching dependency checkpoint 时拒绝；
5. 全部成功后一次 swap；
6. 失败时 before == after；
7. load 不触发技能、市场、scenario、presentation或任何 cash effect；
8. terminal receipts 在 load 后仍能 exact-once replay。

Legacy save 中存在 owner monster 可把对应 actor marker安全迁移为 `summoned`。无法证明是否使用 starter 的 actor必须为 `legacy_unknown`，不能默认 `not_summoned`。

## 17. Public/private/developer 隐私

Public view 使用显式 allowlist + 递归 sanitizer，再由独立递归 leak scanner验证。

Public 禁止：

- unrevealed owner、true/hidden owner、owner truth/index；
- first-summon private marker；
- owner-damage cash meter；
- lure target/source；
- bound skills、手牌、弃牌、对手 cash/ledger；
- AI plan/score/pressure/learning metadata；
- transaction/card instance binding、hash、path、raw error、developer fields。

Private view 只向本人提供 `owned_by_viewer`、自己的可操作状态与本地化失败原因，不复制完整玩家手牌/现金。

Developer view 可包含 reason、revision、fingerprints、journal stage 与 dependency receipts，但不得流入玩家 UI。

隐私测试必须在嵌套 Dictionary/Array 注入 forbidden keys/values，要求 recursive leak count 为 0；顶层检查不够。

## 18. Upgrade 与 stale evidence

Upgrade 延期原因：

- v0.6 候选为 remaining duration +60、非 total refresh；
- legacy owner/50-case 要求 `remaining_time = duration`；
- rank card、逐级提升、低/同级重复与 IV refresh 尚无统一权威表。

因此 P0 永远不进入 `_upgrade_field_monster_from_card`，也不借 starter deploy 偷渡 upgrade。

旧 50-case 中以下证据已陈旧：

- 两个 upgrade case 对完整 duration refresh 的期待；
- 两个 save case 调用后续迁移已删除的 main `_capture_run_state`；
- source assertion要求 main 保留旧 save merge symbol。

不得恢复旧 wrapper或旧规则来使它们变绿。仍必须保护：

- `first_summon_free_placement` 的非冲突行为；
- 单一 Monster owner；
- 自动行动/shared RNG/movement/combat/wager顺序；
- public hidden-owner boundary；
- legacy flat save基本兼容。

旧 bool first-summon characterization 只能证明 legacy compatibility；新 VS06-B focused tests、真实 production snapshot 与 Godot 4.7 Bench 才证明 P0 runtime skeleton。

## 19. P0 production hard gate

Rank-I starter first summon 只有同时满足以下条件才可报告 ready：

1. 真人与 AI 同 owner API/同校验；
2. 正式 Rank-I starter profile binding稳定；
3. owner methods + declared capabilities真实满足；
4. revision + fingerprint可发现直接写与第三方推进；
5. region与first-summon marker稳定绑定；
6. 所有适用跨 owner participant完整原子；
7. prepare/commit/rollback/finalize/exact-once focused tests通过；
8. pending/terminal save-load与checkpoint通过；
9. commit/rollback/load在production snapshot中正确可见；
10. HP/duration/owner-damage/movement meter合同通过；
11. public recursive leak scan为0；
12. 自动怪兽非陈旧 characterization无回归；
13. Godot 4.7真实 Bench通过，debug errors与stop finalErrors为空。

报告必须分别写：

- `rank1_starter_first_summon_ready`；
- `nonstarter_deploy_ready = false`；
- `upgrade_ready = false`。

不得用 combined outer effect 的存在把后三者混为一个“怪兽牌已全部接入”。

## 20. 最小未来接线

P0 ready 后，Coordinator 只需：

1. 把真实 `MonsterRuntimeController` 配给现有 Monster adapter；
2. 真人与 AI 都通过现有 `play_core_card(..., effect_handler, ...)`；
3. target context携带已哈希 region 与权威 owner/region revision；
4. 继续由唯一 Card Flow提交 starter card/玩家状态；
5. 玩家状态提交失败时按 association rollback；
6. 玩家状态成功后 finalize；
7. finalized后才允许 checkpoint与presentation outbox delivery。

不新增 transaction service、玩家状态 owner 或 monster roster。Upgrade、普通 deploy 与固定兽技留给后续独立任务。
