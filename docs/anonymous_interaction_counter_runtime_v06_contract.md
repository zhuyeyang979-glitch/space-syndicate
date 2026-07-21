# v0.6 匿名互动与反制运行时合同

日期：2026-07-22
状态：现役 direct-player / intel / counter-response 边界；旧合同响应已退役。

## 1. 规则边界

本合同只覆盖三类现役互动：直接玩家互动、情报效果，以及可反制直接互动的一层正式反制。它不拥有手牌、现金、六色资产、城市产权、商品网络或情报真相；这些状态仍由各自唯一领域 Owner 管理。

v0.6 不存在目标玩家接受、拒绝或超时的专用合同响应。条件式订单与供货由 `GlobalSupplyDemandRuntimeServiceV06` 按公开网络事实规划，经 CardResolution exact-once lineage 进入 `CommodityFlowRuntimeController` 原子结算，不创建 responder、签署状态、拒绝惩罚或第二响应窗。

## 2. 字段路由

路由只读取机器字段，不读取中文名、卡面文本或 `family_id`：

| route_domain | 字段条件 |
|---|---|
| `direct_player` | `effect_payload.direct_player_interaction=true`，且 effect/target 指向玩家 |
| `counter_response` | `effect_kind=card_counter`、`target_kind=incoming_direct_player_interaction`、`target_scope=direct_player_interaction`、`response_depth=1` |
| `intel` | `effect_kind` 以 `intel_` 开头或 `interaction_domain=intel` |

未知 domain、旧合同 domain 或缺失字段必须在创建窗口前 fail closed，且不得产生任何资源、状态或公开日志副作用。

## 3. Intent 与 receipt

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

prepared、commit、rollback、finalize receipt 必须原样绑定 transaction、actor、card identity、effect/target kind 和三个 hash。只有领域 Owner 明确返回相应成功字段才算成功；缺字段、错绑定、无 rollback/finalize 或结构错误都不能伪造成成功。

## 4. 一层反制窗口

`CounterResponseWindowV06` 只保存窗口 identity、incoming effect binding、合法 responder、权威 deadline、每席 pass/respond 记录、状态、revision 和 exact-once journal。它不保存卡牌、现金、资产或 Owner 私有状态。

- 合法状态为 `open -> resolved(all_passed|countered|timeout|no_eligible_responder)` 或 `open -> cancelled`。
- 同一 responder 只能提交一次；同一 response ID 和 payload 重放返回 journal，ID 碰撞拒绝。
- 无人可响应时以 `no_eligible_responder` 解释完成。
- 响应深度固定为 1；反制牌本身不再开启第二层窗口。
- 保存只恢复现役反制窗口。旧合同响应字段必须在应用前被识别并拒绝，不能转换成反制窗口。

## 5. Capability 与隐私

生产 forwarding port 只可连接声明并实现 snapshot、prepare、commit、rollback、finalize、revision/CAS、exact-once、save-load、privacy 和 checkpoint 能力的现役领域 Owner。缺少任一能力时，必须在玩家资源提交前 fail closed。

- public receipt 递归移除 owner truth、手牌/弃牌、现金/资产、private payload、developer fields 与 AI metadata。
- private snapshot 只合入当前 viewer 被授权的数据，仍移除对手资源和 AI 私有计划。
- developer receipt 只用于测试和开发工具，不得生成玩家 UI 文本。

玩家 UI 只能消费 public receipt 或明确 viewer-scoped private snapshot。旧版签署流程字段只可作为历史或迁移负向证据，不能成为新 Owner、Port、Sink、窗口、AI policy 或 save section 的依据。
