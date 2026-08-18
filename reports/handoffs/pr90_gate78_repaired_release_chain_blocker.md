# PR #90 Gate 78 Repaired Release Chain Blocker

PR #90 当前 Head 为 `4d5b173fccae7c6bb1004488e4d561c11714210a`，Tree 为 `365a2a0d8b09162cc7338a460935e8b881cac770`。CI Run `32055074222` 为 SUCCESS 且 SHA 精确匹配；PR 仍为 OPEN DRAFT、MERGEABLE、CLEAN。

Gate 78 已证明是 `STALE_ORACLE_OLD_RESOLUTION_BUS_CONNECTION_COUNT`，不是产品 cleanup 缺陷。修复只修改 1 个测试支持 GDScript、2 个架构合同文件和 1 个补丁 manifest，生产运行时代码修改为 0。Gate 78 聚焦测试 `33/33 PASS`，Gate 78—79 开发预演 `2/2 PASS`。

当前 Presentation Observer Topology 是三条 composition-owned edge：

1. `V075RuntimeOwner.resolution_presented -> CombatTelemetryBridge.consume_public_receipt`
2. `V075RuntimeOwner.combat_presentation_receipt_ready -> V075CombatPresentationConsumer.consume_receipt`
3. `V075CombatPresentationConsumer.presentation_cue_ready -> CombatTelemetryBridge.consume_public_cue`

required/legacy/duplicate 为 `3/0/0`，cleanup 前后 owner、consumer、telemetry 身份和完整 signature set 一致。旧的 `resolution_presented -> V075CombatPresentationConsumer.consume_receipt` 必须继续缺席；把它接回去会绕过 `PresentationReceiptIdentityV2` 并可能重新造成重复展示投递与 receipt identity collision。

旧 Formal Attempt `pr90-presentation-identity-repaired-release-full-001 / formal-attempt-001` 保持永久冻结：Gate 1—77 PASS、Gate 78 FAIL、Gate 79 不存在，修改/重跑/覆盖计数均为 0。

修复 Head 的唯一新 Formal Attempt `pr90-gate78-repaired-head-release-full-001 / formal-attempt-001` 完整通过 Gate 1—79：started/completed/pass/fail=`79/79/79/0`，Aggregate=`79/79`，execution=`1`，automatic retry=`0`。三路 Post-Aggregate Review 均为 GO，P0=0、P1=0。

唯一 Exact-SHA MCP Runbook 随后真实启动并完成了大部分验证：

- changed scripts `167/167`；project scripts `1,529/1,529`，错误 0；
- changed scenes `13/13`；changed resources `28/28`；
- 真实 1 Human + 3 AI 对局自然进入 `settled`，`match_completed=true`；
- `FinalSettlement=1`，Presentation collision/duplicate、duplicate effect、runtime error、hidden-info violation、invalid action、nonfinite 和 duplicate settlement 全部为 0；
- MCP 读取的 Topology 合同为 required/legacy/duplicate=`3/0/0`。

但是 Exact-SHA MCP 的正式结果必须为 FAIL。Block 8 的最终 `get_runtime_events` 返回恰好 100 条事件，全部是成功 command，`ready` 事件为 0。Runbook 明确拒绝 `count >= 100`，因为早期 ready/command 可能已被固定窗口截断，无法证明最终事件证据完整。首失败为：

`Final runtime event evidence is incomplete or contains a failed command/runtime event.`

绿色产品末态不能覆盖这条 fail-closed 证据失败，也不能把 `EXACT_SHA_MCP_STATUS` 改写为 PASS。本任务不允许自动重跑，实际 MCP execution=`1`、retry=`0`。

Failure Finalizer 已安全退出 play 并停止 Role A：Godot、7576、7586 均为 0；但 cleanup 只能 observation-only。Exact clone 保留 57 个 tracked `.import` 漂移和 219 个 allowlisted `.uid`，`import_state=INVALID_PARTIAL_UNKNOWN_OR_TAMPERED`，因此不能声称 clone 已恢复干净。

按 Exact-SHA MCP 首失败规则，Viewport 与 Headless 3/4/6/8 未启动。Product Headless 2,000 另有独立的可证明阻断：模拟驱动明确设置 `_simulation_presentation_observer_disabled=true` 并省略 Presentation node；现有 simulation metrics 不提供 Presentation collision 或 observer duplicate-edge 计数；authority 工具只有 shard planning，没有 dispatcher。因此当前 Head 无法诚实证明 2,000 局要求的两项 Presentation 指标：

```text
PRODUCT_HEADLESS_2000_STATUS=BLOCKED_MISSING_PRESENTATION_OBSERVABILITY
PRODUCT_HEADLESS_PRESENTATION_COLLISION_COUNT=NOT_PROVABLE
PRODUCT_HEADLESS_OBSERVER_DUPLICATE_EDGE_COUNT=NOT_PROVABLE
DISPATCHER_AVAILABLE=false
```

PR #90 不得转 Ready 或合并；V0.7.6 分支和 Detached POC A 均不得创建。当前状态不是 Gate 78 修复回退，也不是新产品 runtime defect；它是 Post-Aggregate release evidence blocker，加上尚未解决的 Product 2,000 observability blocker。

下一任务：`PR90_RELEASE_EXACT_SHA_MCP_RUNTIME_EVENT_WINDOW_AND_IMPORT_FINALIZER_CONTINUATION`。

该任务必须保持两个 Formal Attempt 与本次 Exact-SHA MCP 证据只读；不得补写或把失败改成 PASS。新的 MCP 正式运行需要新的明确授权，并应先解决 runtime event pagination/capacity 与 clean-clone import finalizer authority。其后再进入 `PR90_PRODUCT_HEADLESS_2000_PRESENTATION_OBSERVABILITY_HARNESS`，以新授权的 harness Head 提供 Presentation collision/duplicate-edge 观测和真实 dispatcher。
