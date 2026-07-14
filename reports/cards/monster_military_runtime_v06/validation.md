# SS06-07 Monster & Military Card Runtime v0.6 Validation

日期：2026-07-14  
证据等级：`focused` + 独立场景 `runtime`；**不是 production 接线证据**

## 结论

独立单位牌合同骨架已完成并通过聚焦验证：5 个测试合计 `187/187`，Godot 4.7 MCP 独立 Bench `54/54`，最终 debug `errors=[]`，停止 `finalErrors=[]`。

Reference owner 已证明 intent/receipt、revision、prepare/commit/rollback/finalize、exact-once、一次性 lure、可回收军令、递归隐私过滤与 checkpoint gate 的合同状态机可运行。真实 `MonsterRuntimeController` 与 `MilitaryRuntimeController` 仍缺原子事务能力，因此所有真实 mutating intent 在 prepare 入口保持 fail-closed，未调用旧 bool mutation API，也未改变 roster。

## 聚焦测试

运行方式：

```powershell
godot_console.cmd --headless --path . --script res://tests/<test>.gd
```

所有测试均为内存 fixture；未运行完整 smoke，未访问默认 `user://`。

| 测试 | 结果 | Checks |
| --- | --- | ---: |
| `monster_card_runtime_v06_test.gd` | PASS | 52 |
| `military_card_runtime_v06_test.gd` | PASS | 49 |
| `unit_card_effect_router_v06_test.gd` | PASS | 41 |
| `unit_card_privacy_v06_test.gd` | PASS | 17 |
| `unit_card_owner_capability_v06_test.gd` | PASS | 28 |
| **合计** | **PASS** | **187** |

覆盖：

- 怪兽部署、同族升级、一次性诱导、移动/攻击/格挡/区域压制固定技能；
- 军队部署、同族升级、前进/保卫/攻击怪兽/区域压制军令；
- 合法、非法目标、旧 revision、transaction replay/collision；
- commit 失败、rollback 成功、rollback 失败与重试、finalize 失败与重试；
- transaction→effect/action 权威绑定，伪造 receipt 不能改路由；
- 冻结 `play_core_card(...)` 原始 effect-intent 的结构归一化；
- prepare/commit 未终结、rollback_failed、finalize_failed 时 checkpoint 关闭；
- public/private/developer 三层视图与嵌套字典/数组递归泄漏扫描；
- 正式 v0.6 目录实数：32 张怪兽部署/升级牌、28 张军队部署/升级牌，当前 0 张正式 lure/bound-action/reusable-command；
- 真实 owner capability gap 与 roster 零变更 fail-closed。

## 独立 Godot Bench

场景：`res://scenes/tools/MonsterMilitaryCardRuntimeV06Bench.tscn`

最终 MCP debug output：

```text
Godot Engine v4.7.stable.official.5b4e0cb0f
MONSTER_MILITARY_CARD_RUNTIME_V06_BENCH|status=PASS|checks=54|failures=0
errors=[]
```

最终 MCP stop：

```text
message=Godot project stopped
finalErrors=[]
```

第一次 MCP run 曾报告两个命名遮蔽 warning：forwarding port 的参数 `domain` 遮蔽方法，Bench 的参数 `owner` 遮蔽 Node 属性。两项均在本轮独占文件内改名；最终重跑无 warning/error。旧输出不作为最终验收结果。

## Exact-once 与事务窗口证据

- Router 在 prepare 时保存完整 binding；相同 transaction 只有完整 binding 一致才返回 journal replay。
- `intent_hash` 保留外层卡牌事务绑定；`unit_intent_fingerprint` 使用 SHA-256 再绑定 effect/action、owner revision、target/payload hash。
- 相同 lure transaction 重放不会建立第二次覆盖；reference autonomous consume 首次成功、第二次拒绝。
- 相同 military command transaction 重放不会重复追加 command。
- Owner 明确 `rolled_back=true` 后才进入终态；rollback false 保留关联、标记 `compensation_failed` 并继续阻止 checkpoint。
- Owner 明确 `finalized=true` 后才关闭 rollback；`finalize_failed` 保留 authoritative committed receipt 并允许重试。

## 隐私证据

public allowlist 和递归 sanitizer/scan 验证结果：`leak_count=0`。测试注入并确认移除：

- `true_owner`、`hidden_owner`、`owner_truth` 与嵌套 owner 字段；
- `actor_id`、transaction/card instance/bound UID；
- 对手现金、手牌、库存与资产 debit；
- AI 私有计划、raw error、raw owner receipt；
- revision、fingerprint/hash、reason code 与 developer/private 字段。

行动者 private view 只接收自己的 allowlist 字段；对手 viewer 退化为 public view。Developer view 保留诊断但不作为玩家文本 fallback。

## 当前阻塞与证据边界

真实 owner 当前只有 roster/debug/save-load 和直接 bool mutation API，没有 unit-card revision、prepare、结构化 commit receipt、rollback、finalize、exact-once journal 或 inflight checkpoint gate。额外已观察风险包括怪兽 v0.6 升级延时语义不一致、军队跨 owner 回执未严格传播、旧动态技能/军令尚无正式 v0.6 profile。

因此本报告只证明独立合同与安全拒绝，不证明：

- `main` / Coordinator / 玩家 UI 已接线；
- 真实怪兽或军队已由牌成功部署、移动或攻击；
- 旧动态诱导、固定兽技和军令已成为 v0.6 正式目录条目；
- 真实跨 owner damage/movement 已具备原子补偿。
