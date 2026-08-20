# PR #90 Gate 63 布局修复工具阻塞交接

当前 PR #90 产品身份保持为 Head `1e948a15e17faffe648722fd596fac01a4525426`、Tree `8508df4e900a73c058566f00fc556ec1d11e08ca`；CI Run `31956611702` 为 SUCCESS，PR 仍是 Draft、可合并但尚未满足 Release 门禁。

Formal Attempt 002 已永久冻结。Execution Start SHA-256 为 `fa7a040ede31658fd213426befae018b8fc090381671b3900a62e275f26c50e4`，Summary SHA-256 为 `fe0a969a56d7a5030f037336b1a521adcc36c1b13dceef2d3d55ff845b915875`。Gate 1—62 为 62 PASS；Gate 63 的 Godot 产品进程退出 0、required marker 命中、业务断言 18/18，但 Canonical fail-closed 捕获一条布局 warning，所以 Gate 63 正式仍为 `PRODUCT_GATE_FAILURE`。Gate 63 Raw Result SHA-256 为 `240fda2cbb17db6d5903663412eb47a97a284e58270fd10db4b61eed9a1c41ff`。Gate 64—79 未启动。旧 Attempt 没有被修改、补写、覆盖或重跑。

根因已经收口为 `TEST_FIXTURE_LAYOUT_CONTRACT_DEFECT`，没有证据证明生产布局有缺陷。生产 `PlanetMapView` 根节点是 Full Rect，真实父链由 `MapHost` 或 Container 唯一拥有尺寸；生产脚本不会在 `_ready()` 后重写根尺寸。测试却把 Full Rect View 直接挂到 `SceneTree.root`，随后在 `tests/v074_planet_map_view_test.gd:20` 写 `view.size = Vector2(1000.0, 650.0)`，精确触发 Godot warning。18/18 只证明业务断言成立，不能覆盖 Canonical diagnostics fail-closed。

正确修复必须是固定尺寸 Test Host 包含 Full Rect `PlanetMapView`，等待 ready 与布局帧，并验证 `1000x650`、`1366x768`、`1600x960`、`1920x1080` 四种 Host/View 尺寸一致。`tests/v074_planet_shader_surface_test.gd:19` 是直接相关的同模式 fixture；Gate 64—79 没有发现直接同模式风险。

当前阻塞不是产品或测试语义不清，而是工具能力边界。任务要求 `MCP_ONLY_GODOT_CODE_EDIT=true`、`DIRECT_FILESYSTEM_GODOT_CODE_EDIT_COUNT=0`。当前 Godot MCP 只有项目读取、运行/停止、启动 Editor、创建/添加/保存场景节点等工具，没有 `.gd` 读取、写入或 patch 接口。通过 MCP 启动 Editor 后，Computer Use 也无法取得可控制的 Editor 窗口。因而本轮没有修改任何 Godot 文件，也没有用 PowerShell、apply_patch 或其他编辑器绕过 MCP-only 约束。

当前 Godot、Release Worker、端口 7576/7586 均为 0。产品代码变化 0、测试 fixture 变化 0、开发 Gate 63—79 预演 0/17、正式新 Attempt 0、PR #90 未合并、V0.7.6 未开始。

下一任务是 `PR90_GATE63_PLANET_MAP_LAYOUT_CURRENT_MCP_SCRIPT_EDIT_CAPABILITY`。它需要提供可审计的当前 MCP GDScript patch 能力，或由用户明确放宽 MCP-only 编辑约束；在此之前不得伪造修复、不得运行 Gate 63、不得消费最终 Formal Attempt。
