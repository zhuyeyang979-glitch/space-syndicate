# Anonymous Interaction Runtime v0.6 Validation

日期：2026-07-14  
范围：Agent C 独立 contract/schema/router/window/privacy/production forwarding port 与 Bench。

## 聚焦测试

| 测试 | 结果 | checks |
|---|---:|---:|
| anonymous_interaction_schema_v06_test.gd | PASS | 13 |
| anonymous_interaction_router_v06_test.gd | PASS | 23 |
| counter_response_window_v06_test.gd | PASS | 13 |
| anonymous_interaction_privacy_v06_test.gd | PASS | 6 |
| anonymous_interaction_owner_capability_v06_test.gd | PASS | 6 |
| 合计 | PASS | 61/61 |

public receipt privacy scan：`0 leaks`。

## 生产状态

现有 Contract、Intel、CardInventory/PlayerHandInteraction owner 均缺少完整的 atomic rollback/finalize/revision/exact-once/save-load 能力组合。production forwarding port 已验证在调用 owner prepare 前 fail-closed；reference owner 仅存在于 tests/Bench。

## Godot MCP Bench

通过 Godot 4.7 内部 MCP server 直接运行：

- scene：`res://scenes/tools/AnonymousInteractionRuntimeV06Bench.tscn`
- engine：`4.7.stable.official.5b4e0cb0f`
- suite：`8/8 PASS`
- public leaks：`0`
- debug output：`errors=[]`
- MCP stop：`finalErrors=[]`

Bench 覆盖字段路由、commit exact-once、rollback exact-once、finalize exact-once、生产 owner fail-closed、反制 scope 零副作用、inflight window save/load 和无人持有反制时的可解释结果。Bench 不访问默认玩家存档，不接 main/Coordinator。

## 硬验收映射

| 验收项 | 证据 |
|---|---|
| 合法/非法目标、旧 revision | schema test |
| 无权限 responder、重复 respond/pass、超时、取消 | window test |
| commit 失败、rollback 成功/失败、finalize 成功/失败 | router test |
| 反制仅 direct-player | schema/router/window test + MCP Bench |
| transaction/window 重放 exact-once | router/window test + MCP Bench |
| public privacy leak=0 | privacy test + MCP Bench |
| inflight save/load/checkpoint | window test + MCP Bench |
| owner 缺原子能力 fail-closed | owner capability test + MCP Bench |
