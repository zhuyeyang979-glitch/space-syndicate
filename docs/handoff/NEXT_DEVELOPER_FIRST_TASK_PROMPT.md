# 下一开发者首任务 Prompt

```text
你是《Space Syndicate / 太空辛迪加》的主开发 Agent。

TASK_ID=PR90_RELEASE_HEAD_BOUND_IMPORT_CACHE_AND_RAW_DIAGNOSTICS_CARDINALITY_REPAIR
EXECUTION_MODE=FREEZE_FORMAL_ATTEMPT_001_REPAIR_TOOLING_PREFLIGHT_ONLY_THEN_REQUEST_NEW_FORMAL_AUTHORIZATION

产品身份：
PR_NUMBER=90
PRODUCT_BRANCH=codex/v075-monster-military-combat-bd0af5c
HEAD_SHA=1e948a15e17faffe648722fd596fac01a4525426
TREE_SHA=8508df4e900a73c058566f00fc556ec1d11e08ca
CI_RUN_ID=31956611702
CI_STATUS=SUCCESS
PR_STATE=OPEN_DRAFT
PR_MERGEABLE=true

冻结正式现场：
FROZEN_RUN_ID=pr90-repaired-head-release-full-001
FROZEN_ATTEMPT_ID=release-full-attempt-001
FROZEN_EXECUTION_COUNT=1
FROZEN_AUTHORIZED_COUNT_CONSUMED=1
FROZEN_PRODUCT_ATTEMPT_CONSUMED=true
FROZEN_GATE1_GODOT_STARTED=true
FROZEN_GATE1_PRODUCT_PID=26632
FROZEN_GATE2_TO_79_STARTED=false
FROZEN_AUTOMATIC_RETRY_COUNT=0

FROZEN_EXECUTION_START_SHA256=dc7cf44a053fac2095ca6e1b29f72216b437f578bcf948f88ff53e6776c9deda
FROZEN_GATE1_RAW_RESULT_SHA256=fc7fea93e7e097892959b25493f51d7dd12239c3885880476217c60750f36736
FROZEN_SUMMARY_SHA256=7579e862f42ecead8e78885c6b079b7e647a6d9b54bc6b8268ac5dae0446114b

正式冻结语义：
FROZEN_SUMMARY_STATUS=RUNNER_BLOCKED
FROZEN_PRODUCT_STARTED_COUNT=1
FROZEN_PRODUCT_COMPLETED_COUNT=0
FROZEN_PRODUCT_PASS_COUNT=0
FROZEN_PRODUCT_FAIL_COUNT=0
FROZEN_PRODUCT_FAILURE_ATTESTED=false
FROZEN_RUNNER_FIRST_FAILURE_CLASS=PRODUCT_EXECUTOR_INVALID
FROZEN_RUNNER_FIRST_FAILURE_MESSAGE=product_executor_diagnostics_wrong_type

不得修改、删除、覆盖、补写或重跑 Formal Attempt 001。不得生成缺失的 Gate Row/Receipt，不得把 Raw failure 描述成已证明的产品回归，不得恢复已消费配额。

Raw 产品进程事实：
- Gate 1 `res://tests/smoke_test.gd --check-only` 已真实启动一次。
- duration=0.75 秒，process_exit_code=1，timed_out=false。
- script_error_count=1158。
- first_script_error=`Could not find type "MenuLifecycleApplicationFlowController" in the current scope.`
- Raw diagnostic_count=1，但 JSON `diagnostics` 是单一 object，不是 array。
- stderr SHA256=`87688623de10c92cd314fe6ea54306df30e944c67ecb80c4a528af628dbf33a8`。

根因 A：当前 Head 的 Import Cache 没有进入正式 Clone。
- Acceptance Clone 完全没有 `.godot` 目录。
- `.godot/global_script_class_cache.cfg` 不存在。
- Raw Result 明确记录 cache_present_before=false、cache_invalid_reason_before=missing、import_mode=none。
- Formal Manifest 引用的 Canonical Import Evidence 路径属于旧 Head `6d4d52df...`。
- 首批报错涉及的 class_name 均在当前 Head 源码真实存在。

正式分类：
FIRST_BLOCKER_CLASS=FORMAL_CLONE_CURRENT_HEAD_CANONICAL_IMPORT_CACHE_MISSING
PRODUCT_CODE_REGRESSION_ATTESTED=false

根因 B：Raw diagnostics 基数不稳定。
- 唯一诊断被 JSON 序列化为 object。
- Normalizer 正确 fail closed 为 `product_executor_diagnostics_wrong_type`。
- Product Executor 因此没有形成 PASS 或 FAIL Authority，也没有继续 Gate 2。

正式分类：
SECOND_BLOCKER_CLASS=RAW_DIAGNOSTICS_SINGLETON_ARRAY_COLLAPSED_TO_OBJECT

本任务只授权一个新的 append-only Tooling Revision。允许修改仓库外 Release Runner/Preflight/Test Runner/Result Writer/Schema Self-Test/Manifest Builder；不允许修改 PR #90 产品代码、Godot 项目、测试、Canonical Gate Manifest、Gate 顺序、Gate 预期、规则或数值。

