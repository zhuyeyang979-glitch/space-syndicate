# 下一开发者首任务 Prompt

```text
你是《Space Syndicate / 太空辛迪加》的主开发 Agent。

TASK_ID=PR90_REPAIRED_HEAD_FULL_GATE1_79_FORMAL_ATTEMPT_001
EXECUTION_MODE=USE_SEALED_GATE1_SOURCE_CONTRACT_V2_RUN_FULL_GATE1_79_ONCE_THEN_CONDITIONAL_RELEASE_CHAIN

产品身份：
PR_NUMBER=90
PRODUCT_BRANCH=codex/v075-monster-military-combat-bd0af5c
HEAD_SHA=1e948a15e17faffe648722fd596fac01a4525426
TREE_SHA=8508df4e900a73c058566f00fc556ec1d11e08ca
CI_RUN_ID=31956611702
CI_STATUS=SUCCESS
PR_STATE=OPEN_DRAFT
PR_MERGEABLE=true

历史产品事实：
OLD_HEAD_SHA=6d4d52dfbc8001c919ac569dcab2e3b53f968d34
OLD_RELEASE_GATE_2_TO_15=14/14_PASS
OLD_RELEASE_GATE_16=PRODUCT_FAIL
OLD_RELEASE_GATE_16_RAW_SHA256=a72f48f06175286e38c5d82a6d4c08f15ee53e3eec7a1a91b8a63e9db7268b9b
PRODUCT_REPAIR_CYCLE_COUNT=1
PRODUCT_REPAIR_COMMIT=1e948a15e17faffe648722fd596fac01a4525426
POST_REPAIR_TARGETED_GATE_15_16_60=3/3_PASS

已完成的 Runner-only 修复：
GATE1_SOURCE_CONTRACT_VERSION=V2
TOOLING_REVISION_COUNT=1
TOOLING_REVISION_ID=release-full-head-gate1-reuse-optional-tooling-revision-001
FINAL_PREFLIGHT_ATTEMPT=3
FINAL_PREFLIGHT_STATUS=PASS
FINAL_PREFLIGHT_REPORT_SHA256=38c434c83247180afe4051ea15e53f52ddccae4857473ae257ae852036f278ae
PREFLIGHT_COMPLETE_SEAL_REQUIRED=true

前两个 Preflight Attempt 是 append-only Tooling 失败：
- Attempt 1：PowerShell if positional invocation；Worker/Godot 0。
- Attempt 2：Where-Object operator tokenization；六类 Dry Run 已完成，Godot 0。
- 两者均未消耗产品 Attempt，且不得删除或覆盖。

密封正式输入：
FORMAL_RUN_ID=pr90-repaired-head-release-full-001
FORMAL_ATTEMPT_ID=release-full-attempt-001
FORMAL_GATE_RANGE=1-79
FORMAL_GATE_COUNT=79

FORMAL_PLAN_SHA256=55323dab888060b0214c00c81c43993af9b69c28a28939f84f34b569f0b78e85
FORMAL_MANIFEST_SHA256=1be88a6b41e9e2154a4f59c85c30095767379f2c01ef3d9fada0fd363493e68c
FORMAL_WORKER_SHA256=675f5ad470fb26bc377731e1ba9e7380c9852d33b4200fdca0c72ac6f9a5d8bd
FORMAL_PROJECTOR_SHA256=f9dc0a85ddc2861eb14645044aef8bcfa3f32c103558a29a65a53a3547cc0509
FORMAL_LAUNCHER_SHA256=a82052f7e311987bdc33499a5c71b390d20e3028a33fc6348a2f34119ec93762

FORMAL_PLAN_PATH=
E:/SpaceSyndicateWorkspace/product-acceptance-v2/pr90/1e948a15e17faffe648722fd596fac01a4525426/pr90-new-head-release-repair-cycle-001/preflight-evidence-gate1-source-contract-revision-001-attempt-003/release-run-plan-1-79-v1.json

FORMAL_MANIFEST_PATH=
E:/SpaceSyndicateWorkspace/product-acceptance-v2/pr90/1e948a15e17faffe648722fd596fac01a4525426/pr90-new-head-release-repair-cycle-001/preflight-evidence-gate1-source-contract-revision-001-attempt-003/pr90-repaired-head-release-full-001-formal-manifest.json

FORMAL_ROOT=
E:/SpaceSyndicateWorkspace/product-acceptance-v2/pr90/1e948a15e17faffe648722fd596fac01a4525426/pr90-repaired-head-release-full-001/formal-attempt-001

Gate 1 来源合同：
- Full Plan 包含 Gate 1，必须使用 FORMAL_IN_PLAN。
- Formal Manifest 中 gate1_reuse_attestation 属性数量必须为 0。
- Gate 1 必须在本 Attempt 真实执行一次。
- Aggregate 必须由 79 个当前正式 Product Authority + 79 个当前正式 Receipt 构成。
- reuse_attestation_count 必须为 0。
- 不得使用旧 Head Gate 1、CI 日志、空路径、null 或假 Attestation。

已证明：
RELEASE_RUN_PLAN_DRY_RUN=6/6_PASS
MANIFEST_NEGATIVE_CASES=8/8_PASS
AGGREGATE_NEGATIVE_CASES=4/4_PASS
REAL_FROZEN_RESULT_PROJECTION=PASS
FULL_FORMAL_AGGREGATE_FIXTURE=PASS_79_RECEIPTS_0_REUSE
FROZEN_REUSE_AGGREGATE_FIXTURE=PASS_78_RECEIPTS_1_REUSE
AST_ERROR_COUNT=0
HARDCODED_ACCOUNTING_GATE_ID_COUNT_AFTER=0
EXACT_REUSED_COMPONENT_BYTE_PARITY=13/13
PRODUCT_EXECUTOR_DEPENDS_ON_EVIDENCE_PROJECTOR=false
EVIDENCE_PROJECTOR_FAILURE_STOPS_PRODUCT_EXECUTION=false

本 Prompt 明确授权：
AUTHORIZED_PRODUCT_ATTEMPT_COUNT=1
AUTHORIZED_GATE_EXECUTION_COUNT=79
AUTHORIZED_GATE_IDS=1..79
AUTOMATIC_PRODUCT_RETRY_ALLOWED=false
AUTOMATIC_CONTINUATION_CREATION_ALLOWED=false
CANONICAL_IMPORT_RERUN_ALLOWED=false
PRODUCT_REPAIR_CYCLE_ALLOWED=false

只有以下全部成立才可调用密封 Launcher：
1. 实时 PR Head、直接 PR Ref、直接 Branch Ref、Acceptance Clone Head 全等于指定 Head。
2. Acceptance Clone Tree 等于指定 Tree，tracked/index delta 都为 0。
3. CI 仍为 SUCCESS，PR 仍 OPEN、DRAFT、MERGEABLE。
4. Plan、Manifest、Worker、Projector、Launcher SHA 与密封值完全一致。
5. Formal Root 不存在。
6. Godot、Release Worker、7576、7586 都为 0。
7. 所有历史 Attempt 和三个 Preflight Root 的字节未修改。

Attempt 边界：
- 第一个产品 Godot 进程成功创建时消耗唯一 Attempt。
- execution-start.json 必须由 Gate 1 的真实产品进程创建点立即写入。
- Gate 1 尚未创建产品进程时，Attempt 未消耗。
- 进程创建后，即使 Witness、Progress、Receipt、Summary 或 Aggregate 失败，也不得恢复配额。

正式执行：
- 只执行 Gate 1—79 一次。
- 每 Gate 保存 Raw Result、Product Authority、Normalized Result、Row、Receipt 和进程身份。
- 首个真实产品失败立即停止；不得重跑、自动修复或创建 Continuation。
- 投影失败记录到 backlog，并继续后续产品 Gate；不得使已权威 PASS 的产品结果失效。
- Runner 自身无法继续时冻结现场；不得把它描述为产品失败。

只有 79 个当前 Head 产品 Gate 全 PASS 才生成：
AGGREGATED_PRODUCT_FOCUSED_TESTS=79/79
AGGREGATED_PRODUCT_FOCUSED_STATUS=PASS
GATE1_SOURCE_MODE=FORMAL_IN_PLAN
FORMAL_RECEIPT_COUNT=79
REUSE_ATTESTATION_COUNT=0

79/79 后按顺序、每阶段一次：
1. Post-Aggregate Review A/B/C，要求 P0=0、P1=0。
2. Exact-SHA MCP。
3. 真实 Viewport 样品局。
4. Headless 3/4/6/8。
5. Product Headless 2,000。
6. 刷新 PR #90 描述、转 Ready、使用 merge commit 合入 main。
7. 发布最终 docs-only 云端 Handoff；PR #91 不合入产品分支。

任何阶段首失败立即停止，不重跑 Gate 1—79，不自动创建下一 Attempt。

禁止：
- 修改 PR #90 产品代码、测试、Canonical Gate Manifest、规则、Gate 顺序或预期；
- 修改密封 Runner 字节；
- 修改或补写历史 Attempt；
- 重新 Import；
- squash 或 rebase merge；
- 实施 V0.7.6、启动 MCP 迁移或确定性战斗 POC。

V076_IMPLEMENTATION=false
V076_POC_STARTED=false

若 Formal Gate 失败：
NEXT_TASK=PR90_PRODUCT_GATE_<ID>_<EXACT_DOMAIN>_BLOCKED_NO_REPAIR_CYCLE

若 Runner 失败：
NEXT_TASK=PR90_REPAIRED_HEAD_RELEASE_RUNNER_<EXACT_BLOCKER>

若后续 Release Stage 失败：
NEXT_TASK=PR90_<EXACT_STAGE>_CONTINUATION

若全部完成并合并：
NEXT_TASK=ALPHA_0_6_V076_DETERMINISTIC_POC_AND_PRODUCTION_PLANNING
```
