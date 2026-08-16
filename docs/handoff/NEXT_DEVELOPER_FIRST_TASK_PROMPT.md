# 下一开发者首任务 Prompt

```text
你是《Space Syndicate / 太空辛迪加》的主开发 Agent。

TASK_ID=PR90_RELEASE_RUNNER_FULL_RANGE_FIRST_GATE_ACCOUNTING_TRIGGER_REPAIR
EXECUTION_MODE=RUNNER_ONLY_PREFLIGHT_THEN_REQUEST_EXPLICIT_NEW_ATTEMPT_AUTHORIZATION

产品身份：
HEAD_SHA=6d4d52dfbc8001c919ac569dcab2e3b53f968d34
TREE_SHA=95c899ceb552a9214edc4ab7e6076ea6e6c7c02c
CI_RUN_ID=31894893974
CI_STATUS=SUCCESS
PR_NUMBER=90
PR_STATE=OPEN_DRAFT

冻结 Attempt：
RUN_ID=pr90-new-head-release-focused-001
DISPOSITION=GATE1_PRODUCT_PASS_THEN_RUNNER_ACCOUNTING_FIRST_GATE_TRIGGER_HARDCODED_TO_GATE3
EXECUTION_COUNT=1
AUTHORIZED_COUNT_CONSUMED=1
PRODUCT_FAILURE_ATTESTED=false
GATE1_RAW_RESULT_SHA256=7b7c94847d6678f17f1b0a9b5d79aaecaba970fed02eb82aa45339277c5f8f5f
FORMAL_PAYLOAD_SHA256=98b3b13b7c6e4ef9aad4792417634df0640cc6e1484daee65993f4615854ab93

目标：
1. 不修改、不重跑、不覆盖冻结 Attempt；不补写 execution-start、Gate 1 Receipt/Row/Summary。
2. 只修 Runner：把 currentGate == 3 与 FirstGateId 3 改为来自已验证 Manifest/Plan 的 first planned gate。
3. 建立 FirstPlannedGateAccountingContractV1；证明 1—79、3—79、60—79、singleton 合法计划只写一次 accounting authority。
4. 保持 StrictMode、Start Witness Wire、Result Cardinality V3、Product Executor/Evidence Projector 解耦。
5. 无 Godot完成 AST/Closure/Self-Test/真实命令绑定/Result Projection Dry Run；产品文件、测试、Canonical Manifest、规则数值 diff 必须为 0。
6. 预检全绿后停止并向用户请求一次新的正式产品 Attempt 授权；本 Prompt 不授权自动运行 Gate。
7. 不实施 V0.7.6，不创建 Continuation，不更换 MCP，不重新 Import。

必须解释：Gate 1 为什么是产品 PASS；为什么 Runner trigger 不能写死具体 Gate；为什么旧 Attempt 不能补写或重跑；下一次正式执行需要什么新授权。

Token 预算建议：Runner/Preflight 250k；Handoff 保留 100k；不得做无边界研究。
```
