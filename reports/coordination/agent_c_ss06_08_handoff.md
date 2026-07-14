# Agent C SS06-08 Anonymous Interaction & Counter Runtime v0.6 交接

日期：2026-07-14  
范围：匿名互动 intent/receipt schema、字段路由、一层反制窗口、receipt 隐私过滤、production owner capability 硬门、聚焦测试与独立 Godot MCP Bench。

## 结论

Agent C 独占范围已完成，未接 main、GameRuntimeCoordinator、CardResolutionQueue 或玩家 UI，也未修改任何现有 owner。当前交付是可安全接线的独立骨架：reference owner 可证明完整生命周期；真实 Contract、Intel、CardInventory/PlayerHandInteraction owner 因缺少原子 rollback/finalize/revision/exact-once/save-load 完整组合，production port 会在玩家卡牌/现金/资产提交前结构化 fail-closed。

所有逻辑按 `effect_kind / target_kind / effect_payload` 路由，不匹配中文卡名。相位否决只接受 `card_counter + incoming_direct_player_interaction + target_scope=direct_player_interaction + response_depth=1`；经济、怪兽自主行动、天气和普通地图效果拒绝且不创建窗口/不调用 owner。

## 只读审计与协作边界

已读取：

- 根 `AGENTS.md`、v0.6 player rulebook/runtime directive/development plan/Profile。
- v0.6 card catalog：直接互动 `player_hand_disrupt` / `player_hand_steal`，反制 `card_counter`；窗口秒数来自目录 `effect_payload.counter_window_seconds`，运行时未增加默认数字。
- CardResolutionQueue、Contract、Intel、CardInventory、PlayerHandInteraction、CardFlow transaction/state port、City/ownership 公开 API。
- `reports/coordination/agent_a_ss06_06_handoff.md` 与 frozen CardFlow prepare/commit/rollback/finalize 合同。
- Agent B 当前共享 `scripts/cards/v06/units/*` schema/router/port/filter 实现。截止交接时未出现新的 SS06-07 handoff；现有最新 B handoff 仍为 `agent_b_core_economy_handoff.md`。

本轮只新增用户授予 Agent C 的路径。没有覆盖、回滚或编辑 Agent A/B 文件；没有 commit、push、merge、`git add -A`，没有运行默认 `user://` full smoke。

## 新增文件

生产骨架：

- `scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd`
- `scripts/cards/v06/interaction/interaction_effect_router_v06.gd`
- `scripts/cards/v06/interaction/counter_response_window_v06.gd`
- `scripts/cards/v06/interaction/anonymous_interaction_receipt_sanitizer_v06.gd`
- `scripts/cards/v06/interaction/anonymous_interaction_owner_forwarding_port_v06.gd`

测试与 Bench：

- `tests/anonymous_interaction_schema_v06_test.gd`
- `tests/anonymous_interaction_router_v06_test.gd`
- `tests/counter_response_window_v06_test.gd`
- `tests/anonymous_interaction_privacy_v06_test.gd`
- `tests/anonymous_interaction_owner_capability_v06_test.gd`
- `scripts/tools/anonymous_interaction_runtime_v06_bench.gd`
- `scenes/tools/AnonymousInteractionRuntimeV06Bench.tscn`

合同与证据：

- `docs/anonymous_interaction_counter_runtime_v06_contract.md`
- `reports/cards/anonymous_interaction_runtime_v06/anonymous_interaction_runtime_v06_validation.md`
- 本交接文件。

reference owner 仅以内嵌 test/Bench class 存在，未进入 production。

## Capability matrix

| Owner / boundary | snapshot | prepare | commit | rollback | finalize | revision | exact-once | save-load | privacy | 当前生产状态 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| CardFlow transaction | 是 | 是 | 是 | 显式 owner receipt | 显式 owner receipt | 是 | 是 | inflight checkpoint 有硬门 | 需本模块过滤 | 可作为外层事务 |
| Contract v0.5 | public/private | plan | 是 | 否 | 否 | 否 | 否 | 是 | 部分 | fail-closed |
| Intel dossier | public compose | 否 | 只读 | 否 | 否 | 否 | 不适用 | 否 | public-only | fail-closed |
| CardInventory/HandInteraction | facts/debug | plan | 是 | 否 | 否 | fingerprint 非统一 CAS | 否 | 否 | 不足 | fail-closed |
| Agent C reference owner | 是 | 是 | 是 | 是 | 是 | 是 | 是 | 是 | 是 | tests/Bench only |

