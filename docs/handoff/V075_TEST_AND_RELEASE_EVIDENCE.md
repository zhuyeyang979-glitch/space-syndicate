# V0.7.5 测试与 Release Evidence

## 当前身份

- PR #90 Head：`16ba8532b53cc598a422060039aaee49c862057b`
- Tree：`faa91174fa45fad6254c3a743b8400b7fdf614f7`
- CI：Run `31975708077`，SUCCESS
- PR：OPEN DRAFT，MERGEABLE

## 当前正式结果

| 项目 | 结果 | 说明 |
|---|---|---|
| Formal full 1—79 | PASS | `pr90-gate63-repaired-head-release-full-001 / formal-attempt-001`；execution 1 |
| Gate 1—79 | 79/79 PASS | 当前 exact Head/Tree；79 个 current-run Result 与 79 个 Formal Receipt |
| Product/Runner failure | 0/0 | `product_first_failure=null`，`runner_first_failure=null` |
| Aggregate | 79/79 PASS | reuse attestation 0；unique gate 79 |
| Reviews A/B/C | GO/GO/GO | P0=0，P1=0；未发现真实产品问题 |
| Exact-SHA MCP | BLOCKED_PRESTART | Block 3：Authority 001 的 UID entry-set 声明哈希与重建值不一致 |
| MCP Role/Editor/Runtime | NOT_STARTED | 失败发生在启动前；不是产品 Runtime 失败 |
| Viewport | NOT_RUN | Exact-SHA MCP 未通过后正确停止 |
| Headless 3/4/6/8 | NOT_RUN | 未授权越过首失败 |
| Product Headless 2,000 | NOT_RUN | 未授权越过首失败 |
| PR merge/tag | NOT_RUN | Release 链未全绿 |
| V0.7.6 POC | NOT_STARTED | PR #90 尚未合并 |

## 冻结哈希

- Formal Summary SHA-256：`d041a0b8ccbdcb4585365e25ce16bc753757a8d2e5868685377200cfacd2007b`
- Aggregate 79 SHA-256：`f046baaa958b7a9a15bbfd8b847200ac3406b28626d4eb7efa8eda1384473b03`
- Exact-SHA MCP Primary Failure SHA-256：`a0fd0fb947c8729279c4df3168d5b770a1b03ff1febb137bd07b1e5db173e8df`
- Exact-SHA MCP Final Failure SHA-256：`f0a57b465b5f81b62eeb5949c2330fa564204b0af1fa007edde32715cb5e6e5f`
- Transient Observation SHA-256：`55a159a917e5adae85a83b48ae92a2045a8a551d051acbd3494a2a062846d7ff`
- Authority 001 File SHA-256：`468be020c0c88d1ee1f58c7d5ce14a80c218d252bdf1f0876a14b53cdb5e560c`
- Authority 002 File SHA-256：`02236b076bc2a14ce3f1d55ae256be91526e11afeb6453af5815a7844d653cd1`

## Review B 结论

怪兽部署/刷新/升级/替换、自治路径/饥饿回退/践踏、私密技能、军队地区/怪兽攻击、撤离、DBG discard/reshuffle、设施损伤 typed bridge、AI、资产预留/结算和 exact-once 均同时有正式 Gate 与静态 Owner 审查支持。

设施损伤在克隆的 batch/bridge/processed/witness 状态上完成全部 intent，再验证三账本一致性，最后一次提交；军队卡与资产由统一 Action/Asset/DBG Owner 结算并受动作前 checkpoint 保护；怪兽自治输入、目标、路径和呈现顺序显式稳定；public projection 与 telemetry fail-closed 拒绝私密身份。没有发现 P0/P1。

## Exact-SHA MCP 首失败

Runbook 在 Block 3 读取冻结 UID allowlist 时停止。Authority 001 声明 `uid_entry_set_sha256=e744...80fb`，同一 215 项按 Runbook 的 canonical row、Ordinal 排序和 UTF-8 重建后为 `ec22...f805`。因此 Runbook 正确 fail-closed，没有启动 MCP Role、Editor 或产品 Runtime。

Authority 002 后续文件声明了 `ec22...f805`，但它不属于失败运行的输入，不能用来篡改历史或声称该次运行通过。Failure Finalizer 还记录 57 个 ignored `.import` sidecar 不在当时可用 closed-set authority 中；这要求新的 prestart 审计，不能被 `git status` clean 掩盖。

当前 Godot、7576、7586 均为 0；Exact-SHA Clone tracked/untracked delta 为 0。下一任务是 `PR90_RELEASE_EXACT_SHA_MCP_UID_ALLOWLIST_AUTHORITY_SELECTION_CONTINUATION`，且不包含自动重跑授权。
