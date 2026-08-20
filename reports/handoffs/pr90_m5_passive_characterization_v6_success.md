# PR90 M5 v6 被动表征成功交接

状态：`PASSIVE_M0_M5_CHARACTERIZATION_PASSED_AND_SEALED`

## 固定身份

- 产品 Head/Tree：`770d741f05964facda4afcbddcdeb3e7f40571d5` / `f5bb584ceea065b13c9b5621b1976af7907c62ad`
- Base Tooling Head/Tree：`f82d6a7c710c6f27332ed7db87260e92315cfc93` / `f52f2f8673898707f191ca85bb82a882e788c99b`
- 新 Tooling Head/Tree：`963f283de0aa869b0e9f181d78d11b7d83ffaed0` / `0cc06c9ea13817c573fba1703ea77ae10823fba5`
- 新 Tooling 提交数：`1`
- 产品代码、产品测试、PR #90 Head 变化计数：`0 / 0 / 0`

## 两个精确修复

1. 保留 5 个总样本、3 个连续双源一致样本和至少 1000ms 稳定窗口。采样预算现在确定性派生为 `(5 - 1) * 500 + 15000 Observer margin + 5000 Process Identity margin = 22000ms`，并受 60000ms 短时上限约束；没有把 5 降为 4。
2. M5 里程碑状态和失败类别先由 `Resolve-Pr90M5MilestoneParametersV1` 计算为显式局部变量，再传给 `Write-Milestone`。控制器中 inline `(if ...)` 参数表达式计数为 0。

## 封印与自测

- Self-Test：`PASS 79/79`，失败 0，静态评审 `GO`
- 4 样本 false-green：`0`
- PowerShell 解析错误：`0`
- PowerShell 参数绑定异常：`0`
- Manifest SHA256：`244289469cd8d1a74b736b4410dd55ba8da398117f12a79b2d04b9bd080e5b32`
- Validation SHA256：`beba7473a3fed68c7d0a166fe109fe079c0840ee648f2701f9cc8d667bcb9495`，问题 0
- Seal SHA256：`6faf41ce48d5b7b2fd36bbbc07480409c7448d24408ecc4e341cf8d5d0d88163`
- Seal 后 Tooling 字节变化：`0`

## 唯一一次 v6 Probe

- Probe：`pr90-m5-passive-characterization-v6-001`
- 执行次数：`1`；自动重试：`false`；第二个 v6 Probe：`false`
- M0、M1、M2、M3、M4、M5：全部 `PASS`
- 总 Listener 样本：`5`
- 连续 Parity 样本：`5`
- 稳定窗口：`8083.264ms`
- 两个 Observer 一致：`true`；A-only/B-only：`0 / 0`
- Endpoint Owner PID：`20168`
- 进程链：`pwsh controller 8796 -> pwsh launcher 5620 -> Godot console wrapper 14908 -> Godot GUI endpoint owner 20168`
- GUI 引擎：`true`；console wrapper：`false`
- launcher 后代、fixture 命令行、Windows Session、用户 SID：全部匹配
- PID、Creation Identity、Process Lineage 变化计数：`0 / 0 / 0`
- 多活 Endpoint Owner：`0`

## M5 归因与终态

- `M5_ROOT_CAUSE_CLASS=D_ENDPOINT_ARCHITECTURE_CONTRACT_DRIFT`
- `M5_ROOT_CAUSE_FORMALLY_ATTESTED=true`
- Result SHA256：`96ce10e876914ab89b093ed53a25f3ce687e39dd213e7147b16fd833c2f4309e`
- Attestation SHA256：`ac78d1980663309804ebd00f734fcdfee7469c91aeda06366a0f947b8778dec8`，状态 `SEALED`
- Characterization 正常停止：`true`；Forced Stop：`false`
- Godot / 7576 / 7586 残留：`0 / 0 / 0`
- 无关进程终止：`0`
- JSON-RPC、M6–M11、Play Main Scene、Product Match、Formal MCP、Authorized Run：全部 `0`

## 授权停止点

- `READY_FOR_ENDPOINT_OWNERSHIP_V2_REPAIR_AUTHORIZATION=true`
- `READY_FOR_POST_REPAIR_M0_M11_PROBE=false`
- `READY_FOR_PR90_STARTUP_PROBE_B=false`
- `READY_FOR_NEW_EXACT_SHA_MCP_AUTHORIZATION=false`

唯一下一任务：

`PR90_MCP_ENDPOINT_OWNERSHIP_V2_CONTRACT_REPAIR_AND_POST_REPAIR_M0_M11_PROBE_AUTHORIZATION`