`AnonymousInteractionOwnerForwardingPortV06.production_ready` 只有在 owner 同时声明且实现 snapshot/prepare/commit/rollback/finalize/checkpoint，并声明 revision/exact_once/save_load/privacy_safe_snapshot/atomic_mutation_ready 后才为 true。

## 生命周期与 exact-once

1. schema 验证机器字段、目标 revision、direct-player/counter scope。
2. router 在 prepare 成功时记录 `transaction_id -> authoritative_effect_kind + route_domain + binding`。
3. commit、rollback、finalize 都从该 association 选择 owner；receipt 自报的 effect kind 不可信，错绑定拒绝。
4. 已成功阶段重放返回 journal receipt 并标记 `idempotent_replay=true`，不重复调用 owner。
5. rollback/finalize 失败保留 inflight association，checkpoint 明确拒绝；不会伪造成功。

因此同一 transaction 重放不会二次拆牌、偷牌、转移产权、签约或产生情报；实际资源/业务 exact-once 仍要求未来真实 owner 达到 capability 硬门。

## CounterResponseWindowV06

- 只保存窗口状态、合法 responder、权威时钟、revision 与 action journal；不复制卡牌/现金/资产。
- deadline 必须由调用方从权威 Profile/catalog 传入，内部无新默认值。
- 覆盖 pass/respond、无权限、重复 responder、response ID replay/collision、超时、取消、no eligible responder。
- 首版一层响应；反制本身不再打开响应窗口。
- `to_save_data/apply_save_data` 可完整恢复 inflight window 与 journal；checkpoint 返回 inflight IDs，保存不会静默丢窗口。

未来 Coordinator 必须对每个 `counterable=true` 的 direct-player 互动调用 `open_window`，即使没有玩家持有反制，也让状态机产出 `no_eligible_responder`。这条接线本轮未做。

## Privacy

public sanitizer 递归移除：

- `true_owner / hidden_owner / owner_truth`
- 任意 hand/discard、对手现金、私有资产、inventory/cards
- private payload/developer fields
- AI metadata/private plan

private sanitizer 只合入 `private_by_viewer[viewer_id]`，仍移除 rival/AI 私有字段。developer receipt 保留诊断真相，但不得供玩家 UI。public privacy scan 为 `0 leaks`。

## 验证结果

聚焦测试：

| 测试 | 结果 | checks |
|---|---:|---:|
| anonymous_interaction_schema_v06_test.gd | PASS | 13 |
| anonymous_interaction_router_v06_test.gd | PASS | 23 |
| counter_response_window_v06_test.gd | PASS | 13 |
| anonymous_interaction_privacy_v06_test.gd | PASS | 6 |
| anonymous_interaction_owner_capability_v06_test.gd | PASS | 6 |
| 合计 | PASS | 61/61 |

Godot 4.7 内部 MCP 独立 Bench：

- `AnonymousInteractionRuntimeV06Bench`：8/8 PASS。
- `public_leaks=0`。
- MCP `get_debug_output`：`errors=[]`。
- MCP `stop_project`：`finalErrors=[]`。
- 场景未访问默认玩家存档。

## 未来最小接线 API

Coordinator/Queue 只需组合一个 router、一个 window state owner、现有真实领域 ports 和 sanitizer：

```gdscript
router.prepare_effect(intent)
router.commit_effect(prepared)
router.rollback_effect(receipt)
router.finalize_effect(receipt)
router.checkpoint_status()

windows.open_window(rule_bound_request)
windows.submit_pass(window_id, responder_id, response_id, authoritative_now)
windows.submit_response(window_id, responder_id, response_id, counter_intent, authoritative_now)
windows.resolve_timeouts(authoritative_now)
windows.to_save_data()
windows.apply_save_data(data)

sanitizer.sanitize_public(receipt)
sanitizer.sanitize_private(receipt, viewer_id)
```

接线前必须先完成：

1. 为真实 direct-player/contract/intel/counter owner 补齐并验证 capability matrix；不能用 reference owner 代替。
2. 让 CardFlow 以同一 reservation 同时锁 actor/target，并把 window/router checkpoint 纳入 v0.6 save envelope。
3. 从 catalog/Profile 把 `counter_window_seconds` 传入 window；不在 Coordinator 写第二个默认值。
4. 玩家 UI 只消费 sanitized public 或 viewer-private receipt，不读取 raw/private payload。

