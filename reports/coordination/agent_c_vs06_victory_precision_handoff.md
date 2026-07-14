# VS06-C6 Victory Audit Split-Delta Precision Gate

状态：完成。未修改 TomorrowVerticalSlice harness、main、Coordinator、UI 或其他 runtime。

## 修复

`VictoryControlRuntimeController` 现在集中使用 `TIMER_BOUNDARY_EPSILON_SECONDS = 0.000001`（一微秒）：

- qualification 与 audit 共用同一边界判断；
- audit 每次扣时后统一 clamp/normalize，`remaining <= epsilon` 规范化为精确 `0.0`；
- save/load 同样规范化 near-end remaining；
- audit 到达规范化端点后仍必须具备 `post_world_settlement` checkpoint 才能产生 outcome；
- debug snapshot 公开 epsilon，便于运行证据解释。

10 秒 qualification、120 秒 audit、暂停、动态资格公式、比较排名与 checkpoint 规则均未改变。remaining 大于 epsilon 时不会提前 resolved。

## Focused regression

新增 `tests/victory_control_split_delta_precision_test.gd`，覆盖：

- qualification `5 + 5`、audit `119.99 + 0.01` 必须 resolved；
- 单步、分段与 0.1 秒细碎步进产生完全相同的 `public_audit_complete` receipt；
- 尚余两微秒时保持 audit，不提前结算；
- outcome exact-once，resolved 后重复 advance 不改变 receipt/sequence；
- 0.01 秒 near-end save/load，以及 epsilon 端点等待 checkpoint 后的 zero-delta 恢复；
- 缺 checkpoint 时保持 audit；负 delta 仍拒绝；menu pause 不消耗 audit 时间。

Godot 4.7 stable、隔离 APPDATA：

- 修复前：57 checks，10 failures；首个错误为 `audit 119.99+0.01 resolves at the same 120-second boundary`。
- 修复后：57/57 PASS，failures=0。

仓库没有独立的 VictoryControl test；只有会写 user evidence/截图的 VictoryControl Bench，因此按任务边界未运行。未运行完整 slice、full smoke、MCP 或有头场景。

## Stage 8 静态结论

若 Stage 7 恢复非空 receipt，现有 Stage 8 应自然继续，无需改 main/UI：

1. 完整生产路径 `GameRuntimeCoordinator.advance_victory_control` 已把 controller result 的 receipt 交给 `_apply_victory_outcome_receipt`。
2. 该入口依次调用 session `finish_session(receipt)` 与 `VictoryControlWorldBridge.apply_outcome_receipt(receipt)`。
3. TomorrowVerticalSlice 的 Stage 7 因直接调用 controller 而绕过 Coordinator；Stage 8 已显式用同一 `_apply_victory_outcome_receipt` 接入，并检查重复应用后仍只有一个 settlement/recap board。

因此本次 Stage 8 失败是 Stage 7 receipt 为空的下游结果；修复后是否真实显示 settlement/recap 仍由协调线程的统一 slice 验证，本轮不宣称有头 UI 已通过。

## 修改文件

- `scripts/runtime/victory_control_runtime_controller.gd`
- `tests/victory_control_split_delta_precision_test.gd`
- `reports/coordination/agent_c_vs06_victory_precision_handoff.md`

## Lessons for other agents

- **invariant**：计时端点、checkpoint 与 outcome exact-once 是三个独立门，epsilon 只能解决端点表示。
- **failed approach**：对重复浮点减法结果使用严格 `remaining > 0.0`，单次 120 秒会绿而 119.99+0.01 会假停留。
- **stable API**：`advance_world_effective`、`outcome_receipt`、`to_save_data`、`apply_save_data` 保持不变。
- **test oracle**：同总时长的单步/分步/细碎步进 receipt 必须全等，且大于 epsilon 的 remainder 必须仍为 audit。
- **integration trap**：直接调用 controller 不会经过 Coordinator 自动 receipt forwarding；独立 harness 必须显式应用 receipt。
- **reusable pattern**：用一个具名 epsilon 和一个 normalize helper统一运行时、snapshot 与 save/load 端点。
- **stale evidence**：只测单次 `advance(120.0)` 的旧 smoke 不能证明分段等价性。
- **next dependency**：协调线程重跑完整 slice，确认 Stage 7 outcome 恢复后 Stage 8 settlement/recap 可见且 exact-once。
