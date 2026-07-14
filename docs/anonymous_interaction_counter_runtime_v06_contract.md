# v0.6 匿名互动与反制运行时合同

日期：2026-07-14  
状态：独立 schema/router/window/privacy/production-port 骨架；未接 main、Coordinator、Queue 或玩家 UI。

## 1. 权威边界

本模块只处理互动效果 intent/receipt、字段路由、响应窗口状态和 receipt 可见性，不拥有卡牌、现金、六色资产、城市产权、合约真相或情报真相。

- 卡牌离手、费用预留与资源提交继续由冻结 `CardFlowTransactionServiceV06` 和唯一 production state port 负责。
- 互动效果 owner 必须是现有领域 owner 的窄 forwarding adapter；不得创建第二套手牌、现金、合约、情报或产权状态。
- prepare 阶段保存的 `transaction_id -> authoritative effect_kind + route_domain` 是后续 commit/rollback/finalize 的唯一路由权威。owner 回执不能改选效果类型。
- reference owner 只能定义在 tests/Bench 内，不得组合进生产场景。

## 2. 字段路由

路由只读取机器字段，不读取中文名、卡面文本或 `family_id`：

| route_domain | 字段条件 |
|---|---|
| `direct_player` | `effect_payload.direct_player_interaction=true`，且 effect/target 指向玩家 |
| `counter_response` | `effect_kind=card_counter`、`target_kind=incoming_direct_player_interaction`、`target_scope=direct_player_interaction`、`response_depth=1` |
| `contract` | `effect_kind` 以 `contract_` 开头或 `interaction_domain=contract` |
| `intel` | `effect_kind` 以 `intel_` 开头或 `interaction_domain=intel` |

当前目录中 `player_hand_disrupt`、`player_hand_steal` 属于 direct-player；`card_counter` 属于 counter-response。经济、怪兽自主行动、天气和普通地图效果不满足这些字段，必须在创建窗口前拒绝且零副作用。

## 3. Schema

intent 必填：

```text
schema_version=0.6
transaction_id, actor_id
card_id, card_instance_id
effect_kind, target_kind
target_player_ids[]
target_revision >= 0
effect_payload{}
target_hash, payload_hash, intent_hash
```

prepared/commit/rollback/finalize receipt 都必须原样绑定：

```text
transaction_id, actor_id, card_id, card_instance_id
effect_kind, target_kind
target_hash, payload_hash, intent_hash
```

阶段布尔值分别为 `prepared / committed / rolled_back / finalized`。只有 owner 明确返回对应 `true` 才算成功；缺字段、错绑定、无 rollback、无 finalize 或结构错误都不能伪造成成功。

## 4. CounterResponseWindowV06

窗口只保存 `window_id`、绑定 transaction、incoming effect 字段、合法 responder、权威 opened/deadline、每席 pass/respond 记录、状态、revision 和 exact-once action journal；不保存牌、现金、资产或 owner 私有状态。

- deadline 必须由调用方从权威规则/目录字段传入；运行时没有新硬编码默认值。
- 合法状态：`open -> resolved(all_passed|countered|timeout|no_eligible_responder)` 或 `open -> cancelled`。
- 同一 responder 只能 pass/respond 一次；同一 response ID+payload 重放返回 journal，ID 碰撞拒绝。
- 无人可响应也必须创建并得到 `no_eligible_responder` 解释结果。
- save data 完整保存 open window 和 action journal；`apply_save_data` 恢复 inflight 状态。checkpoint 返回 inflight IDs，不会静默丢弃窗口。
- 首版响应深度固定为 1；反制牌本身不再开启第二层窗口。

## 5. Capability matrix 与生产硬门

production forwarding port 要求 owner 同时声明并实现：

| capability | 要求 |
|---|---|
| snapshot | viewer-safe snapshot API |
| prepare | 无副作用验证/预留 |
| commit | 原子、绑定、幂等提交 |
| rollback | 明确 `rolled_back=true` 的原子补偿 |
| finalize | 明确 `finalized=true` 且不再改规则效果 |
| revision | 目标 revision/CAS |
| exact-once | transaction journal/replay |
| save-load | owner journal 与 inflight 生命周期可保存 |
| privacy | snapshot 不泄漏 rival/AI 私有信息 |
| checkpoint | inflight 可恢复或明确拒绝 |

任一项缺失，`production_ready=false`，prepare 在玩家资源提交前返回 `interaction_owner_atomic_contract_missing`。现有 Contract、Intel、CardInventory/PlayerHandInteraction owner 不满足完整矩阵，因此本轮真实生产效果全部保持 fail-closed。

## 6. Receipt 可见性

- public：递归移除 `true_owner/hidden_owner/owner_truth`、任何 hand/discard、现金/资产、private payload、developer fields 与 AI metadata。
- private：只合入 `private_by_viewer[viewer_id]`，仍移除对手资源和 AI 私有计划。
- developer：保留完整诊断数据，只可用于测试/开发，不得直接生成玩家 UI 文本。

玩家 UI 文本只能消费 public receipt 或明确 viewer-scoped private snapshot，禁止从 raw/private payload 推导。

## 7. 未来最小接线 API

Coordinator/Queue 未来只需：

```gdscript
router.prepare_effect(intent) -> prepared receipt
router.commit_effect(prepared) -> commit receipt
router.rollback_effect(commit_or_prepared) -> rollback receipt
router.finalize_effect(commit) -> finalize receipt
window.open_window(rule_bound_request) -> window snapshot
window.submit_pass(...) / submit_response(...)
window.resolve_timeouts(authoritative_now)
window.to_save_data() / apply_save_data(data)
sanitizer.sanitize_public/private/developer(receipt)
```

接线前必须先为真实 owner 补齐 capability matrix，并把响应窗口 save section 纳入 v0.6 save envelope。本轮不修改 Coordinator/Queue/UI。
