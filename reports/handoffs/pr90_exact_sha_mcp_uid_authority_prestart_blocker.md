# PR #90 Exact-SHA MCP UID Authority Prestart Blocker

PR #90 当前产品 Head `16ba8532b53cc598a422060039aaee49c862057b`、Tree `faa91174fa45fad6254c3a743b8400b7fdf614f7` 已完成正式 Gate 1—79，结果 79/79 PASS。Post-Aggregate Reviews A/B/C 均为 GO，P0=0、P1=0，没有发现真实产品问题。

唯一正式 Exact-SHA MCP Runbook 在 Block 3 fail-closed，首失败为：

`The frozen UID allowlist entry-set hash is invalid.`

失败发生在 MCP Role、Editor 和产品 Runtime 启动之前。它不推翻 79/79，也不是产品失败。

失败输入 Authority 001 有 215 个 UID 条目，文件 SHA-256 为 `468be020c0c88d1ee1f58c7d5ce14a80c218d252bdf1f0876a14b53cdb5e560c`。文件声明 entry-set SHA 为 `e744234619d31a4080f37683f189451da0ab052836454370342a4e20cc2080fb`；按 Runbook 使用 exact canonical row、Ordinal 排序和 UTF-8 重建后为 `ec22a3f71805a64dae8fae60a54f8bf327185dcd08f2b68ca8633a930f65f805`，两者不相等。

Authority 002 随后已存在，文件 SHA-256 为 `02236b076bc2a14ce3f1d55ae256be91526e11afeb6453af5815a7844d653cd1`，并声明正确的 `ec22...f805`。它没有被失败的 Runbook 使用，所以不能补写旧运行或自动重试。

Failure Finalizer 同时记录 57 个 ignored `.import` sidecar 不属于当时可用的 closed-set authority。虽然 Clone 最终 `git status` 干净，下一任务仍必须解释这些缓存文件的来源和安全处理方式。

冻结证据：

- Primary Failure SHA-256：`a0fd0fb947c8729279c4df3168d5b770a1b03ff1febb137bd07b1e5db173e8df`
- Final Failure SHA-256：`f0a57b465b5f81b62eeb5949c2330fa564204b0af1fa007edde32715cb5e6e5f`
- Transient Observation SHA-256：`55a159a917e5adae85a83b48ae92a2045a8a551d051acbd3494a2a062846d7ff`

失败后 Godot 进程、7576、7586 均为 0；Exact-SHA Clone tracked/untracked delta 为 0。Viewport、Headless、2,000、PR merge 和 V0.7.6 均未启动。

下一任务：`PR90_RELEASE_EXACT_SHA_MCP_UID_ALLOWLIST_AUTHORITY_SELECTION_CONTINUATION`。该任务只授权 prestart authority 审计；新的 Exact-SHA MCP 正式运行仍需用户明确授权。
