# START HERE — 下一开发者入口

当前状态：**PR #90 BLOCKED，尚未合并**。最新 Head 为 `1e948a15e17faffe648722fd596fac01a4525426`，Tree 为 `8508df4e900a73c058566f00fc556ec1d11e08ca`，CI Run `31956611702` SUCCESS。

先读：

1. `docs/handoff/SPACE_SYNDICATE_DEVELOPER_HANDOFF_ZH.md`
2. `docs/handoff/V075_TEST_AND_RELEASE_EVIDENCE.md`
3. `docs/handoff/NEXT_DEVELOPER_FIRST_TASK_PROMPT.md`

历史产品结果：旧 Head `6d4d52df...` 的 Release Continuation 002 已真实完成 Gate 2—15（14/14 PASS），Gate 16 `v075_combat_submission_rollback_test.gd` 产品失败并停止。唯一允许的产品修复已提交为 `1e948a15`：真实 Combat Owner 保持 typed preview/validate/commit 路径，只有最小必需合同 Owner 回退到既有 `prebind_monster_card_action` / `build_military_lock`。Gate 15、16、60 定向验证和新 Head CI 均 PASS。

原 pre-product blocker 已在一个明确授权的独立 Tooling Revision 中修复。Gate 1 来源合同 V2 现在由 ReleaseRunPlan 决定：完整计划使用 `FORMAL_IN_PLAN`，Manifest 禁止任何 reuse 字段，Aggregate 接受 79 个当前正式 Result/Receipt；排除 Gate 1 的计划使用 `FROZEN_REUSE`，必须提供真实同 Head/Tree Attestation。

最终 Preflight Attempt 003 为 PASS：六类相同 Worker Dry Run 6/6、Manifest 负例 8/8、Aggregate 负例 4/4、真实冻结 Result 投影 PASS、full-formal Aggregate fixture 为 79 Receipt/0 reuse、旧复用模式为 78 Receipt/1 reuse。Worker SHA `675f5ad470fb26bc377731e1ba9e7380c9852d33b4200fdca0c72ac6f9a5d8bd`，Preflight Report SHA `38c434c83247180afe4051ea15e53f52ddccae4857473ae257ae852036f278ae`。前两个 Preflight 尝试是 append-only Tooling 失败，均未启动 Godot。

正式 `pr90-repaired-head-release-full-001 / release-full-attempt-001` 已获得授权并且只执行了一次。Gate 1 Godot PID `26632` 成功创建，所以 `execution-start.json` 记录执行次数 1、授权消耗 1、产品 Attempt 已消费。Gate 1 在 0.75 秒后退出 1；Raw Result SHA 为 `fc7fea93e7e097892959b25493f51d7dd12239c3885880476217c60750f36736`，含 1,158 个脚本解析错误，首条为 `MenuLifecycleApplicationFlowController` 类型不可见。

这不是已证明的 PR #90 产品回归。当前 Acceptance Clone 完全没有 `.godot` 目录或 `global_script_class_cache.cfg`，而这些报错引用的 class_name 声明都存在于 exact Head 源码。Formal Manifest 只引用旧 Head 的 Canonical Import Evidence，当前 Head Clone 没有可用 Import 缓存；同时 Raw Result 把唯一 `diagnostics` 序列化为对象而不是数组，Normalizer 因 `product_executor_diagnostics_wrong_type` fail closed。正式 Summary 因此为 `RUNNER_BLOCKED`，产品 completed/pass/fail 均为 0，Gate 2—79 未启动。不得把这一现场重分类为产品失败，也不得重跑或补写本 Attempt。

不得做：不得修改/重跑 Formal Attempt 001；不得补写缺失的 Receipt/Row；不得把环境诱发的 Raw failure 冒充产品回归；不得自动开始新 Attempt；不得再改产品、测试或 Gate Manifest；不得做 V0.7.6。

第一任务：执行 `PR90_RELEASE_HEAD_BOUND_IMPORT_CACHE_AND_RAW_DIAGNOSTICS_CARDINALITY_REPAIR`。只允许在新的 append-only Tooling Preflight 中修复“当前 Head Import Evidence/Cache 必须真实可用”和“Raw diagnostics 必须稳定为 JSON array”的合同，并用没有 `.godot` 缓存的 exact-sha disposable clone 做无产品 Attempt 的负例/正例验证。它不授权新的 Gate 1—79 产品 Attempt；修复和密封完成后必须再次请求明确授权。

状态标签：V0.7.5 规则与代码为 **LIVE**；Detached checkpoint 为 **TEST_ONLY**；V0.7.6 为 **PLANNED_NOT_IMPLEMENTED**。

后续方向已排队但未启动：分层 Godot 工作流/MCP 效率试验与服务器权威确定性战斗 POC。`MCP_PILOT_STARTED=false`，`OPEN_SOURCE_PILOT_STARTED=false`，不得让这些方向绕过或阻塞 PR #90 当前门禁。