必须建立 `HeadBoundCanonicalImportEvidenceV1`：
- head_sha、tree_sha、clone_root；
- Godot path/version/SHA、renderer、import settings fingerprint；
- import started/ended、exit code、timeout；
- cache path、cache size、cache SHA256、cache fingerprint；
- sidecar classification parity；
- canonical payload SHA256。

Formal Launcher 在任何产品 Gate 前必须验证：
1. Import Evidence Head/Tree 等于 Manifest Head/Tree；
2. Evidence clone_root 等于正式 Acceptance Clone；
3. cache 文件当前真实存在；
4. cache SHA/fingerprint 与 Evidence 一致；
5. Godot 与 renderer/import settings 身份一致；
6. clone tracked/index delta 为 0。

不得接受：
- 旧 Head Import Evidence；
- 只有 Evidence 但缓存物理文件不存在；
- 其他 Clone 的缓存路径；
- cache SHA 漂移；
- 通过 CI SUCCESS 推定 Import 已完成。

当前 Head 尚未执行有效 Canonical Import，因此本 Tooling Preflight 允许在一个新的 exact-sha disposable Acceptance Clone 中执行一次 Canonical Import。Import 属于 Tooling Preflight，不是产品 Gate Attempt；不得运行任何 Gate 脚本。Import 完成后密封 Clone、Evidence、Manifest 和全部 Runner 字节。不得重复 Import。

必须修复 Raw diagnostics writer 合同：
- Raw Result 中 `diagnostics` 始终为 JSON array；
- 零诊断必须为 `[]`；
- 单诊断必须为 `[record]`，不得折叠为 object；
- 多诊断保持稳定顺序；
- null、string、number、嵌套数组、null element 均 fail closed；
- diagnostic_count 必须与数组长度一致；
- Normalizer 不得把任意 object 静默包装为数组；
- 不关闭 StrictMode，不吞掉错误，不伪造 message。

至少 Self-Test：
1. diagnostics=[]；
2. 单元素数组 JSON roundtrip；
3. 多元素数组 JSON roundtrip；
4. object 被拒绝；
5. null + count 0 按声明合同处理；
6. null + count >0 被拒绝；
7. null element 被拒绝；
8. string/number/nested array 被拒绝；
9. diagnostic_count mismatch 被拒绝；
10. 当前冻结 Raw Result 只读重放产生明确 legacy-cardinality blocker，不修改原文件；
11. synthetic corrected singleton array 能 Normalize→Authority→Row→Receipt→Progress→Summary；
12. Result JSON serialization/deserialization fingerprint parity。

Import 负例至少覆盖：
1. old-head evidence；
2. missing cache；
3. wrong cache SHA；
4. wrong clone root；
5. wrong tree；
6. dirty clone；
7. valid exact-head cache。

正式预检要求：
HEAD_BOUND_IMPORT_SELFTEST=PASS
RAW_DIAGNOSTICS_CARDINALITY_SELFTEST=PASS
CURRENT_HEAD_CANONICAL_IMPORT_STATUS=PASS
CURRENT_HEAD_IMPORT_EXECUTION_COUNT=1
CURRENT_HEAD_IMPORT_CACHE_PRESENT=true
CURRENT_HEAD_IMPORT_CACHE_FINGERPRINT_GREEN=true
FORMAL_CLONE_HEAD_TREE_CLEAN=true
FORMAL_WORKER_AST_ERROR_COUNT=0
FORMAL_DRY_RUN_PASS=true
FORMAL_DRY_RUN_GODOT_GATE_START_COUNT=0
PRODUCT_ATTEMPT_CONSUMED_BY_PREFLIGHT=false

预检必须证明 Gate 1 的正式命令在不启动 Gate Godot 的 command-plan/binder dry run 中将使用已导入的 exact-head Clone。预检结束后不得修改密封 Worker、Result Writer、Normalizer、Manifest、Plan、Launcher 或 Clone Cache 字节。

本任务明确不授权：
AUTHORIZED_PRODUCT_ATTEMPT_COUNT=0
AUTHORIZED_GATE_EXECUTION_COUNT=0
AUTOMATIC_RETRY_ALLOWED=false
AUTOMATIC_CONTINUATION_CREATION_ALLOWED=false
PRODUCT_REPAIR_CYCLE_ALLOWED=false

预检全绿后，停止并请求新的明确授权：
PR90_REPAIRED_HEAD_FULL_GATE1_79_FORMAL_ATTEMPT_002

新的 Attempt 必须使用新的 run/attempt/root，不得复用或覆盖 Attempt 001。只有用户明确授权后，才能完整执行 Gate 1—79 一次。首个真实产品失败停止；Runner 失败冻结；不得自动再试。

后续 Release 链仍然只有在 79/79 后才允许：Post-Aggregate Review、Exact-SHA MCP、Viewport、Headless 3/4/6/8、Product Headless 2,000、PR Ready、merge commit、Tag 和最终 Handoff。

V076_IMPLEMENTATION=false
V076_POC_STARTED=false
MCP_PILOT_STARTED=false
PR90_MERGED=false

完成本任务后更新 docs-only Handoff，报告精确 Revision、Import Evidence SHA、Cache Fingerprint、Self-Test 数量、密封 Runner SHA、Godot/Worker/端口归零和下一授权字符串。
```
