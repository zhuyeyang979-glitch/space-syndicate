# V0.7.6 后续路线图

全部状态：**PLANNED_NOT_IMPLEMENTED**。本任务没有创建 V0.7.6 分支或 POC。

已排队的非阻塞方向：

- `MCP_WORKFLOW_DIRECTION_QUEUED=true`，但 `MCP_PILOT_STARTED=false`。候选固定为 GoPeak compact、godot-mcp-runtime 与必要时的 godot-mcp-enhanced；试验只能在 disposable exact-SHA Clone，不能改 PR #90，也不能阻塞 V0.7.6。
- `DETERMINISTIC_COMBAT_DIRECTION_QUEUED=true`，但 `OPEN_SOURCE_PILOT_STARTED=false`。候选架构为 Server-Authoritative Deterministic Command Simulation，只把 monster/military physical movement、combat window、cooldown、Direct Action ETA 与 effect schedule 放入固定点 Tick；不把整个经济游戏改成高频 Tick。
- 当前 Release 任务没有更换 MCP、安装 Addon、创建架构分支或生产切换。

## 前置门

1. 在不修改 Formal Attempt 002 的前提下修复 Gate 63 测试布局合同；当前必须先解决 Godot MCP 缺少 `.gd` patch 能力的工具阻塞。
2. Gate 63 聚焦验证与 Gate 63—79 开发预演全部通过后形成新 Head，并完成唯一一次新 Head Gate 1—79 Formal Release。
3. 三路 Review、Exact-SHA MCP、Viewport、Headless Matrix 与 2,000 局全部通过后，用 merge commit 合并 PR #90 并按 Release Manifest 打 Tag。
4. PR #90 合并后立即创建独立 V0.7.6 Detached POC A 分支；不得在 PR #90 合并前提前实施。

## Detached POC

- POC A：怪兽 L1 低成本定向球面移动→践踏→Receipt→Presentation。
- POC B：军队 Direct Action→固定点距离/ETA→赶上 combat freeze 或 too_late→撤离。
- POC C：两玩家同 Tick 私密行动→稳定 Authority 排序→Replay parity→Rival 隐私。

## 架构候选

Server-Authoritative Deterministic Command Simulation；20Hz 为初始候选，10/20/30 对比。Tick 仅管理物理移动、战斗窗口、技能 cooldown、Direct Action ETA、Combat effect schedule。经济/DBG/设施/Victory 保持批次与 Receipt。

建立 CombatCommandV1、EffectProgramV1、CombatStateHasherV1、CombatReplayLogV1、Snapshot Ring。权威数值用 int/fixed point/milli-arc/basis points；唯一 Run RNG Authority 增加命名 stream，不新增 RNG Owner。Presentation 只消费 Receipt。

## 产品方向

精确球面拼图、Shared Half-Edge、军队物理 ETA、怪兽 L1 定向移动、所有怪兽技能正资产成本、Combat Presentation Receipt、多战斗 Combat Observatory、Monster/Military Popout。

## 验收

至少 100 Seeds、100 Command variants、每序列 3 次 Replay，State Hash/RNG cursor/Receipt order/Final state mismatch 全 0；再执行 2,000 局 Headless。若无 Linux 环境，必须写“跨平台确定性未证明”。
