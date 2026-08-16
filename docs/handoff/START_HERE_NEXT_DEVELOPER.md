# START HERE — 下一开发者入口

当前状态：**PR #90 BLOCKED，尚未合并**。权威产品 Head 为 `1e948a15e17faffe648722fd596fac01a4525426`，Tree 为 `8508df4e900a73c058566f00fc556ec1d11e08ca`，CI Run `31956611702` SUCCESS；GitHub PR 仍为 OPEN DRAFT、MERGEABLE。

先读：

1. `reports/handoffs/pr90_gate63_planet_map_layout_tooling_blocker.md`
2. `docs/handoff/V075_TEST_AND_RELEASE_EVIDENCE.md`
3. `docs/handoff/NEXT_DEVELOPER_FIRST_TASK_PROMPT.md`

最新正式现场是 `pr90-repaired-head-release-full-002 / formal-attempt-002`，不是旧的 Attempt 001。Attempt 002 只执行一次并永久冻结：Execution Start SHA-256 `fa7a040ede31658fd213426befae018b8fc090381671b3900a62e275f26c50e4`，Summary SHA-256 `fe0a969a56d7a5030f037336b1a521adcc36c1b13dceef2d3d55ff845b915875`。Gate 1—62 为 62 PASS；Gate 63 为 `PRODUCT_GATE_FAILURE`；Gate 64—79 未启动。不得修改、补写、覆盖或重跑该 Attempt。

Gate 63 的产品进程真实退出 0，required marker 命中，业务断言 18/18；但 stderr 有一条 Canonical 未分类布局 warning，所以正式 Gate 必须失败，不能用业务断言覆盖。Raw Result SHA-256 为 `240fda2cbb17db6d5903663412eb47a97a284e58270fd10db4b61eed9a1c41ff`。

根因已经明确为 `TEST_FIXTURE_LAYOUT_CONTRACT_DEFECT`。生产 `PlanetMapView` 是 Full Rect，真实 `MapHost` 或 Container 是唯一布局 Owner；生产脚本不会在 `_ready()` 后强制写根尺寸。测试在 `tests/v074_planet_map_view_test.gd:20` 对已经拉伸的 View 写固定 size，导致 Godot 报告 opposite anchors 不相等。正确修复是固定尺寸 Test Host → Full Rect `PlanetMapView` → 等待布局 → 验证 Host/View 尺寸一致，覆盖 1000×650、1366×768、1600×960、1920×1080。`tests/v074_planet_shader_surface_test.gd:19` 是直接相关同模式 fixture。

当前没有执行修复，因为授权要求 `MCP_ONLY_GODOT_CODE_EDIT=true`。已安装 Godot MCP 没有 `.gd` 读取、写入或 patch 工具；MCP 启动的 Editor 也无法由 Computer Use 取得可控窗口。没有使用直接文件编辑绕过该约束：产品代码变化 0、测试变化 0、Gate 63 重跑 0、Formal 新 Attempt 0。

第一任务：执行 `PR90_GATE63_PLANET_MAP_LAYOUT_CURRENT_MCP_SCRIPT_EDIT_CAPABILITY`。必须提供可审计的当前 MCP GDScript patch 能力，或取得用户对直接文件编辑的明确放宽授权。能力到位后才可修改两个相关 test fixtures、运行 Gate 63 聚焦验证和 Gate 63—79 开发预演；全部 17/17 通过后才形成新 Head并进入最终 Release。

当前 Godot、Release Worker、受保护端口均为 0。V0.7.6、MCP 效率 Pilot 与确定性战斗 POC 均未启动；不得用新工具或新架构绕过 Gate 63。
