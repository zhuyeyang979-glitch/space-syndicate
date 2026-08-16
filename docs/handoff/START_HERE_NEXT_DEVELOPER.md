# START HERE — 下一开发者入口

当前状态：**PR #90 仍为 OPEN DRAFT，尚未合并；产品 Gate 已 79/79 PASS，但 Release 链在 Exact-SHA MCP 启动前被 Tooling Authority 阻断。**

权威产品 Head 为 `16ba8532b53cc598a422060039aaee49c862057b`，Tree 为 `faa91174fa45fad6254c3a743b8400b7fdf614f7`。GitHub CI Run `31975708077` SUCCESS；PR #90 为 OPEN DRAFT、MERGEABLE。

先读：

1. `reports/handoffs/pr90_exact_sha_mcp_uid_authority_prestart_blocker.md`
2. `docs/handoff/V075_TEST_AND_RELEASE_EVIDENCE.md`
3. `docs/handoff/NEXT_DEVELOPER_FIRST_TASK_PROMPT.md`

最新完整 Formal Run 是 `pr90-gate63-repaired-head-release-full-001 / formal-attempt-001`。该运行只执行一次，Gate 1—79 全部来自当前 Head/Tree，79/79 PASS，79 份 Formal Receipt，0 份复用证明，产品失败 0，Runner 失败 0。Summary SHA-256 为 `d041a0b8ccbdcb4585365e25ce16bc753757a8d2e5868685377200cfacd2007b`；Aggregate SHA-256 为 `f046baaa958b7a9a15bbfd8b847200ac3406b28626d4eb7efa8eda1384473b03`。

Post-Aggregate Reviews A/B/C 均为 GO，P0=0、P1=0。Review B 覆盖怪兽、军队、设施损伤、AI、资产、DBG 与 exact-once；未发现真实产品问题。

唯一正式 Exact-SHA MCP Runbook 在 Block 3 fail-closed，发生在 MCP Role、Editor 和产品 Runtime 启动之前。首失败：`The frozen UID allowlist entry-set hash is invalid.` 使用的 Authority 001 文件 SHA-256 为 `468be020c0c88d1ee1f58c7d5ce14a80c218d252bdf1f0876a14b53cdb5e560c`；其声明 entry-set SHA 为 `e744234619d31a4080f37683f189451da0ab052836454370342a4e20cc2080fb`，按 Runbook 合同重建后为 `ec22a3f71805a64dae8fae60a54f8bf327185dcd08f2b68ca8633a930f65f805`。

Authority 002 随后已存在且声明了正确 entry-set SHA，文件 SHA-256 为 `02236b076bc2a14ce3f1d55ae256be91526e11afeb6453af5815a7844d653cd1`，但它没有被失败的正式 Runbook 使用。不得据此自动重跑。Failure Finalizer 还将 57 个 ignored `.import` 路径标为当前 closed-set authority 未覆盖，必须在任何新授权前完成只读解释和 prestart 审计。

当前现场：Godot 进程 0，7576/7586 监听 0，Exact-SHA Clone tracked/untracked delta 0。Viewport、Headless 3/4/6/8、Product Headless 2,000、PR Ready/Merge、V0.7.6 分支与 POC 均未启动。

下一任务：`PR90_RELEASE_EXACT_SHA_MCP_UID_ALLOWLIST_AUTHORITY_SELECTION_CONTINUATION`。该任务必须先验证 Authority 002 的文件哈希、entry-set 哈希、Head/Tree、来源 Clone 和 215 个 UID 条目；同时证明 57 个 ignored `.import` sidecar 的来源与安全处理方式。未经用户明确授权，不得启动新的 Exact-SHA MCP Runbook。
