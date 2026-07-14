# v0.6 卡牌权威事务边界

日期：2026-07-14

## 用途

`CardFlowTransactionServiceV06` 定义履带领取、动态市场购买、手动合成和打出卡牌的事务语义。UI 只提交意图，不得自行扣钱、移除牌、刷新市场或调用效果后再补扣资产。

本服务目前位于独立 v0.6 路径，内存玩家状态只用于 Bench 和回归测试，不能直接作为生产第二份玩家真相。生产接线必须先提供 `CardPlayerStatePortV06`，再通过 adapter 连接现有牌源和效果 owner，不复制第二套手牌、现金、资产、设施、怪兽或军队状态。

生产状态端口至少需要：

```gdscript
func read_player(actor_id: String) -> Dictionary
func reserve_transaction(transaction_id: String, intent_hash: String, expected_revisions: Dictionary, actor_ids: Array) -> Dictionary
func commit_reserved(reservation: Dictionary, next_states: Dictionary, effect_receipt: Dictionary) -> Dictionary
func abort_reserved(reservation: Dictionary, reason: String) -> Dictionary
func replay_result(transaction_id: String, intent_hash: String) -> Dictionary
```

该端口必须把生产的手牌、现金和六色资产聚合成同一 revision/CAS 边界。玩家互动牌需要在一次 reservation 中同时锁定发起者和目标玩家。当前 `PlayerManaRuntimeController` 的预留 API 可作为资产部分的下层能力，但旧 CardInventory、现金和跨玩家手牌仍不能单独充当此端口。

reference memory port 可以提交完整 `next_states` 以验证原子语义；生产 adapter 应优先提交精确的卡牌移动、现金 debit/credit 和资产 reservation mutation。预留期间新增的实时收入或资产恢复不得被旧快照覆盖；也不能把资产控制器的全局 tick revision 当作单个玩家 revision。

## 玩家权威状态

端口返回的每名玩家快照至少包含：

- `actor_id`
- 单调递增的 `revision`
- `cash`
- 六色 `assets`：`life / energy / industry / technology / commerce / shipping`
- 五张普通手牌和每张牌的 `runtime_instance_id`

不存在第七个 `generic` 资产池。通用费用在计划阶段被展开为六色资产的精确扣款组合。

## 牌源事务

履带和市场都必须提供稳定 `item_id` 与单调 `revision`。

- 履带领取成功时，在同一同步事务中把牌放入手牌、处理满手同名同级自动合成、移除来源 item 并推进 revision。
- 市场购买成功时，在同一同步事务中放牌、扣一次现金、替换为预先验证的下一 listing 并推进 revision。
- 旧 revision、已消费 item、重复竞争者均失败，且玩家状态不变。
- 同一 `transaction_id + intent` 返回 journal 中的原结果；相同 transaction ID 对应另一意图时拒绝。

## 效果两阶段协议

效果 adapter 必须实现：

```gdscript
func prepare_effect(intent: Dictionary) -> Dictionary
func commit_effect(prepared_receipt: Dictionary) -> Dictionary
```

`prepare_effect` 只做最终合法性检查和资源预留，禁止产生游戏副作用。返回值必须包含 `prepared=true`，并原样绑定：

- `transaction_id`
- `actor_id`
- `card_id`
- `card_instance_id`
- `effect_kind`
- `target_hash`
- `payload_hash`
- `intent_hash`

服务验证 prepare 收据后才暂时扣除卡牌与六色资产，再调用 `commit_effect`。成功收据必须包含 `committed=true` 和同一组绑定字段。

效果 owner 还应提供以下可选补偿方法：

```gdscript
func abort_prepared_effect(prepared_receipt: Dictionary) -> void
func rollback_effect(commit_receipt: Dictionary) -> Dictionary
func finalize_effect(commit_receipt: Dictionary) -> Dictionary
```

prepare 失败时不扣牌、不扣资产；commit 失败时恢复玩家卡牌、资产和 revision。效果 owner 的 commit 必须幂等，并保证返回失败时没有部分副作用；若已产生副作用但收据错配，`rollback_effect` 必须完成补偿。

`rollback_effect` 必须返回结构化收据，并且只有明确的 `rolled_back=true` 才算补偿成功。缺少 rollback、返回值无效或 `rolled_back=false` 时，事务以 `effect_compensation_failed` 终止：卡牌、现金与资产不得提交，结果不得伪造 `rolled_back=true`，机器字段保留 `original_reason_code / state_port_reason_code / compensation` 供开发排查；玩家反馈只显示本地化的原因与下一步。

生产状态端口如果实现 `prepare_reserved_mutations(reservation_id, next_states)`，事务服务必须在效果 commit 前完成精确手牌、现金和六色资产变更的预留。效果 commit 成功但玩家状态提交失败时，仍调用 `rollback_effect`；只有效果与玩家状态都提交成功后，才调用可选的 `finalize_effect` 释放临时 preimage、路由映射或 reservation 元数据。终结阶段不得再次改变规则效果。事务结果中的 `effect_finalization` 必须如实标记是否支持、是否完成及是否失败；缺少 finalize 不得被写成已完成。

效果 router 必须以 prepare 时保存的 `transaction_id → effect_kind` 关联为唯一路由权威，不能让 commit receipt 自行选择 rollback/finalize owner。只有 owner 明确返回 `rolled_back=true` 后才删除回滚关联；只有 owner 明确返回 `finalized=true` 后才归档 finalize 结果。失败关联必须保留给诊断或独立重试，未知 transaction 的 finalize 必须失败闭合，成功 finalize 的重放不得再次调用 owner。

## 玩家提示

所有拒绝结果都携带本地化 `feedback.reason` 与 `feedback.next_step`。`reason_code`、事务哈希、卡牌 ID、资源路径或 raw error 只供机器和开发者使用。

## 生产接线门禁

接入某个 `effect_kind` 前必须同时满足：

1. 有且只有一个权威效果 owner。
2. adapter 完成 prepare/commit/补偿协议。
3. 目标 revision 和唯一槽位在 prepare 阶段验证。
4. commit 使用同一事务 ID，重复调用不重复结算。
5. 效果失败时卡牌、现金和资产没有净损失。
6. 玩家文本不显示内部字段，并统一使用“资产”。
