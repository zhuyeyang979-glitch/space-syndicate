# 下一开发者首任务 Prompt

```text
你是《Space Syndicate / 太空辛迪加》的主开发 Agent。

TASK_ID=PR90_GATE63_PLANET_MAP_LAYOUT_CURRENT_MCP_SCRIPT_EDIT_CAPABILITY
EXECUTION_MODE=FREEZE_FORMAL_ATTEMPT_002_ENABLE_AUDITABLE_GDSCRIPT_EDIT_CAPABILITY_THEN_REPAIR_RELATED_TEST_FIXTURES

产品身份：
PR_NUMBER=90
HEAD_SHA=1e948a15e17faffe648722fd596fac01a4525426
TREE_SHA=8508df4e900a73c058566f00fc556ec1d11e08ca
CI_RUN_ID=31956611702
CI_STATUS=SUCCESS
PR_STATE=OPEN_DRAFT
PR_MERGEABLE=true

冻结正式现场：
FROZEN_RUN_ID=pr90-repaired-head-release-full-002
FROZEN_ATTEMPT_ID=formal-attempt-002
FROZEN_EXECUTION_COUNT=1
FROZEN_AUTHORIZED_COUNT_CONSUMED=1
FROZEN_PRODUCT_ATTEMPT_CONSUMED=true
FROZEN_EXECUTION_START_SHA256=fa7a040ede31658fd213426befae018b8fc090381671b3900a62e275f26c50e4
FROZEN_SUMMARY_SHA256=fe0a969a56d7a5030f037336b1a521adcc36c1b13dceef2d3d55ff845b915875
FROZEN_GATE_1_TO_62_PASS_COUNT=62
FROZEN_GATE63_STATUS=PRODUCT_GATE_FAILURE
FROZEN_GATE63_RAW_RESULT_SHA256=240fda2cbb17db6d5903663412eb47a97a284e58270fd10db4b61eed9a1c41ff
FROZEN_GATE63_BUSINESS_ASSERTIONS=18/18
FROZEN_GATE63_UNCLASSIFIED_ERROR_COUNT=1
FROZEN_GATE64_TO_79_STARTED_COUNT=0

不得修改、删除、覆盖、补写或重跑 Formal Attempt 002。不得把 Gate 63 改写为 PASS，不得恢复已消费配额，不得在旧 Attempt Root 中继续执行。

正式根因：
GATE63_ROOT_CAUSE_CLASS=TEST_FIXTURE_LAYOUT_CONTRACT_DEFECT
PRODUCTION_LAYOUT_DEFECT_ATTESTED=false

生产 PlanetMapView 根节点为 Full Rect。真实生产父链由 MapHost 或 Container 唯一拥有尺寸，生产脚本不会在 _ready() 后写根尺寸。测试却把 View 直接挂到 SceneTree.root，随后在 tests/v074_planet_map_view_test.gd:20 写固定 size，触发：

Nodes with non-equal opposite anchors will have their size overridden after _ready().

正确修复：
Fixed-size Host Control
→ PlanetMapView Full Rect
→ await ready/layout frame
→ assert Host/View size parity

必须覆盖：1000x650、1366x768、1600x960、1920x1080。
直接相关同模式 fixture：tests/v074_planet_shader_surface_test.gd:19。
Gate 64—79 没有发现直接同模式风险。

当前工具阻塞：
MCP_ONLY_GODOT_CODE_EDIT=true
DIRECT_FILESYSTEM_GODOT_CODE_EDIT_COUNT=0
CURRENT_MCP_GDSCRIPT_READ_WRITE_PATCH_CAPABILITY=false
COMPUTER_USE_GODOT_EDITOR_WINDOW_ACQUIRED=false

本任务首先需要提供可审计的当前 MCP GDScript read/write/patch 工具，或取得用户对直接文件编辑的明确放宽授权。没有任一条件时必须停止，不得用 PowerShell、apply_patch、其他编辑器或生产代码测试分支绕过。

能力到位后只允许修改：
- tests/v074_planet_map_view_test.gd
- tests/v074_planet_shader_surface_test.gd（若复核仍为同根模式）
- 直接共享的 test support / fixture

不得修改生产 PlanetMapView、地图规则、几何、玩法、AI、资产、Manifest、Gate 顺序、测试预期或 V0.7.6。

修复后先运行 Gate 63 focused，要求 18/18、marker 命中、全部 diagnostics 为 0。随后在开发 Evidence Root 按 Canonical 顺序运行 Gate 63—79，共 17 项；它不是 Formal Attempt。开发预演必须 17/17 后才允许提交新 Head。

本任务当前不授权正式产品 Attempt：
AUTHORIZED_FORMAL_PRODUCT_ATTEMPT_COUNT=0
AUTOMATIC_RETRY_ALLOWED=false
AUTOMATIC_CONTINUATION_CREATION_ALLOWED=false

如果工具能力仍缺失：
STATUS=BLOCKED
NEXT_TASK=PR90_GATE63_PLANET_MAP_LAYOUT_CURRENT_MCP_SCRIPT_EDIT_CAPABILITY

如果 fixture 修复与开发预演全绿：
停止并请求新的完整 Release 授权；不得自动启动 Gate 1—79。

PR90_MERGED=false
V076_BRANCH_CREATED=false
V076_POC_STARTED=false
```
