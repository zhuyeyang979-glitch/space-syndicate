# VS06-B2 Monster legacy write-path retirement audit

审计快照：2026-07-14 22:02 +09:00。只读检查生产源码；A 正在修改 `main.gd` / `game_runtime_coordinator.gd`，以下行号以该快照为准。

## 结论

`MonsterRuntimeController` 内已经存在唯一 v0.6 原子首召写链，但生产卡牌结算仍保留第二条 legacy 权威写链。Coordinator 已配置 Monster adapter，并新增 `play_v06_runtime_card()`；然而 `rg` 在生产源码中只找到其定义，没有调用者。当前真人和 AI 都先进入旧共享队列，最终由 `main.gd:18991-18992` 直接调用 `_summon_monster_from_card()`。

旧链不会写 `_monster_starter_state_v06`，因此可能出现“roster 已有怪兽、starter marker 未提交”的分裂状态。这是 A 完成 `REQ-MON-P0-001` 时必须切断的 P0 写入口。

## 合并调用图

```text
真人：_use_skill (main:19044)
教练：_activate_first_run_coach_action (main:13745) → _use_skill
AI：_ai_card_play_context (ai:6547) → _ai_card_play_candidates (6961)
    → _ai_queue_play_candidate (7274)
                    ↓
          _queue_skill_resolution (main:18217)
                    ↓
 _apply_card_resolution_effect_request (main:18948)
                    ↓ handler_id == monster_card
 _summon_monster_from_card (monster:1992)                 [必须切断]
    ├─ _upgrade_field_monster_from_card (1940) → roster[slot] = actor (1965)
    └─ _make_auto_monster (1584) → 消费 UID (1590-1591)
       → auto_monsters.append (2030)

正式替代：GameRuntimeCoordinator.play_v06_runtime_card (coordinator:925)
 → inventory.play_core_card + MonsterCardEffectAdapter (960)
 → prepare/commit/finalize；失败时 rollback
 → _monster_card_swap_core_state_v06 (monster:1416)
```

## 所有 roster/UID/starter composition 写入口

| 分类 | 入口与调用方 | 写入 | 处置 |
|---|---|---|---|
| v0.6 唯一卡牌 owner | `prepare_unit_card_intent_v06:656` 构造副本；`commit:840→864`、`rollback:876→907` 调 `_monster_card_swap_core_state_v06:1416` | roster、UID、selection、starter marker 一次替换 | 保留，正式唯一卡牌写 API |
| 新局重置 | `GameRuntimeCoordinator.reset_state:1076-1088` → `reset_state:225` | 清 roster、UID、marker/journal | 保留 |
| 权威存档恢复 | `main:9256-9257` → Coordinator `apply_monster_save_data:973` → `apply_save_data:396` | 完整预检后恢复 roster、UID、marker/journal | 保留 |
| 生态离场 | `main:1065-1066` → Coordinator `tick_monster_durations:997` → `_update_auto_monster_durations:1723` → `_remove_auto_monster:1701` | 到期删除 roster、重排 slot | 保留；不是卡牌旁路 |
| legacy 卡牌写 | `main:18991-18992` → `_summon_monster_from_card:1992` | 直接升级或 append，直接分配 UID，不写 marker | A 必须切断 |
| main 动态旁路 | `main._set:1842` 中 `auto_monsters:1855-1860`、`next_auto_monster_uid:1862-1864` | 整表/UID 无 revision 改写 | 移除写分支；getter 暂留 |
| AI 动态旁路 | `ai_runtime_controller.gd:324-329` 的 `auto_monsters` setter | 整表无 revision 改写 | 移除 setter；getter暂留 |
| 测试兼容旁路 | `replace_runtime_state:371` | 转发权威 save-load 替换 | 限测试；fixtures 迁移后删除 |

`main.gd`、AI、资格检查与 UI 对 roster 的现有读取可暂时作为兼容/呈现路径保留；它们没有静态 composition 写入。后续宜改为 `roster_snapshot` / public-private snapshot，但不属于本次 retirement 前置条件。

## A 完成统一接线后的最小降级/删除清单

1. 先删除 `main.gd:18991-18992` 的 legacy direct dispatch，正式 v0.6 怪兽牌只走 `play_v06_runtime_card()`；不得保留“新链失败再回退旧链”。
2. 零生产引用后删除 Controller 函数：`_summon_monster_from_card`、`_upgrade_field_monster_from_card`、`_field_monster_upgrade_slot_for_card`、`_owned_active_monster_slot`、`_make_auto_monster`。
3. 删除 main 的 roster/UID `_set` 写分支和 AI roster setter；暂留只读 getter。
4. 将 `replace_runtime_state` 标为 test-only，待 `layout_scene_smoke_test` 与 characterization fixtures 改用受验证 save fixture 后删除。
5. **整份可删生产文件：0。** Controller、WorldBridge、adapter/port 都仍是正式替代链的一部分。

不要随上述函数一并删除 `_remove_auto_monster`、`_owned_active_monster_count`、`_player_monster_control_limit`、`_grant_bound_monster_skills` 或 `_invalidate_bound_monster_skills`；它们仍被到期离场、takeover 或其他保留运行时路径引用。升级仍按当前合同 fail-closed，不得因删除 legacy 升级而重新开放旧语义。

## 严格证据门

任一删除必须同时满足：

1. **零生产引用**：排除 `tests/**`、`scripts/tools/**`、docs/reports 后，旧函数调用、main/AI roster setter、反射式 `.set("auto_monsters")` 均为 0；定义可在删除提交前作为唯一剩余匹配。
2. **v0.6 replacement 已真实使用**：`play_v06_runtime_card()` 至少有真人与 AI 的生产调用链；两者同走 CardFlow → Monster adapter → authoritative owner lifecycle；无 legacy fallback。
3. **统一验收覆盖**：协调线程确认真人首召、AI 首召、duplicate exact-once、失败 rollback、save/load 后不重复召唤、公开/私有快照与完整局均通过。
4. **fixture 迁移完成**：当前 `smoke_test.gd`、`layout_scene_smoke_test.gd` 及多个 characterization bench 直接调用 `_make_auto_monster` / `_summon_monster_from_card` / `replace_runtime_state`；必须先迁移，不能把这些 stale tests 当成保留 legacy 生产 API 的理由。

## 可复核 rg

```powershell
rg -n --glob '*.gd' --glob '!tests/**' --glob '!scripts/tools/**' '_summon_monster_from_card|_upgrade_field_monster_from_card|_make_auto_monster|replace_runtime_state|play_v06_runtime_card' scripts
rg -n --glob '*.gd' 'auto_monsters\s*=|auto_monsters\.(append|remove_at)|next_auto_monster_uid\s*[+]?=|_monster_starter_state_v06' scripts
rg -n 'play_v06_runtime_card\(' scripts --glob '*.gd'
```

本轮未修改生产代码、未删除函数、未增加测试，也未运行完整验收。
