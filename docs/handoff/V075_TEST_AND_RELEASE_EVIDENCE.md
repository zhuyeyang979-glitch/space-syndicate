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
| Exact-SHA MCP | PRODUCT_FAIL | Block 8：Presentation receipt identity collision 2（要求 0） |
| MCP Role/Editor/Runtime | STARTED_AND_CLEAN_STOPPED | 163/163 scripts，1,525/1,525 project scripts，13/13 scenes，19/19 resources |
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
- Product MCP Primary Failure SHA-256：`c3797454189eb95493d6da6eae02e928982ff797c855f1dc747b9f5948ff7b57`
- Product MCP Final Failure SHA-256：`ce78276e349026609f843f695018982f3acdf8226a129a589ead101283891dc1`
- Terminal Acceptance State Raw SHA-256：`8385035080840c608adbd2ba008159cf00c0d88b754748634933117c5d86ff85`

## Review B 结论

怪兽部署/刷新/升级/替换、自治路径/饥饿回退/践踏、私密技能、军队地区/怪兽攻击、撤离、DBG discard/reshuffle、设施损伤 typed bridge、AI、资产预留/结算和 exact-once 均同时有正式 Gate 与静态 Owner 审查支持。

设施损伤在克隆的 batch/bridge/processed/witness 状态上完成全部 intent，再验证三账本一致性，最后一次提交；军队卡与资产由统一 Action/Asset/DBG Owner 结算并受动作前 checkpoint 保护；怪兽自治输入、目标、路径和呈现顺序显式稳定；public projection 与 telemetry fail-closed 拒绝私密身份。没有发现 P0/P1。

## Exact-SHA MCP 当前首失败

旧 Block 3 UID Authority 失败保留为历史，后续仓库外 adapted Runner 已以正确 Authority 002 完成预检。本次唯一产品 MCP 因而真实启动。

真实 UI 对局为 4 人、1 Human + 3 AI，并自然进入 `settled`、FinalSettlement=1。Combat action=9、public receipt=12、presentation applied=12；所有运行时、隐私、invalid、nonfinite、duplicate effect/settlement 与 Owner integrity 指标均通过。唯一硬门失败是 `combat_presentation.collision_receipt_count=2`，表示同一 receipt ID 对应不同规范 fingerprint。

Failure Finalizer cleanup GREEN；当前 Godot/Worker、7576、7586 均为 0，Exact-SHA Clone tracked/untracked delta 为 0。下一任务是 `PR90_RELEASE_EXACT_SHA_MCP_PRESENTATION_RECEIPT_IDENTITY_COLLISION_REPAIR`；同一 Head 不得自动重跑 MCP。
