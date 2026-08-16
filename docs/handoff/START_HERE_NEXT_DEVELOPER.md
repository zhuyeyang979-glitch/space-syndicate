# START HERE — 下一开发者入口

当前状态：**PR #90 BLOCKED，尚未合并**。最新 Head 为 `1e948a15e17faffe648722fd596fac01a4525426`，Tree 为 `8508df4e900a73c058566f00fc556ec1d11e08ca`，CI Run `31956611702` SUCCESS。

先读：

1. `docs/handoff/SPACE_SYNDICATE_DEVELOPER_HANDOFF_ZH.md`
2. `docs/handoff/V075_TEST_AND_RELEASE_EVIDENCE.md`
3. `docs/handoff/NEXT_DEVELOPER_FIRST_TASK_PROMPT.md`

历史产品结果：旧 Head `6d4d52df...` 的 Release Continuation 002 已真实完成 Gate 2—15（14/14 PASS），Gate 16 `v075_combat_submission_rollback_test.gd` 产品失败并停止。唯一允许的产品修复已提交为 `1e948a15`：真实 Combat Owner 保持 typed preview/validate/commit 路径，只有最小必需合同 Owner 回退到既有 `prebind_monster_card_action` / `build_military_lock`。Gate 15、16、60 定向验证和新 Head CI 均 PASS。

当前精确阻塞发生在新 Head 的第一个 Godot 进程之前：已封存 Revision 002 的动态计划 Dry Run 为 6/6 PASS，但其 Manifest Validator 无条件要求 `gate1_reuse_attestation` 且要求 Head/Tree 匹配。新 Head 必须完整新跑 Gate 1—79，不能复用旧 Head Gate 1；CI 没有保存可复用的 Raw `result.json`。不得伪造 Attestation。当前任务只授权了两个 pre-product Tooling Revision，不能擅自创建第三个。

不得做：不得修改/重跑旧 Formal Attempt；不得补写旧 Receipt/Row/Summary；不得把 CI 日志伪装成 Gate 1 Raw Result；不得自动开始新 Head Attempt；不得再改产品、测试或 Gate Manifest；不得做 V0.7.6。

第一任务：取得一次明确的 post-repair Tooling Revision 授权，使 Gate 1 reuse 按计划条件化：计划包含 Gate 1 时禁止 reuse 并聚合 79 个新 Formal Result；计划从 Gate 2 或更后开始时才要求真实匹配的 reuse Attestation。用相同 Worker 无 Godot Dry Run 全链验证后，停止并请求一次完整 1—79 Attempt 授权。

状态标签：V0.7.5 规则与代码为 **LIVE**；Detached checkpoint 为 **TEST_ONLY**；V0.7.6 为 **PLANNED_NOT_IMPLEMENTED**。
