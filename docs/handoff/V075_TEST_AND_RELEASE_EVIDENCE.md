# V0.7.5 测试与 Release Evidence

## 当前身份

- PR #90 Head：`1e948a15e17faffe648722fd596fac01a4525426`
- Tree：`8508df4e900a73c058566f00fc556ec1d11e08ca`
- CI：Run `31956611702`，SUCCESS
- PR：OPEN DRAFT，MERGEABLE

## 当前正式结果

| 项目 | 结果 | 说明 |
|---|---|---|
| Formal Attempt 002 | FROZEN PRODUCT_FAIL | `pr90-repaired-head-release-full-002 / formal-attempt-002`；execution 1；授权消耗 1 |
| Gate 1—62 | 62/62 PASS | 当前 exact Head/Tree 的正式结果 |
| Gate 63 | PRODUCT_GATE_FAILURE | Godot exit 0、marker 命中、业务 18/18；1 条未分类 anchor/size warning |
| Gate 63 Raw Result | FROZEN | SHA `240fda2cbb17db6d5903663412eb47a97a284e58270fd10db4b61eed9a1c41ff` |
| Gate 64—79 | NOT_STARTED | 首个产品 Gate fail 后正确停止 |
| Gate 63 根因 | TEST_FIXTURE_LAYOUT_CONTRACT_DEFECT | 生产 Full Rect View 合同正确；测试缺少真实固定尺寸 Host |
| 生产布局缺陷 | NOT_ATTESTED | 生产 main 父链没有同 warning 证据 |
| Test fixture 修复 | NOT_STARTED | 当前 MCP 无 `.gd` patch 能力；MCP-only 约束未放宽 |
| Gate 63 focused | NOT_RUN | 不得在无修复时重跑 |
| Gate 63—79 development rehearsal | 0/17 | 尚未开始 |
| 新 Head full Formal 1—79 | NOT_RUN | 授权配额尚未消耗 |
| Review/MCP/Viewport/Headless/2,000 | NOT_RUN | 79/79 前禁止 |
| PR merge/tag | NOT_RUN | Release 链未全绿 |
| V0.7.6 POC | NOT_STARTED | PR #90 合并前禁止 |

## 冻结哈希

- Attempt 002 Execution Start SHA-256：`fa7a040ede31658fd213426befae018b8fc090381671b3900a62e275f26c50e4`
- Attempt 002 Summary SHA-256：`fe0a969a56d7a5030f037336b1a521adcc36c1b13dceef2d3d55ff845b915875`
- Gate 63 Raw Result SHA-256：`240fda2cbb17db6d5903663412eb47a97a284e58270fd10db4b61eed9a1c41ff`
- Root Cause JSON SHA-256：`6659be182e9bd0ef19f820a007b5fbe6b555b46b0bbd0041e50c9a71bc61e71b`
- Root Cause Markdown SHA-256：`c237fdc41fe7b554f6ceeaae21a43be5607a848143827eb02b3bc34b0dfe427d`
- Layout Matrix JSON SHA-256：`893be0f5be7a326296269a366d3d428dcd0ae9695712f95bfb86062bfd80828f`
- Layout Matrix Markdown SHA-256：`d94caea51c294b06efe58b17fa265899cf32eff5e0fa79067f3143950a13e318`
- Tooling Blocker Update SHA-256：`55c61146cbdeabfc52c89cc82808361ed010abeff5c85d18bcb8fb41a94f3e0d`

## 结论

18/18 表示测试内的业务断言完成，但 Canonical Gate 同时要求零脚本、资源、Runtime、Task、UID 和未分类诊断。`tests/v074_planet_map_view_test.gd:20` 触发的 warning 因而必须 fail closed；隐藏 warning、加入忽略表或降低 stderr 检查都不合法。

Root Cause 审计证明生产中的 `PlanetMapView` 由 `MapHost` 或 Container 唯一拥有尺寸；问题发生在测试把 Full Rect View 直接挂到根并写固定 size。正确修复只应改变相关 test fixture，不应修改地图规则、几何、玩法、AI、资产、Manifest 或测试预期。

当前工具只能操作 Godot 项目信息、进程和场景节点，不能修改 `.gd`。由于任务明确禁止直接文件系统编辑，修复必须停在工具能力边界。Godot/Release Worker/7576/7586 均为 0；Attempt 002 没有任何修改、回填或重跑。

Formal Attempt 001 的 Import Cache 和 singleton diagnostics 事件仍保留为历史证据，但已被后续预检修复，不是当前首阻塞。当前唯一下一任务是 `PR90_GATE63_PLANET_MAP_LAYOUT_CURRENT_MCP_SCRIPT_EDIT_CAPABILITY`。