本轮不接生产组合，不改变现有规则公式，也不宣称真实互动牌已可在主场景安全打出。

## Lessons for other agents

### invariant

- prepare 阶段记录的 `transaction_id -> effect_kind + route_domain + binding` 是 commit、rollback、finalize 的唯一路由权威；不得信任后续 receipt 自报类型。
- compensation 只有在权威 owner 明确返回 `rolled_back=true` 时成功；finalization 只有明确返回 `finalized=true` 时完成。缺方法、无效 receipt 或显式 false 都必须保持失败状态。
- public/private/dev receipt 必须先按 viewer scope 过滤，再生成 UI 文本；public 层递归删除隐藏 owner、对手现金/资产/手牌/弃牌和 AI metadata。
- 任何 open response window 都必须可 save/load 恢复，或者由 checkpoint gate 明确拒绝；不得在保存时静默丢失 inflight 响应。
- 相位否决只响应字段标记的 direct-player interaction，且只允许一层；经济、怪兽自主行动、天气和普通地图效果必须零副作用拒绝。

### failed approach

- 仅因 owner 有 `plan/commit` 或 public snapshot 就判定 production-ready 是错误的：旧 Contract、Intel 和 HandInteraction 都缺少完整原子 rollback/finalize/revision/exact-once 组合。
- 让 commit/rollback receipt 携带 `effect_kind` 后直接据此选 owner 看似方便，但允许篡改回执跨域路由；应使用 prepare association。
- 只过滤顶层 receipt key 会漏掉嵌套 dictionary/array 中的 owner truth、手牌和 AI 私有数据；必须递归过滤并递归扫描。
- 无人持有反制时跳过窗口会失去可解释结果和 replay/save 证据；应由状态机生成 `no_eligible_responder`。

### stable API

- Schema：`validate_intent`、四类 `validate_*_receipt`、`binding_from`、`binding_matches`、`stage_receipt`。
- Router：`prepare_effect`、`commit_effect`、`rollback_effect`、`finalize_effect`、`checkpoint_status`。
- Window：`open_window`、`submit_pass`、`submit_response`、`resolve_timeouts`、`cancel_window`、`to_save_data`、`apply_save_data`、`checkpoint_status`。
- Sanitizer：`sanitize_public`、`sanitize_private(viewer_id)`、`sanitize_developer`、`scan_public_leaks`。
- 所有 intent/receipt 必须保持 schema `0.6` 与完整 binding keys；窗口 deadline 由 catalog/Profile 的权威字段传入，API 内没有新默认秒数。

### test oracle

- 最小生命周期 oracle：对同一 prepared receipt 调用两次 commit，owner commit call count 必须仍为 1，第二次 receipt 必须有 `idempotent_replay=true`；rollback/finalize 同理。
- 最小 fail-closed oracle：缺任一 atomic capability 的 owner 在 `prepare_intent` 前返回 `interaction_owner_atomic_contract_missing`，owner mutation call count 为 0。
- 最小隐私 oracle：对含嵌套 dictionaries/arrays 的恶意 receipt 执行 `sanitize_public` 后，`scan_public_leaks(...).size()==0`。
- 最小 checkpoint oracle：保存含 open window 的 state，载入新实例后 window 仍为 open、deadline/journal 不变，checkpoint 明确列出该 window ID。
- runtime oracle：Godot 4.7 MCP 独立 Bench `8/8 PASS`、debug `errors=[]`、stop `finalErrors=[]`。

### integration trap

- CardFlow 的玩家 state commit 可能发生在 effect commit 之后；如果真实 owner 不具备原子 rollback，资源端即使不提交也可能留下业务副作用。因此 production port 必须在 CardFlow 资源预留前检查完整 capability matrix。
- Router 与 CounterResponseWindow 是两个不同生命周期：窗口决定 incoming effect 是否继续，router 才执行具体 owner effect。Coordinator 若先 commit direct effect 再开窗口，就已经无法安全否决。
- public receipt 中的匿名 actor 不能通过 private payload、developer fields、tooltip 或 accessibility text 反推；UI 必须只消费 sanitized snapshot。
- response ID journal 与 transaction journal 不能互相替代；一个防重复响应，一个防重复业务 mutation。

### reusable pattern

