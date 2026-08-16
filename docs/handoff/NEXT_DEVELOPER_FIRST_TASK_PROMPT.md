# 下一开发者首任务 Prompt

```text
你是《Space Syndicate / 太空辛迪加》的主开发 Agent。

TASK_ID=PR90_RELEASE_FULL_HEAD_GATE1_REUSE_OPTIONAL_MANIFEST_CONTRACT_REPAIR
EXECUTION_MODE=ONE_POST_REPAIR_RUNNER_ONLY_REVISION_PREFLIGHT_THEN_REQUEST_EXPLICIT_FULL_ATTEMPT_AUTHORIZATION

产品身份：
HEAD_SHA=1e948a15e17faffe648722fd596fac01a4525426
TREE_SHA=8508df4e900a73c058566f00fc556ec1d11e08ca
CI_RUN_ID=31956611702
CI_STATUS=SUCCESS
PR_NUMBER=90
PR_STATE=OPEN_DRAFT

历史冻结：
OLD_HEAD_SHA=6d4d52dfbc8001c919ac569dcab2e3b53f968d34
OLD_RELEASE_GATE_2_TO_15_PASS_COUNT=14
OLD_RELEASE_GATE_16_RESULT=PRODUCT_FAIL
OLD_RELEASE_GATE_16_RAW_SHA256=a72f48f06175286e38c5d82a6d4c08f15ee53e3eec7a1a91b8a63e9db7268b9b
PRODUCT_REPAIR_CYCLE_COUNT=1
PRODUCT_REPAIR_COMMIT=1e948a15e17faffe648722fd596fac01a4525426

当前 pre-product blocker：
REVISION_002_WORKER_SHA256=dbb27a69d4c94d27f437d4dd12b4910f4ff363c3cfa9139539d2c6341415259d
RELEASE_RUN_PLAN_DRY_RUN=6/6_PASS_NO_GODOT
FIRST_FAILURE_CLASS=FULL_SUITE_MANIFEST_REQUIRES_UNAVAILABLE_SAME_HEAD_GATE1_REUSE_ATTESTATION
NEW_HEAD_FORMAL_EXECUTION_COUNT=0
NEW_HEAD_GODOT_STARTED=false
BLOCKER_EVIDENCE_SHA256=ba70bec044b245338f94c6efd5eb04664ee8adc3708cf393713a56c95339b7df
EXISTING_RUNNER_EXHAUSTION_AUDIT_SHA256=17500b45a0c5362fe425d2666cebd68595c947f462bdb23a47ce39b7df
EXISTING_LEGAL_NEW_HEAD_FULL_PLAN_ENTRY=false
SEALED_WORKER_CANDIDATE_INSTANCE_COUNT=6
UNIQUE_WORKER_CANDIDATE_SHA_COUNT=5

目标：
1. 不修改、不重跑、不覆盖任何历史 Attempt；不补写历史 Receipt/Row/Summary。
2. 本 Prompt 只授权一个独立、post-repair Runner Tooling Revision；产品代码、测试、Canonical Gate Manifest、规则和新 Head不得改变。
   现有密封入口已穷尽审计；不得改用会回退 plan-bound accounting 或 Product/Evidence 解耦合同的旧 full-range Worker。
3. 保留 Revision 002 的 ReleaseRunPlan、first-product-process accounting、Raw Product Authority、Evidence Projector 和 projection replay 合同。
4. 将 Gate 1 reuse 改为由计划决定：计划包含 Gate 1 时，Manifest 必须拒绝 reuse 输入，Aggregate 只消费 79 个新 Formal Authority/Receipt；计划不含 Gate 1 时，必须要求真实同 Head/Tree reuse Attestation。
5. 不允许 null/空路径/假 Attestation 作为兼容填充值；CI 日志不能替代 Raw Result。
6. 相同 Worker 无 Godot Dry Run 至少覆盖 1—79、2—79、3—79、60—79、singleton、非连续计划，并加入 reuse required/forbidden 的正负例。
7. 预检必须证明 AST/Closure/命令绑定/Result Projection/Aggregate 均绿，Godot、Worker、7576、7586 为 0；新 Head Canonical Import 仍为 0。
8. 预检全绿后停止并向用户请求一次完整 Gate 1—79 正式 Attempt 授权；本 Prompt 不授权产品 Godot 进程。
9. 不实施 V0.7.6，不创建产品 Continuation，不更换 MCP。

必须解释：为什么旧 Head Gate 16 是产品失败；为什么新 Head 修复/CI成立但不等于 79/79；为什么 full plan 不能要求 Gate 1 reuse；为什么 CI 日志不能生成 Raw Result Attestation；下一次正式执行需要什么新授权。

Token 预算建议：Runner/Preflight 250k；Handoff 保留 100k；不得做无边界研究。
```
