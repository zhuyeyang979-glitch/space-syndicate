# START HERE — 下一开发者入口

当前状态：**PR #90 仍为 OPEN DRAFT，尚未合并；Formal Gate 已 79/79 PASS，但真实 Exact-SHA MCP 对局发现两个 Presentation receipt identity collision，Release 链已停止。**

权威产品 Head 为 `16ba8532b53cc598a422060039aaee49c862057b`，Tree 为 `faa91174fa45fad6254c3a743b8400b7fdf614f7`。GitHub CI Run `31975708077` SUCCESS；PR #90 为 OPEN DRAFT、MERGEABLE。

先读：

1. `reports/handoffs/pr90_exact_sha_mcp_presentation_receipt_collision_blocker.md`
2. `docs/handoff/V075_TEST_AND_RELEASE_EVIDENCE.md`
3. `docs/handoff/NEXT_DEVELOPER_FIRST_TASK_PROMPT.md`

最新完整 Formal Run 是 `pr90-gate63-repaired-head-release-full-001 / formal-attempt-001`。该运行只执行一次，Gate 1—79 全部来自当前 Head/Tree，79/79 PASS，79 份 Formal Receipt，0 份复用证明，产品失败 0，Runner 失败 0。Summary SHA-256 为 `d041a0b8ccbdcb4585365e25ce16bc753757a8d2e5868685377200cfacd2007b`；Aggregate SHA-256 为 `f046baaa958b7a9a15bbfd8b847200ac3406b28626d4eb7efa8eda1384473b03`。

Post-Aggregate Reviews A/B/C 均为 GO，P0=0、P1=0。Review B 覆盖怪兽、军队、设施损伤、AI、资产、DBG 与 exact-once；静态审查当时没有发现 P0/P1。

旧 Block 3 UID Authority 失败发生在产品启动前，保留为历史。仓库外 adapted Runner（SHA-256 `729591fe...c5da6b`）随后以 Authority 002（215 项，文件 SHA-256 `02236b...3cd1`）完成完整 ValidateOnly；这没有修改产品 Tree。

新的唯一 Exact-SHA MCP Run `16ba8532b53c-20260817T135931485Z-504c4740` 真实启动 Role A、Editor 和 `main.tscn` Runtime。163/163 变更脚本、1,525/1,525 项目脚本、13/13 场景、19/19 资源全部通过。真实 4 人（1 Human + 3 AI）对局自然 settled，FinalSettlement=1，runtime/hidden/invalid/nonfinite/duplicate effect/duplicate settlement 都为 0；但 `runtime_acceptance_debug.combat_presentation.collision_receipt_count=2`，违反硬零合同。Presentation Consumer 的含义是同一 receipt ID 绑定了不同 fingerprint，因此这是产品 Presentation identity blocker，不是 Runner 误报。

当前现场：Failure Finalizer cleanup GREEN；Godot/Worker 进程 0，7576/7586 监听 0，Exact-SHA Clone tracked/untracked delta 0。Viewport、Headless 3/4/6/8、Product Headless 2,000、PR Ready/Merge、V0.7.6 分支与 POC 均未启动。

下一任务：`PR90_RELEASE_EXACT_SHA_MCP_PRESENTATION_RECEIPT_IDENTITY_COLLISION_REPAIR`。必须冻结本次 MCP 证据，在新产品 Head 上修复 receipt ID/fingerprint 一致性并重新走新 Head Release；不得在当前 Head 自动重跑 MCP。