- capability matrix 同时检查“owner 声明 true”与“方法实际存在”，最后计算单一 `production_ready`；任一能力缺失统一 fail-closed。
- prepared association 保存 authoritative domain/binding，terminal stage 只查 association；成功 receipt 写 journal，失败 association 保留用于诊断或重试。
- sanitizer 使用 recursive transform，privacy test 再用独立 recursive scanner 验证，避免过滤器与测试共享同一盲点。
- response window 只保存控制平面状态和 action journal，不复制领域资源真相；这种模式可复用于合约响应、审计确认和其他短时决策窗。

### stale evidence

- 任何旧测试若把“无 counter holder 时不开窗口”视为成功，现在均已陈旧；正确结果是状态机生成 `no_eligible_responder`。
- 旧 Contract response/save 证据只能证明 v0.5 legacy owner 行为，不能证明 v0.6 atomic interaction lifecycle。
- reference owner 的成功 Bench 只达到 runtime 级骨架证据，不得写成 real main path/production 接线完成。
- 若未来真实 owner 补齐 rollback/finalize，当前“production fail-closed”正向断言将成为陈旧证据；应替换为真实 owner lifecycle/integration oracle，而不是保留人为缺口。

### next dependency

- Direct-player/Contract/Intel/Counter owners：提供版本化 `anonymous_interaction_runtime_capabilities_v06(domain)`，以及 snapshot/prepare/commit/rollback/finalize/checkpoint 六个绑定 API；必须有 revision、exact-once、save-load 和 viewer-safe snapshot 证据。
- CardFlow owner：确认一次 reservation 可同时锁 actor 与所有 target player，且 effect receipt 绑定可原样传给本 router；不得创建第二个 transaction service。
- Save owner：为 CounterResponseWindow save section 与 router inflight gate 提供单一 v0.6 checkpoint 聚合接口。
- Coordinator/Queue owner：从 catalog/Profile 传入权威 `counter_window_seconds`，先完成 response window 决议，再决定是否提交 direct-player effect。

## Cross-owner interface requests

### IR-SS06-08-01：真实互动 owner 原子生命周期

- observed fact/API：`ContractRuntimeController`、`IntelDossierPublicSnapshotService`、`CardInventoryRuntimeService`、`PlayerHandInteractionRuntimeService` 没有同时暴露绑定的 prepare/commit/rollback/finalize/revision/exact-once API。
- severity/failure mode：高；若 CardFlow state commit 失败，已执行的偷牌、弃牌、签约或情报 mutation 无法被权威补偿。
- responsible owner：各真实 Contract/Intel/HandInteraction owner 的维护线程。
- required interface/invariant：实现上述 `anonymous_interaction_*_v06` 生命周期，并保证相同 transaction replay 不重复 mutation；rollback/finalize 必须显式返回成功布尔值。
- evidence：owner capability test 6/6 PASS，缺能力时 owner call count=0；合同 capability matrix。
- ownership statement：Agent C 不会编辑这些 owner 文件。

### IR-SS06-08-02：CardFlow 跨玩家 reservation

- observed fact/API：frozen CardFlow contract 要求互动牌一次锁 actor/target，但当前 Agent C 未接生产 state port 验证真实组合。
- severity/failure mode：高；分别锁定会产生目标 revision race 或部分资源提交。
- responsible owner：CardFlow production state port/Coordinator 维护线程。
- required interface/invariant：一次 reservation 原子绑定 actor 与全部 target revisions，并在 effect commit 失败/补偿失败时保留结构化 machine receipt。
- evidence：`docs/card_flow_transaction_v06_contract.md` 与 Agent C binding/exact-once focused tests。
- ownership statement：Agent C 不会编辑 CardFlow、production adapter 或 Coordinator 文件。

### IR-SS06-08-03：统一 checkpoint 聚合

- observed fact/API：CounterResponseWindow 可独立 save/load；router 在 rollback/finalize 未完成时会 `can_checkpoint=false`，但尚未进入全局 save envelope。
- severity/failure mode：高；全局保存若忽略其中一个 gate，会丢窗口或留下无法解释的 committed effect。
- responsible owner：v0.6 Save/Coordinator 维护线程。
- required interface/invariant：全局 checkpoint 必须同时聚合 CardFlow reservation、interaction router 与 response window；open window 保存恢复，未完成 effect association 则明确拒绝。
- evidence：window save/load focused test、router checkpoint focused test、Godot MCP Bench clean pass。
- ownership statement：Agent C 不会编辑 Save 或 Coordinator 文件。
