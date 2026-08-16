# START HERE — 下一开发者入口

当前状态：**PR #90 BLOCKED，尚未合并**。最新 Head 为 `1e948a15e17faffe648722fd596fac01a4525426`，Tree 为 `8508df4e900a73c058566f00fc556ec1d11e08ca`，CI Run `31956611702` SUCCESS。

先读：

1. `docs/handoff/SPACE_SYNDICATE_DEVELOPER_HANDOFF_ZH.md`
2. `docs/handoff/V075_TEST_AND_RELEASE_EVIDENCE.md`
3. `docs/handoff/NEXT_DEVELOPER_FIRST_TASK_PROMPT.md`

历史产品结果：旧 Head `6d4d52df...` 的 Release Continuation 002 已真实完成 Gate 2—15（14/14 PASS），Gate 16 `v075_combat_submission_rollback_test.gd` 产品失败并停止。唯一允许的产品修复已提交为 `1e948a15`：真实 Combat Owner 保持 typed preview/validate/commit 路径，只有最小必需合同 Owner 回退到既有 `prebind_monster_card_action` / `build_military_lock`。Gate 15、16、60 定向验证和新 Head CI 均 PASS。

原 pre-product blocker 已在一个明确授权的独立 Tooling Revision 中修复。Gate 1 来源合同 V2 现在由 ReleaseRunPlan 决定：完整计划使用 `FORMAL_IN_PLAN`，Manifest 禁止任何 reuse 字段，Aggregate 接受 79 个当前正式 Result/Receipt；排除 Gate 1 的计划使用 `FROZEN_REUSE`，必须提供真实同 Head/Tree Attestation。

最终 Preflight Attempt 003 为 PASS：六类相同 Worker Dry Run 6/6、Manifest 负例 8/8、Aggregate 负例 4/4、真实冻结 Result 投影 PASS、full-formal Aggregate fixture 为 79 Receipt/0 reuse、旧复用模式为 78 Receipt/1 reuse。Worker SHA `675f5ad470fb26bc377731e1ba9e7380c9852d33b4200fdca0c72ac6f9a5d8bd`，Preflight Report SHA `38c434c83247180afe4051ea15e53f52ddccae4857473ae257ae852036f278ae`。前两个 Preflight 尝试是 append-only Tooling 失败，均未启动 Godot。

不得做：不得修改/重跑旧 Formal Attempt；不得补写旧 Receipt/Row/Summary；不得把 CI 日志伪装成 Gate 1 Raw Result；不得自动开始新 Head Attempt；不得再改产品、测试或 Gate Manifest；不得做 V0.7.6。

第一任务：明确授权 `PR90_REPAIRED_HEAD_FULL_GATE1_79_FORMAL_ATTEMPT_001`。只允许使用已封存的 Plan、Manifest、Worker、Projector 和 Launcher，完整执行 Gate 1—79 一次；当前 Handoff 和 Preflight 本身不授权产品 Godot 进程。

状态标签：V0.7.5 规则与代码为 **LIVE**；Detached checkpoint 为 **TEST_ONLY**；V0.7.6 为 **PLANNED_NOT_IMPLEMENTED**。

后续方向已排队但未启动：分层 Godot 工作流/MCP 效率试验与服务器权威确定性战斗 POC。`MCP_PILOT_STARTED=false`，`OPEN_SOURCE_PILOT_STARTED=false`，不得让这些方向绕过或阻塞 PR #90 当前门禁。
