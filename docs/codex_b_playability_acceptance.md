# Codex B Playability Acceptance Gates

Codex B 的目标不是继续堆剧本外壳，而是让人类玩家能从主菜单进入可试玩路径，并在不知道完整规则的情况下完成前 10-30 分钟体验。

## 硬边界

- 不修改 `PublicTrack`、`CardTrack`、`BidBoard` 核心行为。
- 不修改 AI 评分、经济公式、怪兽移动/伤害公式。
- 只允许在 `main.gd` 做 Scenario/Campaign 的薄接线。
- 玩家可见 UI 不显示 AI 内部评分、压力桶、对手真实手牌、对手真实现金、弃牌选择或匿名牌真实归属。

## 本阶段硬验收

1. 主菜单能进入新手战役、快速开局、资料库和剧本库。
2. Scenario Lab 至少有 8 个固定可试玩剧本。
3. 每个剧本阶段必须有：
   - `success_signal`
   - `snapshot_key`
   - `focus_target`
   - `stuck_hint`
4. ScenarioCoach 主按钮只能定位/提示下一步，不能伪完成目标。
5. ScenarioCoach 不显示“跳过”按钮。
6. 玩家连续求助或卡住 20 秒后，Coach 必须显示一句短卡住提示。
7. ScenarioCoach 的“定位”必须跳到真实桌面目标：牌轨只聚焦不假完成，牌架/经济/情报等目标可打开对应页面或抽屉。
8. 剧本行动日志只显示公开记录和当前玩家私密记录。
9. Campaign 关卡完成必须来自真实 scenario signal，而不是 UI 按钮直接通关。
10. 截图/布局测试必须覆盖 Scenario/Campaign 关键页面。
11. 每轮收尾必须运行 Codex B 必跑测试，并在推 main 前确认没有覆盖 Codex A 的最新 main。

## 必跑测试

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/scenario_smoke_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/scenario_focus_navigation_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/scenario_progress_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/scenario_privacy_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/campaign_runtime_flow_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/player_journey_30min_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/layout_scene_smoke_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/visual_snapshot.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke_test.gd --check-only
```

完整发布到 `main` 前还要跑完整 `tests/smoke_test.gd`。
