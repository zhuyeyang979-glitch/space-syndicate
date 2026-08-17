# PR #90 Exact-SHA MCP Presentation Receipt Collision Blocker

PR #90 当前产品 Head `16ba8532b53cc598a422060039aaee49c862057b`、Tree `faa91174fa45fad6254c3a743b8400b7fdf614f7` 的唯一完整 Formal Run 仍是 79/79 PASS；Post-Aggregate Reviews A/B/C 均为 GO，P0=0、P1=0。

旧的 UID Authority prestart 失败没有启动 Godot。它随后通过仓库外 Runner-only 适配和正确的 215 项 Authority 002 完成预检，本次 Exact-SHA MCP 因而真实启动了 Role A、Editor 与 `main.tscn` 产品 Runtime。

MCP 已完成：

- changed files：314；
- changed scripts：163/163；
- project script scope：1,525/1,525，错误 0；
- changed scenes：13/13；
- changed resources：19/19。

真实 UI 对局为 4 人（1 Human + 3 AI），自然进入 `settled`，`match_completed=true`，`FinalSettlement=1`。运行时错误、隐私违规、无效动作、非有限数值、重复效果和重复结算全部为 0；Combat effect、Combat receipt 与 Facility effect integrity 均为 GREEN。

首个且唯一的硬门失败是：

`runtime_acceptance_debug.combat_presentation.collision_receipt_count=2`（要求 0）。

Presentation Consumer 的正式语义是：同一 `receipt_id` 已经绑定过一个规范化 receipt fingerprint，随后又收到不同 fingerprint；它正确 fail-closed 并增加 collision 计数。因此这不是 Runner、UID、Import、截图或终局误报，而是自然产品运行时暴露的 Presentation Receipt identity collision。

冻结证据：

- Primary Failure SHA-256：`c3797454189eb95493d6da6eae02e928982ff797c855f1dc747b9f5948ff7b57`
- Final Failure SHA-256：`ce78276e349026609f843f695018982f3acdf8226a129a589ead101283891dc1`
- Terminal Acceptance State Raw SHA-256：`8385035080840c608adbd2ba008159cf00c0d88b754748634933117c5d86ff85`
- Raw MCP Manifest SHA-256：`50b80e02136369227fabc7a1e6138f68885b9ad74f367e2356d0a943a9e4c27a`

Failure Finalizer 已完成安全清理：Godot、Worker、7576、7586 均为 0，Exact Clone tracked/untracked delta 为 0。按首失败规则，Viewport、Headless 3/4/6/8、Product Headless 2,000、PR Ready/Merge 与 V0.7.6 均未启动；不得在同一 Head 自动重跑 MCP。

下一任务：`PR90_RELEASE_EXACT_SHA_MCP_PRESENTATION_RECEIPT_IDENTITY_COLLISION_REPAIR`。
